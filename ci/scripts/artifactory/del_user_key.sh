#! /usr/bin/env bash

set -eu

# Description:
# Delete User Key in artifactory.
#
# Usage:
#   del_user_key.sh
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
        --one-liner "Delete user's public key in the artifactory." \
        ${COMMON_OPT_DRYRUN} \
        ${COMMON_OPT_HELP} \
        ${COMMON_OPT_KEYNAME} \
        ${COMMON_OPT_RTURL} \
        ${COMMON_OPT_RTUSER} \
        ${COMMON_OPT_USER} \
        ${COMMON_OPT_VERBOSE})
common_parse_options "${USAGE}" "$@"

# Sanity checks
# =============
common_validate_keyname
common_validate_rturl
common_validate_rtuser
common_validate_user
common_validate_rttoken

# Export artifactory environment
export RT_URL="${COMMON_OPT_RTURL_VALUE}"
export RT_USER="${COMMON_OPT_RTUSER_VALUE}"

common_verbose "Calling rt_del_user_public_key with"\
               "user=${COMMON_OPT_USER_VALUE},"\
               "key-name=${COMMON_OPT_KEYNAME_VALUE}"
rt_del_user_public_key "${COMMON_OPT_USER_VALUE}" "${COMMON_OPT_KEYNAME_VALUE}"
