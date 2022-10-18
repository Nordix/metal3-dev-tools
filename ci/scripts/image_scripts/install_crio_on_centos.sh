#!/bin/bash

set -uex

export CRICTL_VERSION=${CRICTL_VERSION:-"v1.23.3"}
ARCH=${ARCH:-"amd64"}
# CRI-O version goes 1:1 with Kubernetes version. Thus,
# please make sure that k8s version given in
# KUBERNETES_VERSION variable matches CRI-O version
# give in VERSION variable.
VERSION=${VERSION:-"${CRICTL_VERSION}"}

# Create the .conf file to load the modules at bootup
cat <<EOF | sudo tee /etc/modules-load.d/crio.conf
overlay
br_netfilter
EOF

sudo dnf install jq -y
sudo modprobe overlay
sudo modprobe br_netfilter

# Set up required sysctl params, these persist across reboots.
cat <<EOF | sudo tee /etc/sysctl.d/99-kubernetes-cri.conf
net.bridge.bridge-nf-call-iptables  = 1
net.ipv4.ip_forward                 = 1
net.bridge.bridge-nf-call-ip6tables = 1
EOF

sudo sysctl --system
sudo setenforce 0

curl https://raw.githubusercontent.com/cri-o/cri-o/main/scripts/get | sudo bash -s -- -t ${VERSION}
sudo systemctl daemon-reload
sudo systemctl start crio

# Download crictl
curl -LO https://github.com/kubernetes-sigs/cri-tools/releases/download/${CRICTL_VERSION}/crictl-${CRICTL_VERSION}-linux-amd64.tar.gz
sudo tar -C /usr/local/bin -xzf crictl-${CRICTL_VERSION}-linux-amd64.tar.gz

# Delete default cni config for crio
sudo rm /etc/cni/net.d/*