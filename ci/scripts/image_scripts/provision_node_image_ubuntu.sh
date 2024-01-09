#!/bin/bash

set -uex

SCRIPTS_DIR="$(dirname "$(readlink -f "${0}")")"

export KUBERNETES_VERSION=${KUBERNETES_VERSION:-"v1.29.0"}
export KUBERNETES_MINOR_VERSION=${KUBERNETES_VERSION%.*}
export KUBERNETES_BINARIES_VERSION="${KUBERNETES_BINARIES_VERSION:-${KUBERNETES_VERSION}}"
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

sudo cp "${SCRIPTS_DIR}"/node-image-cloud-init/retrieve.configuration.files.sh /usr/local/bin/retrieve.configuration.files.sh
sudo chmod +x /usr/local/bin/retrieve.configuration.files.sh
sudo apt-get install -y conntrack socat
sudo apt-get install net-tools gcc linux-headers-"$(uname -r)" bridge-utils -y
sudo apt-get install -y keepalived && sudo systemctl stop keepalived

# migrate to the Kubernetes community-owned repositories
sudo mkdir -m 0755 -p /etc/apt/keyrings
echo "deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/${KUBERNETES_MINOR_VERSION}/deb/ /" | sudo tee /etc/apt/sources.list.d/kubernetes.list
curl -fsSL https://pkgs.k8s.io/core:/stable:/"${KUBERNETES_MINOR_VERSION}"/deb/Release.key | sudo gpg --yes --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
sudo apt-get update -y

# Install CRI-O
"${SCRIPTS_DIR}"/install_crio_on_ubuntu.sh

echo  "Installing kubernetes binaries"
# deb versions doesn't have a 'v' in the beginning and has a build version suffix
# like -1.1, we are using * to make sure it takes the latest build. We checked
# manually that for a specific version, only one built is present in the apt list.
KUBERNETES_DEB_VERSION="${KUBERNETES_VERSION//v}"-\*
sudo apt-get install -y kubelet="${KUBERNETES_DEB_VERSION}" kubeadm="${KUBERNETES_DEB_VERSION}" kubectl="${KUBERNETES_DEB_VERSION}"
sudo apt-mark hold kubelet kubeadm kubectl

# Last checkup and cleanup
sudo sed -i "0,/.*PermitRootLogin.*/s//PermitRootLogin yes/" /etc/ssh/sshd_config
sudo rm "${HOME}"/.ssh/authorized_keys

# Download container images
"${SCRIPTS_DIR}"/target_cluster_container_images.sh

# Reset cloud-init to run on next boot.
"${SCRIPTS_DIR}"/reset_cloud_init.sh

# Remove the scripts
sudo rm -r "${SCRIPTS_DIR}"
