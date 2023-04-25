#!/bin/bash

# This script can be used to run locally one of the image building
# scripts. It reproduces the CI environment.
#
# This requires the openstack.rc file to have been sourced and
# takes one parameters:
# - the file name of the script to run
#
# There are some variables in this script that can be overridden and some are
# required. See comments below.

# For example:
# $ source my-custom-vars.sh
# $ source openstack.rc
# $ ./run_local.sh provision_metal3_image_centos.sh

set -eux

PROVISIONING_SCRIPT="${1:?}"

#
# Required variables:
#
# - SSH_KEYPAIR_NAME: Name of the keypair in openstack

#
# Overridable variables
#
# These variables can be overridden by the user, but have defaults that may or
# may not be useful.
CONTAINER_RUNTIME="${CONTAINER_RUNTIME:-docker}"
SSH_USER_NAME="${SSH_USER_NAME:-${USER}}"
SSH_PUBLIC_KEY_FILE="${SSH_PUBLIC_KEY_FILE:-/home/${USER}/.ssh/id_rsa.pub}"
SSH_PRIVATE_KEY_FILE="${SSH_PRIVATE_KEY_FILE:-/home/${USER}/.ssh/id_rsa}"
IMAGE_NAME="${IMAGE_NAME:-${USER}-test}"
# Image to start build from. For example ubuntu-22.04-server-cloudimg-amd64 or CentOS-Stream-9-20220829
SOURCE_IMAGE_NAME="${SOURCE_IMAGE_NAME:-CentOS-Stream-GenericCloud-8}"
# Group to add user to. To get sudo access on CentOS: wheel, on Ubuntu: sudo
SSH_USER_GROUP="${SSH_USER_GROUP:-wheel}"
KUBERNETES_VERSION=${KUBERNETES_VERSION:-"v1.26.0"}
# The network name is by defualt set to $DEV_EXT_NET. You can override it here.
NETWORK_NAME=""
# Or if you want to use ID, set this instead:
# NETWORK=<ID-of-network>

# The variables below should not need to be touched by the user
if [[ "$PROVISIONING_SCRIPT" == *"node"* ]]; then
  BUILDER_CONFIG_FILE="image_builder_template_node.json"
  IMAGE_FLAVOR="1C-4GB-20GB"
elif [[ "$PROVISIONING_SCRIPT" == *"metal3"* ]]; then
  BUILDER_CONFIG_FILE="image_builder_template.json"
  IMAGE_FLAVOR="4C-16GB-50GB"
elif [[ "$PROVISIONING_SCRIPT" == *"base"* ]]; then
  BUILDER_CONFIG_FILE="image_builder_template.json"
  IMAGE_FLAVOR="1C-4GB-20GB"
else
  echo "Available provisioning scripts are:"
  find ../scripts/image_scripts/provision_* | cut -f4 -d'/'
  exit 1
fi

if [[ "$PROVISIONING_SCRIPT" == *"centos"* ]]; then
  USER_DATA_TEMPLATE="centos_userdata.tpl"
else
  USER_DATA_TEMPLATE="ubuntu_userdata.tpl"
fi

DEV_TOOLS="$(dirname "$(readlink -f "${0}")")/../../"
SCRIPTS_DIR="${DEV_TOOLS}/ci/scripts/image_scripts"
OS_SCRIPTS_DIR="${DEV_TOOLS}/ci/scripts/openstack"
IMAGES_DIR="${DEV_TOOLS}/ci/images"

# shellcheck source=ci/scripts/openstack/infra_defines.sh
source "${OS_SCRIPTS_DIR}/infra_defines.sh"
# shellcheck source=ci/scripts/openstack/utils.sh
source "${OS_SCRIPTS_DIR}/utils.sh"

NETWORK_NAME="${NETWORK_NAME:-${DEV_EXT_NET}}"
FLOATING_IP_NETWORK="${EXT_NET}"
REUSE_IPS="true"
# get_resource_id_from_name assumes that the openstack CLI is installed locally.
# If this is not the case, set the NETWORK directly instead.
NETWORK="${NETWORK:-$(get_resource_id_from_name network "${NETWORK_NAME}")}"

TMP="$(mktemp -d)"
USER_DATA_FILE="${TMP}/userdata"
STARTER_SCRIPT_PATH="${TMP}/build_starter.sh"

REMOTE_EXEC_CMD="KUBERNETES_VERSION=${KUBERNETES_VERSION} /home/${SSH_USER_NAME}/image_scripts/${PROVISIONING_SCRIPT}"
echo "${REMOTE_EXEC_CMD}" > "${STARTER_SCRIPT_PATH}"

SSH_AUTHORIZED_KEY="$(cat "${SSH_PUBLIC_KEY_FILE}")"
render_user_data \
  "${SSH_AUTHORIZED_KEY}" \
  "${SSH_USER_NAME}" \
  "${SSH_USER_GROUP}" \
  "${IMAGE_NAME}" \
  "${IMAGES_DIR}/${USER_DATA_TEMPLATE}" \
  "${USER_DATA_FILE}"

CR_CMD_ENV="--env METAL3_CI_USER \
  --env METAL3_CI_USER_KEY=/data/id_ed25519_metal3ci \
  --env OS_AUTH_URL \
  --env OS_USER_DOMAIN_NAME \
  --env OS_PROJECT_DOMAIN_NAME \
  --env OS_REGION_NAME \
  --env OS_PROJECT_NAME \
  --env OS_TENANT_NAME \
  --env OS_AUTH_VERSION \
  --env OS_IDENTITY_API_VERSION \
  --env OS_USERNAME \
  --env OS_PASSWORD "

# Paths inside the container
CONTAINER_SCRIPTS_DIR="/data/metal3-dev-tools/ci/scripts/image_scripts"
CONTAINER_IMAGES_DIR="/data/metal3-dev-tools/ci/images"

# Run the script in a docker container
"${CONTAINER_RUNTIME}" run --rm \
  "${CR_CMD_ENV}"\
  -v "${DEV_TOOLS}":/data/metal3-dev-tools \
  -v "${SSH_PRIVATE_KEY_FILE}":/data/private_key \
  -v "${TMP}":"${TMP}" \
  registry.nordix.org/metal3/image-builder \
  packer build \
    -var "image_name=${IMAGE_NAME}" \
    -var "source_image_name=${SOURCE_IMAGE_NAME}" \
    -var "user_data_file=${USER_DATA_FILE}" \
    -var "exec_script_path=${STARTER_SCRIPT_PATH}" \
    -var "ssh_username=${SSH_USER_NAME}" \
    -var "ssh_keypair_name=${SSH_KEYPAIR_NAME}" \
    -var "ssh_private_key_file=/data/private_key" \
    -var "network=${NETWORK}" \
    -var "floating_ip_net=${FLOATING_IP_NETWORK}" \
    -var "reuse_ips=${REUSE_IPS}" \
    -var "local_scripts_dir=${CONTAINER_SCRIPTS_DIR}" \
    -var "ssh_pty=true" \
    -var "flavor=${IMAGE_FLAVOR}" \
    "${CONTAINER_IMAGES_DIR}/${BUILDER_CONFIG_FILE}"


# upload node image to artifactory
if [[ "$PROVISIONING_SCRIPT" == *"node"* ]]; then
  bash "${SCRIPTS_DIR}/upload_node_image_rt.sh" "${IMAGE_NAME}"
fi
