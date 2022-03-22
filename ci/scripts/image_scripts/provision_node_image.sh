#!/bin/bash

set -uex

SCRIPTS_DIR="$(dirname "$(readlink -f "${0}")")"

export KUBERNETES_VERSION=${KUBERNETES_VERSION:-"v1.23.5"}
export KUBERNETES_BINARIES_VERSION="${KUBERNETES_BINARIES_VERSION:-${KUBERNETES_VERSION}}"
export KUBERNETES_BINARIES_CONFIG_VERSION=${KUBERNETES_BINARIES_CONFIG_VERSION:-"v0.2.7"}
export CONTAINER_RUNTIME="${CONTAINER_RUNTIME:-docker}"

# Upgrade all packages
sudo apt-get update
sudo apt-get upgrade -f -y

# Install required packages.
sudo apt install -y \
  vim \
  jq \
  git \
  coreutils \
  wget \
  curl \
  apt-transport-https \
  ca-certificates \
  tree \
  make \
  gnupg-agent \
  software-properties-common \
  openssl

sudo mv $SCRIPTS_DIR/node-image-cloud-init/retrieve.configuration.files.sh /usr/local/bin/retrieve.configuration.files.sh
sudo chmod +x /usr/local/bin/retrieve.configuration.files.sh
sudo apt-get install -y conntrack socat
sudo apt install net-tools gcc linux-headers-$(uname -r) bridge-utils -y
sudo apt install -y keepalived && sudo systemctl stop keepalived
curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | sudo apt-key add -
sudo bash -c 'echo "deb https://apt.kubernetes.io/ kubernetes-xenial main" > /etc/apt/sources.list.d/kubernetes.list'
sudo apt update -y

# Install CRI-O
"${SCRIPTS_DIR}"/install_crio_on_ubuntu.sh 

echo  "Installing kubernetes binaries"
curl -L --remote-name-all "https://storage.googleapis.com/kubernetes-release/release/${KUBERNETES_BINARIES_VERSION}/bin/linux/amd64/{kubeadm,kubelet,kubectl}"
sudo chmod a+x kubeadm kubelet kubectl
sudo mv kubeadm kubelet kubectl /usr/local/bin/
sudo mkdir -p /etc/systemd/system/kubelet.service.d
sudo retrieve.configuration.files.sh https://raw.githubusercontent.com/kubernetes/release/"${KUBERNETES_BINARIES_CONFIG_VERSION}"/cmd/kubepkg/templates/latest/deb/kubelet/lib/systemd/system/kubelet.service /etc/systemd/system/kubelet.service
sudo retrieve.configuration.files.sh https://raw.githubusercontent.com/kubernetes/release/"${KUBERNETES_BINARIES_CONFIG_VERSION}"/cmd/kubepkg/templates/latest/deb/kubeadm/10-kubeadm.conf /etc/systemd/system/kubelet.service.d/10-kubeadm.conf

# Last checkup and cleanup
sudo sed -i "0,/.*PermitRootLogin.*/s//PermitRootLogin yes/" /etc/ssh/sshd_config
sudo rm "${HOME}"/.ssh/authorized_keys

# Download container images
"${SCRIPTS_DIR}"/target_cluster_container_images.sh

# Reset cloud-init to run on next boot.
"${SCRIPTS_DIR}"/reset_cloud_init.sh

# Remove the scripts
sudo rm -r "${SCRIPTS_DIR}"
