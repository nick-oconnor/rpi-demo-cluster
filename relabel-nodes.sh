#!/bin/bash

set -e

for i in {1..5}; do
    kubectl label node k8s-node-$i blinktShow-
done

for i in {1..5}; do
    kubectl label node k8s-node-$1 blinktShow=true
done
