#! /usr/bin/env bash

set -eu

# Description:
#   Deletes a dev jumphost in openstack environment
#   Requires:
#     - source stackrc file
# Usage:
#  delete_dev_jumphost.sh
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
JUMPHOST_FLAVOR="4C-16GB-50GB"

# Get the jumphost ID
JUMPHOST_SERVER_ID="$(openstack server list --name "${DEV_JUMPHOST_NAME}" -f json \
  | jq -r 'map(.ID) | @csv' \
  | tr ',' '\n' \
  | tr -d '"')"

# Get the floating IP
FLOATING_IP_ID="$(openstack floating ip list --tags "${DEV_JUMPHOST_FLOATING_IP_TAG}" -f json \
    | jq -r 'map(.ID) | @csv' \
    | tr ',' '\n' \
    | tr -d '"')"

# Delete the jumphost
if [ -n "${JUMPHOST_SERVER_ID}" ]
then
  openstack server delete "${DEV_JUMPHOST_NAME}"
fi

# Unset the floating ip, keep it to reuse later
if [ -n "${FLOATING_IP_ID}" ]
then
  openstack floating ip unset --port "${FLOATING_IP_ID}"
fi

# Cleanup any stale ports
delete_port "${JUMPOST_EXT_PORT_NAME}"

# Cleanup security group
delete_sg "${DEV_JUMPHOST_EXT_SG}"
