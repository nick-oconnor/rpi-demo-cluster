#!/bin/bash

set -e

kubectl label node node1 blinktShow-
kubectl label node node2 blinktShow-
kubectl label node node3 blinktShow-
kubectl label node node4 blinktShow-
kubectl label node node5 blinktShow-

kubectl label node node1 blinktShow=true
kubectl label node node2 blinktShow=true
kubectl label node node3 blinktShow=true
kubectl label node node4 blinktShow=true
kubectl label node node5 blinktShow=true
