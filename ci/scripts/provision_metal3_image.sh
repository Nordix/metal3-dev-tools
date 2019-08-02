#!/bin/bash

set -uex

SCRIPTS_DIR="$(dirname "$(readlink -f "${0}")")"

# Metal3 Dev Env variables
M3_DENV_ORG="${M3_DENV_ORG:-metal3-io}"
M3_DENV_REPO="${M3_DENV_REPO:-metal3-dev-env}"
M3_DENV_URL="${M3_DENV_URL:-https://github.com/${M3_DENV_ORG}/${M3_DENV_REPO}.git}"
M3_DENV_BRANCH="${M3_DENV_BRANCH:-master}"
M3_DENV_ROOT="${M3_DENV_ROOT:-/tmp}"
M3_DENV_PATH="${M3_DENV_PATH:-${M3_DENV_ROOT}/${M3_DENV_REPO}}"
FORCE_REPO_UPDATE="${FORCE_REPO_UPDATE:-true}"

export CONTAINER_RUNTIME="${CONTAINER_RUNTIME:-docker}"

sudo apt install -y git

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
"${M3_DENV_PATH}/01_install_requirements.sh"
popd

rm -rf "${M3_DENV_PATH}"


# Reset cloud-init to run on next boot.
"${SCRIPTS_DIR}"/reset_cloud_init.sh
