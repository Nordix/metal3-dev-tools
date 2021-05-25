#! /usr/bin/env bash

set -eu

SSH_PRIVATE_KEY_FILE="${1:?}"
USE_FLOATING_IP="${2:?}"
PROVISIONING_SCRIPT="${3:?}"

CI_DIR="$(dirname "$(readlink -f "${0}")")/.."
IMAGES_DIR="${CI_DIR}/images"
SCRIPTS_DIR="${CI_DIR}/scripts/image_scripts"
OS_SCRIPTS_DIR="${CI_DIR}/scripts/openstack"
CENTOS_VERSION="8.2"
KUBERNETES_VERSION=${KUBERNETES_VERSION:-"v1.21.1"}

# shellcheck disable=SC1090
source "${OS_SCRIPTS_DIR}/infra_defines.sh"

if [[ "$PROVISIONING_SCRIPT" == *"node"* ]]; then
  CI_IMAGE_NAME="${CI_NODE_CENTOS_IMAGE}"
  BUILDER_CONFIG_FILE="image_builder_template_node.json"
  IMAGE_FLAVOR="1C-4GB-20GB"
  FINAL_IMAGE_NAME="CENTOS_"${CENTOS_VERSION}"_NODE_IMAGE_K8S_""${KUBERNETES_VERSION}"
elif [[ "$PROVISIONING_SCRIPT" == *"metal3"* ]]; then
  CI_IMAGE_NAME="${CI_METAL3_CENTOS_IMAGE}"
  BUILDER_CONFIG_FILE="image_builder_template.json"
  IMAGE_FLAVOR="4C-16GB-50GB"
  FINAL_IMAGE_NAME="${CI_IMAGE_NAME}"
else
  echo "Available provisioning scripts are:"
  echo "$(ls -l ../scripts/image_scripts/provision_* | cut -f4 -d'/')"
  echo "Example:"
  echo "./gen_metal3_centos_image.sh /data/keys/id_rsa_airshipci 1 provision_node_image_centos.sh"
  exit 1
fi

# shellcheck disable=SC1090
source "${OS_SCRIPTS_DIR}/utils.sh"

IMAGE_NAME="${CI_IMAGE_NAME}-$(get_random_string 10)"
SOURCE_IMAGE_NAME="ea0091dc-ccb5-401e-bc64-2615321b4087"
USER_DATA_FILE="$(mktemp -d)/userdata"
SSH_USER_NAME="${CI_SSH_USER_NAME}"
SSH_KEYPAIR_NAME="${CI_KEYPAIR_NAME}"
NETWORK="$(get_resource_id_from_name network "${CI_EXT_NET}")"
FLOATING_IP_NETWORK="$( [ "${USE_FLOATING_IP}" = 1 ] && echo "${EXT_NET}")"
REMOTE_EXEC_CMD="/home/${SSH_USER_NAME}/image_scripts/${PROVISIONING_SCRIPT}"
SSH_USER_GROUP="wheel"
SOURCE_IMAGE="$(get_resource_id_from_name image "${SOURCE_IMAGE_NAME}")"
SSH_AUTHORIZED_KEY="$(cat "${OS_SCRIPTS_DIR}/id_rsa_airshipci.pub")"
render_user_data \
  "${SSH_AUTHORIZED_KEY}" \
  "${SSH_USER_NAME}" \
  "${SSH_USER_GROUP}" \
  "${IMAGE_NAME}" \
  "${IMAGES_DIR}/centos_userdata.tpl" \
  "${USER_DATA_FILE}"

STARTER_SCRIPT_PATH="/tmp/build_starter.sh"
echo "${REMOTE_EXEC_CMD}" > "${STARTER_SCRIPT_PATH}"

# Create CI Keypair
CI_PUBLIC_KEY_FILE="${OS_SCRIPTS_DIR}/id_rsa_airshipci.pub"
delete_keypair "${SSH_KEYPAIR_NAME}"
create_keypair "${CI_PUBLIC_KEY_FILE}" "${SSH_KEYPAIR_NAME}"

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
  -var "ssh_pty=true" \
  -var "flavor=${IMAGE_FLAVOR}" \
  "${IMAGES_DIR}/${BUILDER_CONFIG_FILE}"

# Replace any old image

replace_image "${IMAGE_NAME}" "${FINAL_IMAGE_NAME}"

# upload node image to artifactory
if [[ "$PROVISIONING_SCRIPT" == *"node"* ]]; then
  bash "${SCRIPTS_DIR}/upload_node_image_rt.sh" "${FINAL_IMAGE_NAME}"
fi
