#!/bin/bash

set -uex

export CRICTL_VERSION=${CRICTL_VERSION:-"v1.21.0"}
OS=${OS:-"CentOS_8"}
# CRI-O version goes 1:1 with Kubernetes version. Thus,
# please make sure that k8s version given in
# KUBERNETES_VERSION variable matches CRI-O version
# give in VERSION variable.
TEMP_CRIO_VERSION="${CRICTL_VERSION#v}" && TEMP_CRIO_VERSION="${TEMP_CRIO_VERSION%.*}" # e.g. v1.20.2 -> 1.20
VERSION=${VERSION:-"${TEMP_CRIO_VERSION}"}

# Create the .conf file to load the modules at bootup
cat <<EOF | sudo tee /etc/modules-load.d/crio.conf
overlay
br_netfilter
EOF

sudo modprobe overlay
sudo modprobe br_netfilter

# Set up required sysctl params, these persist across reboots.
cat <<EOF | sudo tee /etc/sysctl.d/99-kubernetes-cri.conf
net.bridge.bridge-nf-call-iptables  = 1
net.ipv4.ip_forward                 = 1
net.bridge.bridge-nf-call-ip6tables = 1
EOF

sudo sysctl --system

sudo curl -L -o /etc/yum.repos.d/devel:kubic:libcontainers:stable.repo https://download.opensuse.org/repositories/devel:/kubic:/libcontainers:/stable/$OS/devel:kubic:libcontainers:stable.repo
sudo curl -L -o /etc/yum.repos.d/devel:kubic:libcontainers:stable:cri-o:$VERSION.repo https://download.opensuse.org/repositories/devel:kubic:libcontainers:stable:cri-o:$VERSION/$OS/devel:kubic:libcontainers:stable:cri-o:$VERSION.repo
sudo yum install cri-o -y

sudo systemctl daemon-reload
sudo systemctl start crio

# Download crictl
curl -LO https://github.com/kubernetes-sigs/cri-tools/releases/download/${CRICTL_VERSION}/crictl-${CRICTL_VERSION}-linux-amd64.tar.gz
sudo tar -C /usr/local/bin -xzf crictl-${CRICTL_VERSION}-linux-amd64.tar.gz
