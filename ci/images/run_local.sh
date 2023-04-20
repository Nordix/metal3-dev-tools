#!/usr/bin/env bash

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
# Overridable variables
#
# These variables can be overridden by the user, but have defaults that may or
# may not be useful.
CONTAINER_RUNTIME="${CONTAINER_RUNTIME:-docker}"
KUBERNETES_VERSION="${KUBERNETES_VERSION:-v1.27.1}"
# ssh user name used by packer for provisioning
PACKER_SSH_USER_NAME="${PACKER_SSH_USER_NAME:-${USER}}"
# ssh username injected to the userdata files (could differ from what packer is using)
USERDATA_SSH_USER_NAME="${USERDATA_SSH_USER_NAME:-${PACKER_SSH_USER_NAME}}"
USERDATA_SSH_PUBLIC_KEY_FILE="${USERDATA_SSH_PUBLIC_KEY_FILE:-/home/${USER}/.ssh/id_rsa.pub}"
PACKER_SSH_PRIVATE_KEY_FILE="${PACKER_SSH_PRIVATE_KEY_FILE:-/home/${USER}/.ssh/id_rsa}"
IMAGE_NAME="${IMAGE_NAME:-${USER}-test}"
# Image to start build from. For example ubuntu-22.04-server-cloudimg-amd64 or CentOS-Stream-9-20220829
SOURCE_IMAGE_NAME="${SOURCE_IMAGE_NAME:-CentOS-Stream-GenericCloud-9}"
# Group to add user to. To get sudo access on CentOS: wheel, on Ubuntu: sudo
USERDATA_SSH_USER_GROUP="${USERDATA_SSH_USER_GROUP:-wheel}"
# Openstack network name, vm will receive Openstack internal IP from this network.
OS_NETWORK_NAME="${OS_NETWORK_NAME:-}"
# Or if you want to use Openstack network ID instead of the network name set this instead
# (then network ID lookup won't happen):
OS_NETWORK_ID="${OS_NETWORK_ID:-}"
# IMAGE_DATE is used to distinguish between images because the openstack client
# can't download an image if there are multiple images present in OS with the same name
IMAGE_DATE="$(date +"%Y-%m-%dT%H-%M-%S%z")"
PACKER_DEBUG_ENABLED="${PACKER_DEBUG_ENABLED:-false}"
PACKER_BUILD_COMMAND=("build")
PACKER_INTERACTIVE=("--rm")
IMAGE_CLEANUP="${IMAGE_CLEANUP:-false}"


if [ "${PACKER_DEBUG_ENABLED}" = "true" ]; then
  PACKER_BUILD_COMMAND=("build" "-debug")
  PACKER_INTERACTIVE=("--rm" "-ti")
fi

# The variables below should not need to be touched by the user
if [[ "${PROVISIONING_SCRIPT}" == *"node"* ]]; then
  BUILDER_CONFIG_FILE="image_builder_template_node.json"
  IMAGE_FLAVOR="1C-4GB-20GB"
elif [[ "${PROVISIONING_SCRIPT}" == *"metal3"* ]]; then
  BUILDER_CONFIG_FILE="image_builder_template.json"
  IMAGE_FLAVOR="4C-16GB-50GB"
elif [[ "${PROVISIONING_SCRIPT}" == *"base"* ]]; then
  BUILDER_CONFIG_FILE="image_builder_template.json"
  IMAGE_FLAVOR="1C-4GB-20GB"
elif [ "${PROVISIONING_SCRIPT}" = "sandbox" ]; then
  echo "Local builder script will run in sandbox mode!"
else
  echo "Available provisioning scripts are:"
  find ../scripts/image_scripts/provision_* | cut -f4 -d'/'
  exit 1
fi

if [[ "${PROVISIONING_SCRIPT}" == *"centos"* ]]; then
  USER_DATA_TEMPLATE="centos_userdata.tpl"
else
  USER_DATA_TEMPLATE="ubuntu_userdata.tpl"
fi

DEV_TOOLS="$(dirname "$(readlink -f "${0}")")/../../"
OS_SCRIPTS_DIR="${DEV_TOOLS}/ci/scripts/openstack"
IMAGES_DIR="${DEV_TOOLS}/ci/images"

CR_CMD_ENV=(
  "--env" "OS_AUTH_URL"
  "--env" "OS_USER_DOMAIN_NAME"
  "--env" "OS_PROJECT_DOMAIN_NAME"
  "--env" "OS_REGION_NAME"
  "--env" "OS_PROJECT_NAME"
  "--env" "OS_TENANT_NAME"
  "--env" "OS_AUTH_VERSION"
  "--env" "OS_IDENTITY_API_VERSION"
  "--env" "OS_USERNAME"
  "--env" "OS_PASSWORD"
)


if [ "${PROVISIONING_SCRIPT}" = "sandbox" ]; then
  "${CONTAINER_RUNTIME}" run --rm -ti \
    "${CR_CMD_ENV[@]}" \
    "-v" "${DEV_TOOLS}:/data/metal3-dev-tools" \
    "-v" "/tmp:/tmp" \
    "registry.nordix.org/metal3/image-builder" \
    "/bin/bash"
  exit 0
