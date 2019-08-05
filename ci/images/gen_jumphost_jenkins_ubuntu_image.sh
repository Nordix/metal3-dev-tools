#! /usr/bin/env bash

set -eu

SSH_PRIVATE_KEY_FILE="${1:?}"
USE_FLOATING_IP="${2:?}"

CI_DIR="$(dirname "$(readlink -f "${0}")")/.."
IMAGES_DIR="${CI_DIR}/images"
SCRIPTS_DIR="${CI_DIR}/scripts"
OS_SCRIPTS_DIR="${CI_DIR}/scripts/openstack"

# shellcheck disable=SC1090
source "${OS_SCRIPTS_DIR}/infra_defines.sh"

# shellcheck disable=SC1090
source "${OS_SCRIPTS_DIR}/utils.sh"

IMAGE_NAME="${CI_JENKINS_IMAGE}-$(get_random_string 10)"
FINAL_IMAGE_NAME="${CI_JENKINS_IMAGE}"
SOURCE_IMAGE_NAME="${CI_BASE_IMAGE}"
USER_DATA_FILE="$(mktemp -d)/userdata"
SSH_USER_NAME="${CI_SSH_USER_NAME}"
SSH_KEYPAIR_NAME="${CI_KEYPAIR_NAME}"
NETWORK="$(get_resource_id_from_name network "${CI_EXT_NET}")"
FLOATING_IP_NETWORK="$( ([ "${USE_FLOATING_IP}" = 1 ] && echo "${EXT_NET}"))" || true
REMOTE_EXEC_CMD="/home/${SSH_USER_NAME}/scripts/provision_jumphost_jenkins_base_img.sh"

SOURCE_IMAGE="$(get_resource_id_from_name image "${SOURCE_IMAGE_NAME}")"
SSH_AUTHORIZED_KEY="$(cat "${OS_SCRIPTS_DIR}/id_rsa_airshipci.pub")"
render_user_data \
  "${SSH_AUTHORIZED_KEY}" \
  "${SSH_USER_NAME}" \
  "${IMAGES_DIR}/userdata.tpl" \
  "${USER_DATA_FILE}"

STARTER_SCRIPT_PATH="/tmp/build_starter.sh"
echo "${REMOTE_EXEC_CMD}" > "${STARTER_SCRIPT_PATH}"

# Build Image
packer build \
  -var "image_name=${IMAGE_NAME}" \
  -var "source_image=${SOURCE_IMAGE}" \
  -var "user_data_file=${USER_DATA_FILE}" \
  -var "exec_script_path=${STARTER_SCRIPT_PATH}" \
  -var "ssh_username=${SSH_USER_NAME}" \
  -var "ssh_keypair_name=${SSH_KEYPAIR_NAME}" \
  -var "ssh_private_key_file=${SSH_PRIVATE_KEY_FILE}" \
  -var "network=${NETWORK}" \
  -var "floating_ip_net=${FLOATING_IP_NETWORK}" \
  -var "local_scripts_dir=${SCRIPTS_DIR}" \
  "${IMAGES_DIR}/image_builder_template.json"

# Replace any old image

replace_image "${IMAGE_NAME}" "${FINAL_IMAGE_NAME}"
