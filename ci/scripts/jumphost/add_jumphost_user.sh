#! /usr/bin/env bash

set -euo pipefail

# Description:
# Adds new user on Openstack Jumphost.
#   Requires:
#     - source stackrc file
#     - openstack infra and jumphost should already be deployed
#
# Usage:
#   add_jumphost_user.sh <user_name> <file_path_containing_all_user_keys>
#

CI_DIR="$(dirname "$(readlink -f "${0}")")/../.."
RT_SCRIPTS_DIR="${CI_DIR}/scripts/artifactory"
JUMPHOST_SCRIPTS_DIR="${CI_DIR}/scripts/jumphost"
COMMON_SCRIPTS_DIR="${CI_DIR}/scripts/common"
OS_SCRIPTS_DIR="${CI_DIR}/scripts/openstack"

# shellcheck source=ci/scripts/common/opts.sh
. "${COMMON_SCRIPTS_DIR}/opts.sh"
# shellcheck source=ci/scripts/common/utils.sh
. "${COMMON_SCRIPTS_DIR}/utils.sh"
# shellcheck source=ci/scripts/artifactory/utils.sh
. "${RT_SCRIPTS_DIR}/utils.sh"
# shellcheck source=ci/scripts/openstack/utils.sh
. "${OS_SCRIPTS_DIR}/utils.sh"
# shellcheck source=ci/scripts/openstack/infra_defines.sh
. "${OS_SCRIPTS_DIR}/infra_defines.sh"
# shellcheck source=ci/scripts/jumphost/utils.sh
. "${JUMPHOST_SCRIPTS_DIR}/utils.sh"

USAGE=$(common_make_usage_string \
        --one-liner "Create a user to the jumphost." \
        --arguments "<new-user> <authorized-keys-file>" \
        ${COMMON_OPT_HELP} \
        ${COMMON_OPT_KEYFILE} \
        ${COMMON_OPT_TARGET} \
        ${COMMON_OPT_USER} \
        ${COMMON_OPT_VERBOSE})
common_parse_options "${USAGE}" "$@"

# Arguments
NEW_USER=${COMMON_OPT_ARGUMENTS[0]:-}
[[ -z "${NEW_USER}" ]] && {
    echo >&2 "Error: no user argument specified"
    exit 1
}
USER_AUTHORIZED_KEYS_FILE=${COMMON_OPT_ARGUMENTS[1]:-}
[[ -z "${USER_AUTHORIZED_KEYS_FILE}" ]] && {
    echo >&2 "Error: no authorized keys specified"
    exit 1
}

# Sanity checks
# =============
common_validate_target
common_validate_keyfile
common_validate_user

JUMPHOST_FLOATING_IP_TAG="${COMMON_OPT_TARGET_VALUE}_JUMPHOST_FLOATING_IP_TAG"

common_verbose "Resolving public IP for a jumpost with tag"\
               "${!JUMPHOST_FLOATING_IP_TAG}"
JUMPHOST_PUBLIC_IP="$(get_jumphost_public_ip "${!JUMPHOST_FLOATING_IP_TAG}")"
if [[ -z "${JUMPHOST_PUBLIC_IP}" ]]; then
  echo >&2 "Error: no public IP found for a jumpost with tag"\
           "${!JUMPHOST_FLOATING_IP_TAG}"
  exit 1
fi
common_verbose "Jumphost public IP = ${JUMPHOST_PUBLIC_IP}"

# Send the new user's SSH keys to jumphost
common_verbose "Copy SSH key ${USER_AUTHORIZED_KEYS_FILE} to"\
               "${JUMPHOST_PUBLIC_IP}:/tmp/${NEW_USER}_auth_keys..."
scp \
  -o StrictHostKeyChecking=no \
  -o UserKnownHostsFile=/dev/null \
  -i "${COMMON_OPT_KEYFILE_VALUE}" \
  "${USER_AUTHORIZED_KEYS_FILE}" \
  "${COMMON_OPT_USER_VALUE}@${JUMPHOST_PUBLIC_IP}:/tmp/${NEW_USER}_auth_keys" > /dev/null

# Send the remote script to jumphost
common_verbose "Copy ${JUMPHOST_SCRIPTS_DIR}/files/add_proxy_user.sh to"\
               "${JUMPHOST_PUBLIC_IP}:/tmp/..."
scp \
  -o StrictHostKeyChecking=no \
  -o UserKnownHostsFile=/dev/null \
  -i "${COMMON_OPT_KEYFILE_VALUE}" \
  "${JUMPHOST_SCRIPTS_DIR}/files/add_proxy_user.sh" \
  "${COMMON_OPT_USER_VALUE}@${JUMPHOST_PUBLIC_IP}:/tmp/" > /dev/null

# Execute the remote script
# shellcheck disable=SC2029
common_verbose "Running the script with ${NEW_USER} /tmp/${NEW_USER}_auth_keys"
ssh \
  -o StrictHostKeyChecking=no \
  -o UserKnownHostsFile=/dev/null \
  -i "${COMMON_OPT_KEYFILE_VALUE}" \
  "${COMMON_OPT_USER_VALUE}"@"${JUMPHOST_PUBLIC_IP}" \
  /tmp/add_proxy_user.sh "${NEW_USER}" "/tmp/${NEW_USER}_auth_keys" > /dev/null

echo "User[${NEW_USER}] updated"