fi

# Image name timestamp appending or cleanup based on config
if [ "${IMAGE_CLEANUP}" = "true" ]; then
  FULL_IMAGE_NAME="${IMAGE_NAME}"
  "${CONTAINER_RUNTIME}" run --rm \
    "${CR_CMD_ENV[@]}" \
    "registry.nordix.org/metal3/image-builder" \
    bash -c "openstack image delete ${FULL_IMAGE_NAME} || true"
else
  FULL_IMAGE_NAME="${IMAGE_NAME}-${IMAGE_DATE}"
fi

# Paths inside the container
CONTAINER_OS_UTILS="/data/metal3-dev-tools/ci/scripts/openstack/utils.sh"

# The network where the vm will get it's floating ip (external IP)
FLOATING_IP_NETWORK="ext-net"
REUSE_IPS="true"
# If NETWORK is not set directly, try to get it based on NETWORK_NAME.
if [ -z "${OS_NETWORK_ID}" ]; then
  OS_NETWORK_ID=$("${CONTAINER_RUNTIME}" run --rm \
            "${CR_CMD_ENV[@]}" \
	    "-v" "${DEV_TOOLS}":"/data/metal3-dev-tools" \
	    "registry.nordix.org/metal3/image-builder" \
            bash -c "source ${CONTAINER_OS_UTILS} && get_resource_id_from_name network ${OS_NETWORK_NAME}")
fi

# Generate user data and provision command

# shellcheck source=ci/scripts/openstack/utils.sh
source "${OS_SCRIPTS_DIR}/utils.sh"

TMP="$(mktemp -d)"
USER_DATA_FILE="${TMP}/userdata"
STARTER_SCRIPT_PATH="${TMP}/build_starter.sh"

REMOTE_EXEC_CMD="KUBERNETES_VERSION=${KUBERNETES_VERSION} /home/${PACKER_SSH_USER_NAME}/image_scripts/${PROVISIONING_SCRIPT}"
echo "${REMOTE_EXEC_CMD}" > "${STARTER_SCRIPT_PATH}"

USERDATA_SSH_AUTHORIZED_KEY="$(cat "${USERDATA_SSH_PUBLIC_KEY_FILE}")"
render_user_data \
  "${USERDATA_SSH_AUTHORIZED_KEY}" \
  "${USERDATA_SSH_USER_NAME}" \
  "${USERDATA_SSH_USER_GROUP}" \
  "${IMAGE_NAME}" \
  "${IMAGES_DIR}/${USER_DATA_TEMPLATE}" \
  "${USER_DATA_FILE}"

# Paths inside the container
CONTAINER_SCRIPTS_DIR="/data/metal3-dev-tools/ci/scripts/image_scripts"
CONTAINER_IMAGES_DIR="/data/metal3-dev-tools/ci/images"

# Run the packer build in a docker container
"${CONTAINER_RUNTIME}" run "${PACKER_INTERACTIVE[@]}" \
  "${CR_CMD_ENV[@]}" \
  -v "${DEV_TOOLS}":"/data/metal3-dev-tools" \
  -v "${PACKER_SSH_PRIVATE_KEY_FILE}":"/data/private_key" \
  -v "${TMP}":"${TMP}" \
  "registry.nordix.org/metal3/image-builder" \
  packer "${PACKER_BUILD_COMMAND[@]}" \
    -var "image_name=${FULL_IMAGE_NAME}" \
    -var "source_image_name=${SOURCE_IMAGE_NAME}" \
    -var "user_data_file=${USER_DATA_FILE}" \
    -var "exec_script_path=${STARTER_SCRIPT_PATH}" \
    -var "ssh_username=${PACKER_SSH_USER_NAME}" \
    -var "ssh_private_key_file=/data/private_key" \
    -var "network=${OS_NETWORK_ID}" \
    -var "floating_ip_net=${FLOATING_IP_NETWORK}" \
    -var "reuse_ips=${REUSE_IPS}" \
    -var "local_scripts_dir=${CONTAINER_SCRIPTS_DIR}" \
    -var "ssh_pty=true" \
    -var "flavor=${IMAGE_FLAVOR}" \
    "${CONTAINER_IMAGES_DIR}/${BUILDER_CONFIG_FILE}"

if [[ "${PROVISIONING_SCRIPT}" == *"node"* ]]; then 
  
  CR_CMD_ENV+=(
    "--env" "RT_URL"
    "--env" "RT_USER"
    "--env" "RT_TOKEN"
)

  "${CONTAINER_RUNTIME}" run --rm \
    "${CR_CMD_ENV[@]}" \
    -v "${DEV_TOOLS}:/data/metal3-dev-tools" \
    -v "/tmp:/tmp" \
    "registry.nordix.org/metal3/image-builder" \
    bash "/data/metal3-dev-tools/ci/scripts/image_scripts/upload_node_image_rt.sh" "${FULL_IMAGE_NAME}"
fi
