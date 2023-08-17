#!/usr/bin/env bash
set -eux

export IMAGE_ID
export PROJECT_ID

OS_SCRIPTS_DIR="$(dirname "$(readlink -f "${0}")")/.."

# shellcheck source=ci/scripts/openstack/infra_defines.sh
. "${OS_SCRIPTS_DIR}/openstack/infra_defines.sh"

# shellcheck source=ci/scripts/openstack/utils.sh
. "${OS_SCRIPTS_DIR}/openstack/utils.sh"

export IMAGE_OS="${IMAGE_OS:-}"

if [[ "${IMAGE_OS}" == "Ubuntu" ]]; then
  IMAGE_NAME=${CI_METAL3_IMAGE}
elif [[ "${IMAGE_OS}" == "CentOS" ]]; then
  IMAGE_NAME=${CI_METAL3_CENTOS_IMAGE}
else
  echo "error: Available IMAGE_OS variables are: CentOS and Ubuntu. Got: ${IMAGE_OS}"
  exit 1
fi

# get image id
IMAGE_ID="$(get_image_id "${IMAGE_NAME}")"
# get project id
PROJECT_ID="$(get_project_id "dev2")"
# Set image shared
share_image "${IMAGE_ID}" "${PROJECT_ID}"
    
export OS_PROJECT_NAME="dev2"
export OS_TENANT_NAME="dev2"

# Accept shared image in dev2 project
accept_shared_image "${IMAGE_ID}"

export OS_PROJECT_NAME="Default Project 37137"
export OS_TENANT_NAME="Default Project 37137"
