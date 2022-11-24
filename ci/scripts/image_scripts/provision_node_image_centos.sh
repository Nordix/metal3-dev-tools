#!/bin/bash

set -uex

SCRIPTS_DIR="$(dirname "$(readlink -f "${0}")")"
export KUBERNETES_VERSION=${KUBERNETES_VERSION:-"v1.26.0"}
export KUBERNETES_BINARIES_VERSION="${KUBERNETES_BINARIES_VERSION:-${KUBERNETES_VERSION}}"
export KUBERNETES_BINARIES_CONFIG_VERSION=${KUBERNETES_BINARIES_CONFIG_VERSION:-"v0.14.0"}
export CONTAINER_RUNTIME="${CONTAINER_RUNTIME:-podman}"

"${SCRIPTS_DIR}"/configure_network_centos.sh

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
# Workaround on centos network manager versions higher than 1.40.0-1.el9 are failing after creating a bridge e.g running:

# tee -a /etc/NetworkManager/system-connections/provisioning-1.nmconnection <<EOF
# [connection]
# id=provisioning-1
# type=bridge
# interface-name=provisioning-1
# [bridge]
# stp=false
# [ipv4]
# address1=172.22.0.1/24
# method=manual
# [ipv6]
# addr-gen-mode=eui64
# method=disabled
# EOF
# chmod 600 /etc/NetworkManager/system-connections/provisioning-1.nmconnection
# nmcli con load /etc/NetworkManager/system-connections/provisioning-1.nmconnection
# nmcli con up provisioning-1

# After those commands ssh connection will be lost
# This workaround downgrade NetworkManager version to NetworkManager-1.40.0-1.el9
sudo yum downgrade -y NetworkManager-1.40.0-1.el9
sudo systemctl restart NetworkManager

#set password and install missing firmware in kernel for bml
sudo yum install linux-firmware -y
sudo usermod --password $(echo password123 | openssl passwd -1 -stdin) metal3ci

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
