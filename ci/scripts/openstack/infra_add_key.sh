#! /usr/bin/env bash

set -euo pipefail

CI_DIR="$(dirname "$(readlink -f "${0}")")/../.."
COMMON_SCRIPTS_DIR="${CI_DIR}/scripts/common"
OS_SCRIPTS_DIR="${CI_DIR}/scripts/openstack"

# shellcheck source=ci/scripts/common/opts.sh
. "${COMMON_SCRIPTS_DIR}/opts.sh"
# shellcheck source=ci/scripts/common/utils.sh
. "${COMMON_SCRIPTS_DIR}/utils.sh"
# shellcheck source=ci/scripts/openstack/infra_defines.sh
. "${OS_SCRIPTS_DIR}/infra_defines.sh"
# shellcheck source=ci/scripts/openstack/utils.sh
. "${OS_SCRIPTS_DIR}/utils.sh"

USAGE=$(common_make_usage_string \
        --one-liner "Add management key." \
        ${COMMON_OPT_DRYRUN} \
        ${COMMON_OPT_HELP} \
        ${COMMON_OPT_KEYFILE} \
        ${COMMON_OPT_TARGET} \
        ${COMMON_OPT_VERBOSE})
common_parse_options "${USAGE}" "$@"

# Sanity checks
# =============
common_validate_target
common_validate_keyfile

MANAGEMENT_KEYPAIR_NAME="${COMMON_OPT_TARGET_VALUE}_KEYPAIR_NAME"

# Create keypair
common_verbose "Calling create_keypair with"\
               "key-file=${COMMON_OPT_KEYFILE_VALUE},"\
               "key-name=${!MANAGEMENT_KEYPAIR_NAME}"
create_keypair "${COMMON_OPT_KEYFILE_VALUE}" "${!MANAGEMENT_KEYPAIR_NAME}"
