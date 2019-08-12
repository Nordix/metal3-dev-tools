#! /usr/bin/env bash

set -eu

# Description:
#   Creates or updates a dev jumphost in openstack environment
#   and adds jumphost users on the jumphost fetching the user
#   from artifactory.
#   Requires:
#     - source stackrc file
#     - openstack dev infra should already be deployed.
#     - environment variables set:
#       - AIRSHIP_CI_USER: Ci user for jumphost.
#       - AIRSHIP_CI_USER_KEY: Path of the CI user private key for jumphost.
#       - RT_URL: artifactory URL.
# Usage:
#  create_or_update_dev_jumphost.sh
#

CI_DIR="$(dirname "$(readlink -f "${0}")")/../.."
OS_SCRIPTS_DIR="${CI_DIR}/scripts/openstack"
RT_SCRIPTS_DIR="${CI_DIR}/scripts/artifactory"
JUMPHOST_SCRIPTS_DIR="${CI_DIR}/scripts/jumphost"

# shellcheck disable=SC1090
source "${RT_SCRIPTS_DIR}/utils.sh"
# shellcheck disable=SC1090
source "${OS_SCRIPTS_DIR}/utils.sh"
# shellcheck disable=SC1090
source "${OS_SCRIPTS_DIR}/infra_defines.sh"

JUMPOST_EXT_PORT_NAME="${DEV_JUMPHOST_NAME}-ext-port"
JUMPHOST_FLAVOR="1C-2GB-50GB"

# Create or rebuild jumphost image
JUMPHOST_SERVER_ID="$(openstack server list --name "${DEV_JUMPHOST_NAME}" -f json \
  | jq -r 'map(.ID) | @csv' \
  | tr ',' '\n' \
  | tr -d '"')"

if [ -n "${JUMPHOST_SERVER_ID}" ]
then
  echo "Rebuilding DEV Jumphost with ID[${JUMPHOST_SERVER_ID}]."
  openstack server rebuild --image "${CI_JENKINS_IMAGE}" "${JUMPHOST_SERVER_ID}" > /dev/null
else

  # Cleanup any stale ports
  echo "Cleaning up networking."
  delete_port "${JUMPOST_EXT_PORT_NAME}"

  # Cleanup security group
  delete_sg "${DEV_JUMPHOST_EXT_SG}"

  #Create security group
  echo "Creating new security group."
  SG_ID="$(openstack security group create -f json "${DEV_JUMPHOST_EXT_SG}" | \
    jq -r '.id')"
  openstack security group rule create --ingress --description ssh \
    --ethertype IPv4 --protocol tcp --dst-port 22 "${SG_ID}" > /dev/null

  # Create new ports
  echo "Creating new jumphost port."
  EXT_PORT_ID="$(openstack port create -f json \
    --network "${DEV_EXT_NET}" \
    --fixed-ip subnet="$(get_subnet_name "${DEV_EXT_NET}")" \
    --enable-port-security \
    --security-group "${SG_ID}" \
    "${JUMPOST_EXT_PORT_NAME}" | jq -r '.id')"

  # Create new jumphost
  echo "Creating new jumphost Server."
  JUMPHOST_SERVER_ID="$(openstack server create -f json \
    --image "${CI_JENKINS_IMAGE}" \
    --flavor "${JUMPHOST_FLAVOR}" \
    --port "${EXT_PORT_ID}" \
    "${DEV_JUMPHOST_NAME}" | jq -r '.id')"
fi

# Recycle or create floating IP and assign it to jumphost port
FLOATING_IP_ID="$(openstack floating ip list --tags "${DEV_JUMPHOST_FLOATING_IP_TAG}" -f json \
    | jq -r 'map(.ID) | @csv' \
    | tr ',' '\n' \
    | tr -d '"')"

if [ -n "${FLOATING_IP_ID}" ]
then
  echo "Unattaching and Attaching floating IP to updated Jumphost port"
  openstack floating ip unset --port "${FLOATING_IP_ID}" > /dev/null
  openstack floating ip set --port "${JUMPOST_EXT_PORT_NAME}" "${FLOATING_IP_ID}" > /dev/null
else

  echo "Creating new jumphost floating ip"
  FLOATING_IP_ID="$(openstack floating ip create -f json \
    --port "${JUMPOST_EXT_PORT_NAME}" \
    --tag "${DEV_JUMPHOST_FLOATING_IP_TAG}" \
    "${EXT_NET}" | jq -r '.id')"
fi

FLOATING_IP_ADDRESS="$(openstack floating ip list --tags "${DEV_JUMPHOST_FLOATING_IP_TAG}" -f json \
  | jq -r 'map(."Floating IP Address") | @csv' \
  | tr ',' '\n' \
  | tr -d '"')"

echo "DEV Jumphost Public IP = ${FLOATING_IP_ADDRESS}"

wait_for_ssh "${AIRSHIP_CI_USER}" "${AIRSHIP_CI_USER_KEY}" "${FLOATING_IP_ADDRESS}"


# Update Authorized users in Jumphost
"${JUMPHOST_SCRIPTS_DIR}/update_dev_jumphost_users.sh"
