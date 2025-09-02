#! /usr/bin/env bash

set -euo pipefail

# Description:
# Reads all the users and their keys from artifatory and
# create or update those users' keys on dev jumphost.
#
# Requires:
#     - source stackrc file
#     - openstack dev infra and jumphost should already be deployed.
#
# Usage:
#  update_dev_jumphost_users.sh <user-name>
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
# shellcheck source=ci/scripts/jumphost/utils.sh
. "${JUMPHOST_SCRIPTS_DIR}/utils.sh"
# shellcheck source=ci/scripts/openstack/infra_defines.sh
. "${OS_SCRIPTS_DIR}/infra_defines.sh"

# shellcheck disable=SC2140
USAGE=$(common_make_usage_string \
        --one-liner "Add public keys for the users found in the "\
"artifactory to the jumphost." \
        --arguments "<user>" \
        ${COMMON_OPT_HELP} \
        ${COMMON_OPT_KEYFILE} \
        ${COMMON_OPT_RTURL} \
        ${COMMON_OPT_TARGET} \
        ${COMMON_OPT_USER} \
        ${COMMON_OPT_VERBOSE})
common_parse_options "${USAGE}" "$@"

# Arguments
_USER=${COMMON_OPT_ARGUMENTS[0]:-"all"}

# Sanity checks
# =============
common_validate_target
common_validate_keyfile
common_validate_rturl
common_validate_user

export RT_URL="${COMMON_OPT_RTURL_VALUE}"

# Fetch List of users from artifactory
common_verbose "Fetching user list from ${RT_URL}/${RT_USERS_DIR}..."
USERS="$(rt_list_directory "${RT_USERS_DIR}" \
  | jq -r '.children[] | select(.folder==true) |.uri')"

# Iterate over all users and add user to jumphost
for JH_USER in ${USERS}
do
  # If a user name is given, update only the specified user
  [[ -n "${_USER}" ]] && \
     [[ "${_USER}" != "all" ]] && \
     [[ "${JH_USER//\//}" != "${_USER}" ]] && continue
  USER_KEY_FILE="$(mktemp)"
  common_verbose "Fetching public key for ${JH_USER}..."
  _USER_KEYS="$(rt_get_user_public_keys "${JH_USER//\//}")"
  echo "${_USER_KEYS}" > "${USER_KEY_FILE}"
  common_verbose "Injecting public key for ${JH_USER}..."
  ARGS=(
    -t "${COMMON_OPT_TARGET_VALUE}"
    -u "${COMMON_OPT_USER_VALUE}"
    -k "${COMMON_OPT_KEYFILE_VALUE}"
  )
  [[ "${COMMON_OPT_VERBOSE_VALUE}" == "true" ]] && { ARGS+=("-v"); }
  "${JUMPHOST_SCRIPTS_DIR}"/add_jumphost_user.sh "${ARGS[@]}" "${JH_USER//\//}" \
    "${USER_KEY_FILE}"
  rm -f "${USER_KEY_FILE}"
done
