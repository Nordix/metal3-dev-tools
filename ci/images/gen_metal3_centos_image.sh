#! /usr/bin/env bash

set -eux

SSH_PRIVATE_KEY_FILE="${1:?}"
USE_FLOATING_IP="${2:?}"
PROVISIONING_SCRIPT="${3:?}"

CI_DIR="$(dirname "$(readlink -f "${0}")")/.."
IMAGES_DIR="${CI_DIR}/images"
SCRIPTS_DIR="${CI_DIR}/scripts/image_scripts"
OS_SCRIPTS_DIR="${CI_DIR}/scripts/openstack"
CENTOS_VERSION="9"
KUBERNETES_VERSION=${KUBERNETES_VERSION:-"v1.29.0"}

# shellcheck source=ci/scripts/openstack/infra_defines.sh
source "${OS_SCRIPTS_DIR}/infra_defines.sh"

if [[ "$PROVISIONING_SCRIPT" == *"node"* ]]; then
  CI_IMAGE_NAME="${CI_NODE_CENTOS_IMAGE}"
  CI_KEYPAIR_NAME="metal3ci-key-centos"
  BUILDER_CONFIG_FILE="image_builder_template_node.json"
  IMAGE_FLAVOR="1C-4GB-20GB"
  FINAL_IMAGE_NAME=${FINAL_IMAGE_NAME:-"CENTOS_${CENTOS_VERSION}_NODE_IMAGE_K8S_${KUBERNETES_VERSION}"}
elif [[ "$PROVISIONING_SCRIPT" == *"metal3"* ]]; then
  CI_IMAGE_NAME="${CI_METAL3_CENTOS_IMAGE}"
  CI_KEYPAIR_NAME="metal3ci-key-centos"
  BUILDER_CONFIG_FILE="image_builder_template.json"
  IMAGE_FLAVOR="4C-16GB-50GB"
  FINAL_IMAGE_NAME="${CI_IMAGE_NAME}"
else
  PROVISIONING_SCRIPTS=("${CI_DIR}"/scripts/image_scripts/provision_{node,metal3}_image_centos.sh)
  echo """
Available provisioning scripts are: ${PROVISIONING_SCRIPTS[*]}
Example:
$(realpath "$0") /data/keys/id_ed25519_metal3ci 1 ${PROVISIONING_SCRIPTS[0]:-}"""
  exit 1
fi

# shellcheck source=ci/scripts/openstack/utils.sh
source "${OS_SCRIPTS_DIR}/utils.sh"

IMAGE_NAME="${CI_IMAGE_NAME}-$(get_random_string 10)"
SOURCE_IMAGE_NAME="CentOS-Stream-9-20230925"
USER_DATA_FILE="$(mktemp -d)/userdata"
SSH_USER_NAME="${CI_SSH_USER_NAME}"
SSH_KEYPAIR_NAME="${CI_KEYPAIR_NAME}"
NETWORK="$(get_resource_id_from_name network "${CI_EXT_NET}")"
FLOATING_IP_NETWORK="$( [ "${USE_FLOATING_IP}" = 1 ] && echo "${EXT_NET}")"
SSH_USER_GROUP="wheel"

if [[ "$PROVISIONING_SCRIPT" == *"node"* ]]; then
  REMOTE_EXEC_CMD="KUBERNETES_VERSION=${KUBERNETES_VERSION} CRIO_VERSION=${CRIO_VERSION} CRICTL_VERSION=${CRICTL_VERSION} /home/${SSH_USER_NAME}/image_scripts/${PROVISIONING_SCRIPT}"
elif [[ "$PROVISIONING_SCRIPT" == *"metal3"* ]]; then
  REMOTE_EXEC_CMD="KUBERNETES_VERSION=${KUBERNETES_VERSION} /home/${SSH_USER_NAME}/image_scripts/${PROVISIONING_SCRIPT}"
fi

SSH_AUTHORIZED_KEY="$(cat "${OS_SCRIPTS_DIR}/id_ed25519_metal3ci.pub")"
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
CI_PUBLIC_KEY_FILE="${OS_SCRIPTS_DIR}/id_ed25519_metal3ci.pub"
delete_keypair "${SSH_KEYPAIR_NAME}"
create_keypair "${CI_PUBLIC_KEY_FILE}" "${SSH_KEYPAIR_NAME}"

# Build Image
packer build \
  -var "image_name=${IMAGE_NAME}" \
  -var "source_image_name=${SOURCE_IMAGE_NAME}" \
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

# Replace image. Backup image if it is building Metal3 image in Kna region
# We keep metal3 backup images in only Kna region
if [[ "${PROVISIONING_SCRIPT}" == *"metal3-img"* ]] && [[ "${OS_REGION_NAME}" == "Kna1" ]]; then
  backup_and_replace_image "${IMAGE_NAME}" "${FINAL_IMAGE_NAME}"
else
  replace_image "${IMAGE_NAME}" "${FINAL_IMAGE_NAME}"
fi

# upload node image to artifactory
if [[ "$PROVISIONING_SCRIPT" == *"node"* ]]; then
  bash "${SCRIPTS_DIR}/upload_node_image_rt.sh" "${FINAL_IMAGE_NAME}"
fi
