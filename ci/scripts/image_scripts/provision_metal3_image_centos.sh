#!/bin/bash

set -uex

SCRIPTS_DIR="$(dirname "$(readlink -f "${0}")")"

# Metal3 Dev Env variables
M3_DENV_ORG="${M3_DENV_ORG:-metal3-io}"
M3_DENV_REPO="${M3_DENV_REPO:-metal3-dev-env}"
M3_DENV_URL="${M3_DENV_URL:-https://github.com/${M3_DENV_ORG}/${M3_DENV_REPO}.git}"
M3_DENV_BRANCH="${M3_DENV_BRANCH:-main}"
M3_DENV_ROOT="${M3_DENV_ROOT:-/tmp}"
M3_DENV_PATH="${M3_DENV_PATH:-${M3_DENV_ROOT}/${M3_DENV_REPO}}"
FORCE_REPO_UPDATE="${FORCE_REPO_UPDATE:-true}"

export IMAGE_OS="${IMAGE_OS:-Centos}"
export EPHEMERAL_CLUSTER="${EPHEMERAL_CLUSTER:-minikube}"
export CONTAINER_RUNTIME="${CONTAINER_RUNTIME:-podman}"
export CONTAINER_REGISTRY="registry.nordix.org/quay-io-proxy"
export DOCKER_HUB_PROXY="registry.nordix.org/docker-hub-proxy"

"${SCRIPTS_DIR}"/configure_network_centos.sh

sudo dnf distro-sync -y
sudo dnf install -y git make

# Install EPEL repo (later required by atop, python3-bcrypt and python3-passlib)
sudo dnf install -y epel-release

# Without this minikube cannot start properly kvm and fails.
# As a simple workaround, this will create an empty file which can
# disable the new firmware, more details here [1], look for firmware description.
# [1] <https://libvirt.org/formatdomain.html#operating-system-booting>
# upstream commit fixing the behavior to not print error messages for unknown features
# will be included in RHEL-AV-8.5.0 by next rebase to libvirt 7.4.0.
sudo mkdir -p /etc/qemu/firmware
sudo touch /etc/qemu/firmware/50-edk2-ovmf-cc.json

## Install metal3 requirements
mkdir -p "${M3_DENV_ROOT}"
if [[ -d "${M3_DENV_PATH}" && "${FORCE_REPO_UPDATE}" == "true" ]]; then
  sudo rm -rf "${M3_DENV_PATH}"
fi
if [ ! -d "${M3_DENV_PATH}" ] ; then
  pushd "${M3_DENV_ROOT}"
  git clone "${M3_DENV_URL}"
  popd
fi
pushd "${M3_DENV_PATH}"
git checkout "${M3_DENV_BRANCH}"
git pull -r || true
make install_requirements
sudo su -l -c "minikube delete" "${USER}"
popd

rm -rf "${M3_DENV_PATH}"

# Download container images
"${SCRIPTS_DIR}"/source_cluster_container_images.sh

sudo sed -i "0,/.*PermitRootLogin.*/s//PermitRootLogin yes/" /etc/ssh/sshd_config

# Install monitoring tools
"${SCRIPTS_DIR}"/setup_monitoring_centos.sh

# Reset cloud-init to run on next boot.
"${SCRIPTS_DIR}"/reset_cloud_init.sh
