#!/bin/bash

set -uex

#Disable the automatic updates
cat << EOF | sudo tee /etc/apt/apt.conf.d/20auto-upgrades
APT::Periodic::Update-Package-Lists "0";
APT::Periodic::Unattended-Upgrade "0";
EOF

# Set apt retry limit to higher than default
# robust to make the data retrival more reliable
sudo sh -c 'echo "Acquire::Retries \"10\";" > /etc/apt/apt.conf.d/80-retries'

sudo systemctl disable apt-daily-upgrade.timer
sudo systemctl disable apt-daily.timer
sudo systemctl stop apt-daily-upgrade.timer
sudo systemctl stop apt-daily.timer

SCRIPTS_DIR="$(dirname "$(readlink -f "${0}")")"

# Metal3 Dev Env variables
M3_DENV_ORG="${M3_DENV_ORG:-metal3-io}"
M3_DENV_REPO="${M3_DENV_REPO:-metal3-dev-env}"
M3_DENV_URL="${M3_DENV_URL:-https://github.com/${M3_DENV_ORG}/${M3_DENV_REPO}.git}"
M3_DENV_BRANCH="${M3_DENV_BRANCH:-main}"
M3_DENV_ROOT="${M3_DENV_ROOT:-/tmp}"
M3_DENV_PATH="${M3_DENV_PATH:-${M3_DENV_ROOT}/${M3_DENV_REPO}}"
FORCE_REPO_UPDATE="${FORCE_REPO_UPDATE:-true}"

export CONTAINER_RUNTIME="${CONTAINER_RUNTIME:-docker}"
export IMAGE_OS="${IMAGE_OS:-Ubuntu}"
export EPHEMERAL_CLUSTER="${EPHEMERAL_CLUSTER:-kind}"

"${SCRIPTS_DIR}"/configure_network_ubuntu.sh

sudo apt-get install -y git

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
popd

rm -rf "${M3_DENV_PATH}"

# Download container images
"${SCRIPTS_DIR}"/source_cluster_container_images.sh

sudo sed -i "0,/.*PermitRootLogin.*/s//PermitRootLogin yes/" /etc/ssh/sshd_config

# Install monitoring tools
"${SCRIPTS_DIR}"/setup_monitoring_ubuntu.sh

# Reset cloud-init to run on next boot.
"${SCRIPTS_DIR}"/reset_cloud_init.sh
