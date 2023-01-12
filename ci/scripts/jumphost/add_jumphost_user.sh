#! /usr/bin/env bash

set -eu

# Description:
# Adds New User on Openstack Dev Jumphost. This script
# is executed remotely to connect to the jumphost and
# add user on it.
#   Requires:
#     - source stackrc file
#     - openstack dev infra and jumphost should already be deployed.
#     - environment variables set:
#       - METAL3_CI_USER: Ci user for jumphost.
#       - METAL3_CI_USER_KEY: Path of the CI user private key for jumphost.
#
# Usage:
#   add_jumphost_user.sh <user_name> <file_path_containing_all_user_keys>
#

CI_DIR="$(dirname "$(readlink -f "${0}")")/../.."
OS_SCRIPTS_DIR="${CI_DIR}/scripts/openstack"
RT_SCRIPTS_DIR="${CI_DIR}/scripts/artifactory"
JUMPHOST_SCRIPTS_DIR="${CI_DIR}/scripts/jumphost"

NEW_USER="${1:?}"
USER_AUTHORIZED_KEYS_FILE="${2:?}"

# shellcheck source=ci/scripts/artifactory/utils.sh
source "${RT_SCRIPTS_DIR}/utils.sh"
# shellcheck source=ci/scripts/openstack/utils.sh
source "${OS_SCRIPTS_DIR}/utils.sh"
# shellcheck source=ci/scripts/openstack/infra_defines.sh
source "${OS_SCRIPTS_DIR}/infra_defines.sh"
# shellcheck source=ci/scripts/jumphost/utils.sh
source "${JUMPHOST_SCRIPTS_DIR}/utils.sh"

JUMPHOST_PUBLIC_IP="$(get_dev_jumphost_public_ip)"

echo "DEV Jumphost Public IP = ${JUMPHOST_PUBLIC_IP}"
wait_for_ssh "${METAL3_CI_USER}" "${METAL3_CI_USER_KEY}" "${JUMPHOST_PUBLIC_IP}"

# Send Authorized KEYS file to Jumphost
scp \
  -o StrictHostKeyChecking=no \
  -o UserKnownHostsFile=/dev/null \
  -i "${METAL3_CI_USER_KEY}" \
  "${USER_AUTHORIZED_KEYS_FILE}" \
  "${METAL3_CI_USER}@${JUMPHOST_PUBLIC_IP}:/tmp/${NEW_USER}_auth_keys" > /dev/null

# Send Remote script to Jumphost
scp \
  -o StrictHostKeyChecking=no \
  -o UserKnownHostsFile=/dev/null \
  -i "${METAL3_CI_USER_KEY}" \
  "${JUMPHOST_SCRIPTS_DIR}/files/add_proxy_user.sh" \
  "${METAL3_CI_USER}@${JUMPHOST_PUBLIC_IP}:/tmp/" > /dev/null

# Execute remote script
# shellcheck disable=SC2029
ssh \
  -o StrictHostKeyChecking=no \
  -o UserKnownHostsFile=/dev/null \
  -i "${METAL3_CI_USER_KEY}" \
  "${METAL3_CI_USER}"@"${JUMPHOST_PUBLIC_IP}" \
  /tmp/add_proxy_user.sh "${NEW_USER}" "/tmp/${NEW_USER}_auth_keys" > /dev/null

echo "User[${NEW_USER}] added successfully"
