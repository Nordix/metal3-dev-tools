#! /usr/bin/env bash

set -eux

# Description:
# Deletes User on Openstack Dev Jumphost.
#
# Requires:
#  - source stackrc file
#
# Usage:
#   dev_jumphost_user.sh <user_name>
#

CI_DIR="$(dirname "$(readlink -f "${0}")")/../.."
OS_SCRIPTS_DIR="${CI_DIR}/scripts/openstack"
RT_SCRIPTS_DIR="${CI_DIR}/scripts/artifactory"
JUMPHOST_SCRIPTS_DIR="${CI_DIR}/scripts/jumphost"

_USER="${1:?}"

# shellcheck disable=SC1090
source "${RT_SCRIPTS_DIR}/utils.sh"
# shellcheck disable=SC1090
source "${OS_SCRIPTS_DIR}/utils.sh"
# shellcheck disable=SC1090
source "${OS_SCRIPTS_DIR}/infra_defines.sh"
# shellcheck disable=SC1090
source "${JUMPHOST_SCRIPTS_DIR}/utils.sh"

JUMPHOST_PUBLIC_IP="$(get_dev_jumphost_public_ip)"

echo "DEV Jumphost Public IP = ${JUMPHOST_PUBLIC_IP}"
wait_for_ssh "${METAL3_CI_USER}" "${METAL3_CI_USER_KEY}" "${JUMPHOST_PUBLIC_IP}"

# Execute remote script to delete user
# shellcheck disable=SC2029
ssh \
  -o StrictHostKeyChecking=no \
  -o UserKnownHostsFile=/dev/null \
  -i "${METAL3_CI_USER_KEY}" \
  "${METAL3_CI_USER}"@"${JUMPHOST_PUBLIC_IP}" \
  "sudo deluser --remove-all-files ${_USER}"
