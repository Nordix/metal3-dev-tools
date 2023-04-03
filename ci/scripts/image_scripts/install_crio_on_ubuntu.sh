#!/bin/bash

set -uex

export CRICTL_VERSION=${CRICTL_VERSION:-"v1.26.1"}
export CRIO_VERSION=${CRIO_VERSION:-"v1.26.3"}
# shellcheck disable=SC1091
source /etc/os-release
if [[ ${VERSION_ID} == "20.04" ]]
then
  OS=${OS:-"xUbuntu_20.04"}
else
  OS=${OS:-"xUbuntu_22.04"}
fi

TEMP_CRIO_VERSION="${CRIO_VERSION#v}" && TEMP_CRIO_VERSION="${TEMP_CRIO_VERSION%.*}" # e.g. v1.20.2 -> 1.20
CRIO_VERSION="${TEMP_CRIO_VERSION}"

# Prerequisites for CRI-O
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

# Install CRI-O
cat <<EOF | sudo tee /etc/apt/sources.list.d/devel:kubic:libcontainers:stable.list
deb [signed-by=/usr/share/keyrings/libcontainers-archive-keyring.gpg] https://download.opensuse.org/repositories/devel:/kubic:/libcontainers:/stable/$OS/ /
EOF
cat <<EOF | sudo tee /etc/apt/sources.list.d/devel:kubic:libcontainers:stable:cri-o:"${CRIO_VERSION}".list
deb [signed-by=/usr/share/keyrings/libcontainers-crio-archive-keyring.gpg] https://download.opensuse.org/repositories/devel:/kubic:/libcontainers:/stable:/cri-o:/$CRIO_VERSION/$OS/ /
EOF

curl -L https://download.opensuse.org/repositories/devel:/kubic:/libcontainers:/stable/"$OS"/Release.key | sudo gpg --dearmor -o /usr/share/keyrings/libcontainers-archive-keyring.gpg
curl -L https://download.opensuse.org/repositories/devel:/kubic:/libcontainers:/stable:/cri-o:/"$CRIO_VERSION"/"$OS"/Release.key | sudo gpg --dearmor -o /usr/share/keyrings/libcontainers-crio-archive-keyring.gpg

sudo apt-get update
sudo apt-get install cri-o cri-o-runc -y

# Start CRI-O
sudo systemctl daemon-reload
sudo systemctl start crio

# Download crictl
curl -LO https://github.com/kubernetes-sigs/cri-tools/releases/download/"${CRICTL_VERSION}"/crictl-"${CRICTL_VERSION}"-linux-amd64.tar.gz
sudo tar -C /usr/local/bin -xzf crictl-"${CRICTL_VERSION}"-linux-amd64.tar.gz
