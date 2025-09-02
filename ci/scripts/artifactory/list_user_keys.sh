#! /usr/bin/env bash

set -euo pipefail

# Description:
#   List User Keys in artifactory.
#   Requires:
#     - jq installed
#
# Usage:
#   list_user_keys.sh
#

CI_DIR="$(dirname "$(readlink -f "${0}")")/../.."
RT_SCRIPTS_DIR="${CI_DIR}/scripts/artifactory"
COMMON_SCRIPTS_DIR="${CI_DIR}/scripts/common"
OS_SCRIPTS_DIR="${CI_DIR}/scripts/openstack"

# shellcheck source=ci/scripts/common/opts.sh
. "${COMMON_SCRIPTS_DIR}/opts.sh"
# shellcheck source=ci/scripts/common/utils.sh
. "${COMMON_SCRIPTS_DIR}/utils.sh"
# shellcheck source=ci/scripts/artifactory/utils.sh
. "${RT_SCRIPTS_DIR}/utils.sh"
# shellcheck source=ci/scripts/openstack/infra_defines.sh
. "${OS_SCRIPTS_DIR}/infra_defines.sh"

# Reset the default user name
COMMON_OPT_USER_VALUE=
USAGE=$(common_make_usage_string \
        --one-liner "List user's public keys in the artifactory." \
        ${COMMON_OPT_HELP} \
        ${COMMON_OPT_RTURL} \
        ${COMMON_OPT_USER} \
        ${COMMON_OPT_VERBOSE})
common_parse_options "${USAGE}" "$@"

# Sanity checks
# =============
common_validate_rturl

# Export artifactory environment
export RT_URL="${COMMON_OPT_RTURL_VALUE}"

# Fetch List of users from artifactory
common_verbose "Calling rt_list_directory with"\
               "user=${COMMON_OPT_USER_VALUE:-"all"}"
USERS="$(rt_list_directory "${RT_USERS_DIR}" \
  | jq -r '.children[] | select(.folder==true) |.uri')"

# Iterate over all users
for JH_USER in ${USERS}; do
   JH_USER="${JH_USER//\//}"
   # If a user name is given, list only the specified user
   [[ -n "${COMMON_OPT_USER_VALUE}" ]] && \
     [[ "${COMMON_OPT_USER_VALUE}" != "all" ]] && \
     [[ "${JH_USER}" != "${COMMON_OPT_USER_VALUE}" ]] && continue
   USER_KEYS="$(rt_get_user_public_keys "${JH_USER}" 1)"
   echo -e "user: ${JH_USER}\n===${USER_KEYS}"
done
