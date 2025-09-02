#! /usr/bin/env bash

set -euo pipefail

# Description:
# Deletes user on Openstack jumphost.
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
COMMON_SCRIPTS_DIR="${CI_DIR}/scripts/common"
JUMPHOST_SCRIPTS_DIR="${CI_DIR}/scripts/jumphost"

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
        --one-liner "Remove a user to the jumphost." \
        --arguments "<user>" \
        ${COMMON_OPT_HELP} \
        ${COMMON_OPT_KEYFILE} \
        ${COMMON_OPT_TARGET} \
        ${COMMON_OPT_USER} \
        ${COMMON_OPT_VERBOSE})
common_parse_options "${USAGE}" "$@"

# Arguments
_USER=${COMMON_OPT_ARGUMENTS[0]:-}
[[ -z "${_USER}" ]] && {
    echo >&2 "Error: no user argument specified"
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

# Run a command remotely to remove the user
# shellcheck disable=SC2029
common_verbose "Running deluser for ${_USER} on ${JUMPHOST_PUBLIC_IP}"
ssh \
  -o StrictHostKeyChecking=no \
  -o UserKnownHostsFile=/dev/null \
  -i "${COMMON_OPT_KEYFILE_VALUE}" \
  "${COMMON_OPT_USER_VALUE}"@"${JUMPHOST_PUBLIC_IP}" \
  "sudo deluser --remove-all-files ${_USER}"
