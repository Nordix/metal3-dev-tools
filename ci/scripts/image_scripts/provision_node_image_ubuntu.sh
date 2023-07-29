#!/bin/bash

set -uex

SCRIPTS_DIR="$(dirname "$(readlink -f "${0}")")"

export KUBERNETES_VERSION=${KUBERNETES_VERSION:-"v1.27.4"}
export KUBERNETES_BINARIES_VERSION="${KUBERNETES_BINARIES_VERSION:-${KUBERNETES_VERSION}}"
export KUBERNETES_BINARIES_CONFIG_VERSION=${KUBERNETES_BINARIES_CONFIG_VERSION:-"v0.15.1"}
export CONTAINER_RUNTIME="${CONTAINER_RUNTIME:-docker}"

# Needrestart and packer does not seem to work well together. Needrestart is
# propmpting for what services to restart and packer cannot answer, so it get stuck.
# This makes needrestart (l)ist the packages instead of prompting with a dialog.
# It also makes it only print kernel hints instead of prompting users to aknowledge.
# The alternative would be sudo apt-get remove -y needrestart.
#shellcheck disable=SC2016
echo -e '$nrconf{restart} = "l";\n$nrconf{kernelhints} = -1;' | sudo tee /etc/needrestart/needrestart.conf || true

# Set apt retry limit to higher than default to
# make the data retrival more reliable
sudo sh -c 'echo "Acquire::Retries \"10\";" > /etc/apt/apt.conf.d/80-retries'

# Upgrade all packages
sudo apt-get update
sudo apt-get dist-upgrade -f -y

# Install required packages.
sudo apt-get update
sudo apt-get install -y \
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

sudo mv "${SCRIPTS_DIR}"/node-image-cloud-init/retrieve.configuration.files.sh /usr/local/bin/retrieve.configuration.files.sh
sudo chmod +x /usr/local/bin/retrieve.configuration.files.sh
sudo apt-get install -y conntrack socat
sudo apt-get install net-tools gcc linux-headers-"$(uname -r)" bridge-utils -y
sudo apt-get install -y keepalived && sudo systemctl stop keepalived
sudo curl -fsSLo /etc/apt/keyrings/kubernetes-archive-keyring.gpg https://dl.k8s.io/apt/doc/apt-key.gpg
sudo bash -c 'echo "deb [signed-by=/etc/apt/keyrings/kubernetes-archive-keyring.gpg] https://apt.kubernetes.io/ kubernetes-xenial main" | sudo tee /etc/apt/sources.list.d/kubernetes.list'
sudo apt-get update -y

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

# Reset machine-id to regenerate on next boot.
"${SCRIPTS_DIR}"/reset_machine_id.sh

# Remove the scripts
sudo rm -r "${SCRIPTS_DIR}"
