#!/bin/bash

set -e

error() {
    echo -e " Failed\nCheck the log for details."
}

resource-wait() {
    while [ "$(kubectl get $1 -n $2 $3 -o=jsonpath={.status.$4})" != "$5" ]; do
        sleep 5
    done
}

deploy-wait() {
    resource-wait deploy $1 $2 availableReplicas $3
}

ds-wait() {
    resource-wait ds $1 $2 numberAvailable $3
}

enable-blinkt() {
    kubectl label node $1 blinktImage=$2 &>> log
    kubectl label node $1 blinktShow=true &>> log
    kubectl label node $1 blinktReadyColor=cpu &>> log
    sleep 1
}

trap error ERR

echo -n "Configuring k8s master..."
sudo kubeadm init --config kubeadm-init.yaml &>> log
mkdir -p $HOME/.kube
sudo cp /etc/kubernetes/admin.conf $HOME/.kube/config >> log
sudo chown $(id -u):$(id -g) $HOME/.kube/config >> log

echo -ne " Done\nWaiting for kube-proxy..."
ds-wait kube-system kube-proxy 1

TOKEN=$(sudo kubeadm token list | sed -n 2p | awk '{print $1}')
openssl x509 -noout -in /etc/kubernetes/pki/ca.crt -pubkey | openssl asn1parse -noout -inform pem -out /tmp/public.key
CA_CERT_HASH=$(openssl dgst -sha256 /tmp/public.key | awk '{print $2}')

echo -ne " Done\nJoining workers..."
parallel-ssh -H k8s-node-2 -H k8s-node-3 -H k8s-node-4 -H k8s-node-5 -t 0 -i "sudo kubeadm join --token $TOKEN 10.88.1.1:6443 --discovery-token-ca-cert-hash sha256:$CA_CERT_HASH" &>> log

echo -ne " Done\nWaiting for kube-proxy..."
ds-wait kube-system kube-proxy 5

echo -ne " Done\nInstalling flannel..."
kubectl apply -f kube-flannel.yaml &>> log

echo -ne " Done\nWaiting for flannel..."
ds-wait kube-system kube-flannel-ds 5

echo -ne " Done\nWaiting for coredns..."
deploy-wait kube-system coredns 2

kubectl label node k8s-node-1 masterNode=true &>> log

echo -ne " Done\nInstalling metrics server..."
kubectl apply -f metrics-server &>> log

echo -ne " Done\nWaiting for metrics server..."
deploy-wait kube-system metrics-server 1

echo -ne " Done\nInstalling traefik..."
kubectl apply -f traefik.yaml &>> log

echo -ne " Done\nWaiting for traefik..."
deploy-wait kube-system traefik-ingress-controller 1

echo -ne " Done\nInstalling kubernetes-dashboard..."
kubectl apply -f kubernetes-dashboard.yaml &>> log

echo -ne " Done\nWaiting for kubernetes-dashboard..."
deploy-wait kube-system kubernetes-dashboard 1

echo -ne " Done\nCreating admin user..."
kubectl apply -f kubernetes-adminuser.yaml &>> log

echo -ne " Done\nInstalling blinkt nodes..."
kubectl apply -f blinkt-k8s-controller-rbac.yaml &>> log
kubectl apply -f blinkt-k8s-controller-nodes.yaml &>> log

enable-blinkt k8s-node-1 nodes

echo -ne " Done\nWaiting for blinkt nodes..."
ds-wait kube-system blinkt-k8s-controller-nodes 1

for i in {2..5}; do
    enable-blinkt k8s-node-$i pods
done

echo -ne " Done\nInstalling blinkt pods..."
kubectl apply -f blinkt-k8s-controller-pods.yaml &>> log

echo -ne " Done\nWaiting for blinkt pods..."
ds-wait kube-system blinkt-k8s-controller-pods 4

echo -ne " Done\nInstalling pi..."
kubectl apply -f pi.yaml &>> log

echo -ne " Done\nWaiting for pi..."
deploy-wait default pi 1

echo -ne " Done\nInstalling load-simulator..."
kubectl apply -f load-simulator.yaml &>> log

echo -ne " Done\nWaiting for load-simulator..."
deploy-wait default load-simulator 1

echo -e " Done\nCluster setup complete."
