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
        --one-liner "Delete the target infrastructure." \
        ${COMMON_OPT_DRYRUN} \
        ${COMMON_OPT_HELP} \
        ${COMMON_OPT_TARGET} \
        ${COMMON_OPT_VERBOSE})
common_parse_options "${USAGE}" "$@"

# Sanity checks
# =============
common_validate_target

NETWORK="${COMMON_OPT_TARGET_VALUE}_NETWORK"
ROUTER_NAME="${COMMON_OPT_TARGET_VALUE}_ROUTER_NAME"

# Delete Infrastructure
# =====================

# Delete Networks and associated resources (subnets and ports)
common_verbose "Calling delete_network ${!NETWORK}..."
delete_network "${!NETWORK}"

# Delete Router
common_verbose "Calling delete_router ${!ROUTER_NAME}..."
delete_router "${!ROUTER_NAME}"
