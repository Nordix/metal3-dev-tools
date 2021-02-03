#!/bin/bash

set -uex

DEPLOY_METAL3="${1:-false}"

SCRIPTS_DIR="$(dirname "$(readlink -f "${0}")")"

# Metal3 Dev Env variables
M3_DENV_ORG="${M3_DENV_ORG:-metal3-io}"
M3_DENV_REPO="${M3_DENV_REPO:-metal3-dev-env}"
M3_DENV_URL="${M3_DENV_URL:-https://github.com/${M3_DENV_ORG}/${M3_DENV_REPO}.git}"
M3_DENV_BRANCH="${M3_DENV_BRANCH:-master}"
M3_DENV_ROOT="${M3_DENV_ROOT:-/tmp}"
M3_DENV_PATH="${M3_DENV_PATH:-${M3_DENV_ROOT}/${M3_DENV_REPO}}"
FORCE_REPO_UPDATE="${FORCE_REPO_UPDATE:-true}"

export IMAGE_OS="${IMAGE_OS:-Centos}"
export EPHEMERAL_CLUSTER="${EPHEMERAL_CLUSTER:-minikube}"

sudo yum update -y
sudo yum update -y curl nss
sudo yum install -y git make

#Install Operator SDK
OSDK_RELEASE_VERSION=v0.19.0
curl -OJL https://github.com/operator-framework/operator-sdk/releases/download/${OSDK_RELEASE_VERSION}/operator-sdk-${OSDK_RELEASE_VERSION}-x86_64-linux-gnu
chmod +x operator-sdk-${OSDK_RELEASE_VERSION}-x86_64-linux-gnu
sudo mkdir -p /usr/local/bin/
sudo mv operator-sdk-${OSDK_RELEASE_VERSION}-x86_64-linux-gnu /usr/local/bin/operator-sdk


if [[ "${DEPLOY_METAL3}" == "true" ]]; then
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
fi

# Download container images
"${SCRIPTS_DIR}"/source_cluster_container_images.sh

sudo sed -i "0,/.*PermitRootLogin.*/s//PermitRootLogin yes/" /etc/ssh/sshd_config

# Reset cloud-init to run on next boot.
"${SCRIPTS_DIR}"/reset_cloud_init.sh