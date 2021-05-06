#!/bin/bash

# Delete an existing kind cluster, if any.
kind delete cluster --name kind-capo || true
# Create a new kind cluster
kind create cluster --name kind-capo

# Install clusterctl
pushd /tmp
curl -L https://github.com/kubernetes-sigs/cluster-api/releases/download/v0.3.16/clusterctl-linux-amd64 -o clusterctl
chmod +x ./clusterctl
#sudo mv ./clusterctl /usr/local/bin/clusterctl # Enable this and remove next one
./clusterctl version -o json
# Change the cluster into a management cluster
./clusterctl init --infrastructure openstack
popd

