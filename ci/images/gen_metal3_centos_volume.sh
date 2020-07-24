#! /usr/bin/env bash

set -eu

SSH_PRIVATE_KEY_FILE="${1:?}"
USE_FLOATING_IP="${2:?}"

CI_DIR="$(dirname "$(readlink -f "${0}")")/.."
IMAGES_DIR="${CI_DIR}/images"
OS_SCRIPTS_DIR="${CI_DIR}/scripts/openstack"
IMAGE_SCRIPTS_DIR="${CI_DIR}/scripts/image_scripts"

# shellcheck disable=SC1090
source "${OS_SCRIPTS_DIR}/infra_defines.sh"

# shellcheck disable=SC1090
source "${OS_SCRIPTS_DIR}/utils.sh"

VM_NAME="${VM_PREFIX_CENTOS}-${VM_KEY}"
VM_PORT_NAME="${VM_NAME}-int-port"
BUILDER_VOLUME_NAME="${VM_PREFIX_CENTOS}-${VM_KEY}"
BASE_VOLUME_NAME="metal3-centos"
VOLUME_SIZE="50"
CI_INSTALLER_VM_FLAVOR="4C-8GB"
SSH_USER_NAME="${CI_SSH_USER_NAME}"
SSH_KEYPAIR_NAME="${CI_KEYPAIR_NAME}"
NETWORK="$(get_resource_id_from_name network "${CI_EXT_NET}")"

# Create CI Keypair
CI_PUBLIC_KEY_FILE="${OS_SCRIPTS_DIR}/id_rsa_airshipci.pub"
delete_keypair "${SSH_KEYPAIR_NAME}"
create_keypair "${CI_PUBLIC_KEY_FILE}" "${SSH_KEYPAIR_NAME}"

# Create a volume from SOURCE_IMAGE_NAME
echo "Creating a volume..."
create_volume "${CI_METAL3_CENTOS_IMAGE}" "${VOLUME_SIZE}" "${BUILDER_VOLUME_NAME}"

# Wait for a volume to be available...
echo "Waiting for a volume to be available..."
retry=0
until openstack volume show "${BUILDER_VOLUME_NAME}" -f json \
  | jq .status | grep "available"
do
  sleep 10
  # Check if volume creation is failed
  if [[ "$(openstack volume show "${BUILDER_VOLUME_NAME}" -f json \
    | jq .status)" == "error" ]];
  then
    echo "Volume creation is failed"
    # If volume creation is failed, then retry volume creation only once
    if [ $retry -eq 0 ]; then
      echo "Deleting a volume that failed to be created..."
      openstack volume delete "${BUILDER_VOLUME_NAME}"
      echo "Creating another new volume..."
      create_volume "${CI_METAL3_CENTOS_IMAGE}" "${VOLUME_SIZE}" "${BUILDER_VOLUME_NAME}"
      retry=1
    else
      exit 1
    fi
    continue
  fi
done

# Create a new port to get the IP immediately
echo "Creating a new port to get an IP address..."
PRIVATE_PORT_ID="$(openstack port create -f json \
  --network "${CI_EXT_NET}" \
  --fixed-ip subnet="$(get_subnet_name "${CI_EXT_NET}")" \
  "${VM_PORT_NAME}" | jq -r '.id')"

# Create a floating IP address
if [[ "$USE_FLOATING_IP" -ne 1 ]]; then
  echo "Floating IP address is not used..."
else
  echo "Creating a floating IP address..."
  FLOATING_IP_ID="$(openstack floating ip create --port "${PRIVATE_PORT_ID}" -f json \
  "${EXT_NET}" | jq -r '.id')"
fi

# Create a package installer VM from volume
echo "Creating a package installer VM from volume..."
PACKAGE_INSTALLER_VM_ID="$(openstack server create -f json \
  --volume "${BUILDER_VOLUME_NAME}" \
  --flavor "${CI_INSTALLER_VM_FLAVOR}" \
  --port "${PRIVATE_PORT_ID}" \
  --key-name "${SSH_KEYPAIR_NAME}" \
  "${VM_NAME}" | jq -r '.id')"

if [[ "$USE_FLOATING_IP" -ne 1 ]]; then
  echo "Floating IP address is not used..."
  echo "Getting the IP of package installer VM..."
  PACKAGE_INSTALLER_VM_IP="$(openstack port show -f json "${VM_PORT_NAME}" \
    | jq -r '.fixed_ips[0].ip_address')"
else
  echo "Getting the floating IP of package installer VM..."
  PACKAGE_INSTALLER_VM_IP="$(openstack floating ip show -f json "${FLOATING_IP_ID}" \
    | jq -r '.floating_ip_address')"
fi

# Wait for the host to come up
echo "Waiting for the host ${VM_NAME} to come up..."
wait_for_ssh "${SSH_USER_NAME}" "${SSH_PRIVATE_KEY_FILE}" "${PACKAGE_INSTALLER_VM_IP}"

# Copy provision_metal3_image_centos.sh and reset_cloud_init.sh scripts to package installer VM
echo "Copying provision_metal3_image_centos.sh and reset_cloud_init.sh scripts to package installer VM..."
scp \
  -o StrictHostKeyChecking=no \
  -o UserKnownHostsFile=/dev/null \
  -i "${SSH_PRIVATE_KEY_FILE}" \
  "${IMAGE_SCRIPTS_DIR}/provision_metal3_image_centos.sh" "${IMAGE_SCRIPTS_DIR}/reset_cloud_init.sh" \
  "${SSH_USER_NAME}@${PACKAGE_INSTALLER_VM_IP}:/tmp/" > /dev/null

# Execute provision_metal3_image_centos.sh script
# shellcheck disable=SC2029
echo "Executing provision_metal3_image_centos.sh script..."
ssh \
  -o StrictHostKeyChecking=no \
  -o UserKnownHostsFile=/dev/null \
  -o ServerAliveInterval=15 \
  -o ServerAliveCountMax=10 \
  -i "${SSH_PRIVATE_KEY_FILE}" \
  "${SSH_USER_NAME}"@"${PACKAGE_INSTALLER_VM_IP}" \
  PATH=/usr/local/bin:/usr/bin:/usr/local/sbin:/usr/sbin:/sbin:/bin \
  /tmp/provision_metal3_image_centos.sh true

# Delete the floating IP of installer VM
if [[ "$USE_FLOATING_IP" -ne 1 ]]; then
  echo "No floating IP address is found to delete..."
else
  echo "Deleting the package installer VM's floating IP..."
  openstack floating ip delete "${FLOATING_IP_ID}"
fi

# Delete the package installer VM
echo "Deleting the package installer VM..."
openstack server delete "${PACKAGE_INSTALLER_VM_ID}"

# Delete the package installer VM's port
echo "Deleting the package installer VM's port..."
openstack port delete "${PRIVATE_PORT_ID}"

# Replace the base volume with final volume
echo "Replacing the base volume with final volume..."
replace_volume "${BUILDER_VOLUME_NAME}" "${BASE_VOLUME_NAME}"