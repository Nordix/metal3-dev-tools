#!/bin/bash

set -uex

SCRIPTS_DIR="$(dirname "$(readlink -f "${0}")")"
export KUBERNETES_VERSION=${KUBERNETES_VERSION:-"v1.29.0"}
export KUBERNETES_MINOR_VERSION=${KUBERNETES_VERSION%.*}
export KUBERNETES_BINARIES_VERSION="${KUBERNETES_BINARIES_VERSION:-${KUBERNETES_VERSION}}"
export CONTAINER_RUNTIME="${CONTAINER_RUNTIME:-podman}"

# migrate to the Kubernetes community-owned repositories
cat <<EOF | sudo tee /etc/yum.repos.d/kubernetes.repo
[kubernetes]
name=Kubernetes
baseurl=https://pkgs.k8s.io/core:/stable:/${KUBERNETES_MINOR_VERSION}/rpm/
enabled=1
gpgcheck=1
gpgkey=https://pkgs.k8s.io/core:/stable:/${KUBERNETES_MINOR_VERSION}/rpm/repodata/repomd.xml.key
exclude=kubelet kubeadm kubectl cri-tools kubernetes-cni
EOF

"${SCRIPTS_DIR}"/install_crio_on_centos.sh

echo "${PATH}"|tr ':' '\n'
sudo cp "${SCRIPTS_DIR}"/node-image-cloud-init/retrieve.configuration.files.sh /usr/local/bin/retrieve.configuration.files.sh
sudo chmod +x /usr/local/bin/retrieve.configuration.files.sh
sudo ls -la /usr/local/bin/retrieve.configuration.files.sh
sudo dnf update -y
sudo dnf install -y ebtables socat conntrack-tools
sudo dnf install python3 -y
sudo dnf install gcc kernel-headers kernel-devel keepalived -y
sudo dnf install device-mapper-persistent-data lvm2 -y

# Fixes bnx2x firmware issue with NIC (reported here https://bugzilla.redhat.com/show_bug.cgi?id=1952463)
sudo yum install linux-firmware -y

# Disable SELINUX enforcing
sudo sed -i 's/enforcing/disabled/g' /etc/selinux/config /etc/selinux/config

echo  \"Installing kubernetes binaries\"
sudo dnf install -y kubelet-"${KUBERNETES_BINARIES_VERSION//v}" kubeadm-"${KUBERNETES_BINARIES_VERSION//v}" kubectl-"${KUBERNETES_BINARIES_VERSION//v}" --disableexcludes=kubernetes
sudo systemctl enable --now kubelet

# Last checkup and cleanup
sudo yum clean all && sudo rm -rf /var/cache/yum
sudo rm "${HOME}"/.ssh/authorized_keys

# Download container images
"${SCRIPTS_DIR}"/target_cluster_container_images.sh

# Reset cloud-init to run on next boot.
"${SCRIPTS_DIR}"/reset_cloud_init.sh

# Remove the scripts
sudo rm -r "${SCRIPTS_DIR}"
