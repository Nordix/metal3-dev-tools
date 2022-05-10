#!/bin/bash

set -uex

SCRIPTS_DIR="$(dirname "$(readlink -f "${0}")")"
export KUBERNETES_VERSION=${KUBERNETES_VERSION:-"v1.23.5"}
export KUBERNETES_BINARIES_VERSION="${KUBERNETES_BINARIES_VERSION:-${KUBERNETES_VERSION}}"
export KUBERNETES_BINARIES_CONFIG_VERSION=${KUBERNETES_BINARIES_CONFIG_VERSION:-"v0.13.0"}
export CONTAINER_RUNTIME="${CONTAINER_RUNTIME:-podman}"

"${SCRIPTS_DIR}"/configure_nameservers_centos.sh

# Install CRI-O
"${SCRIPTS_DIR}"/install_crio_on_centos.sh
# NOTE: When running with sudo, PATH is different.
# /usr/local/bin is NOT read by sudo commands, but rather /usr/bin.
sudo cp /usr/local/bin/crictl /usr/bin/

echo $PATH|tr ':' '\n'
sudo mv $SCRIPTS_DIR/node-image-cloud-init/retrieve.configuration.files.sh /usr/local/bin/retrieve.configuration.files.sh
sudo chmod +x /usr/local/bin/retrieve.configuration.files.sh
sudo ls -la /usr/local/bin/retrieve.configuration.files.sh
sudo dnf update -y
sudo dnf install -y ebtables socat conntrack-tools
sudo dnf install python3 -y
sudo dnf install gcc kernel-headers kernel-devel keepalived -y
sudo dnf install device-mapper-persistent-data lvm2 -y

# Driver to load firmware files (from /lib/firmware/bnx2x/) in the kernel
# version of 5.14.0-80.el9.x86_64 are missing (probably they are present 
# on the file system but missing from new kernel initrd image) which causes driver to fail.  
# This workaround should help in making FW files as a part of initrd.
sudo dnf -y install dracut
sudo dnf install wget -y
sudo wget https://anduin.linuxfromscratch.org/sources/linux-firmware/bnx2x/bnx2x-e2-7.13.21.0.fw
sudo wget https://anduin.linuxfromscratch.org/sources/linux-firmware/bnx2x/bnx2x-e2-7.13.15.0.fw
sudo dracut --install-optional bnx2x-e2-7.13.21.0.fw --force
sudo dracut --install-optional bnx2x-e2-7.13.15.0.fw --force
sudo lsinitrd | grep bnx2x

# Disable SELINUX enforcing
sudo sed -i 's/enforcing/disabled/g' /etc/selinux/config /etc/selinux/config

echo  \"Installing kubernetes binaries\"
curl -L --remote-name-all "https://storage.googleapis.com/kubernetes-release/release/${KUBERNETES_BINARIES_VERSION}/bin/linux/amd64/{kubeadm,kubelet,kubectl}"
chmod a+x kubeadm kubelet kubectl
sudo mv kubeadm kubelet kubectl /usr/local/bin/
sudo mkdir -p /etc/systemd/system/kubelet.service.d
sudo /usr/local/bin/retrieve.configuration.files.sh https://raw.githubusercontent.com/kubernetes/release/"${KUBERNETES_BINARIES_CONFIG_VERSION}"/cmd/kubepkg/templates/latest/deb/kubelet/lib/systemd/system/kubelet.service /etc/systemd/system/kubelet.service
sudo /usr/local/bin/retrieve.configuration.files.sh https://raw.githubusercontent.com/kubernetes/release/"${KUBERNETES_BINARIES_CONFIG_VERSION}"/cmd/kubepkg/templates/latest/deb/kubeadm/10-kubeadm.conf /etc/systemd/system/kubelet.service.d/10-kubeadm.conf

# Last checkup and cleanup
sudo yum clean all && sudo rm -rf /var/cache/yum
sudo rm "${HOME}"/.ssh/authorized_keys

# Download container images
"${SCRIPTS_DIR}"/target_cluster_container_images.sh

# Reset cloud-init to run on next boot.
"${SCRIPTS_DIR}"/reset_cloud_init.sh

# Remove the scripts
sudo rm -r "${SCRIPTS_DIR}"
