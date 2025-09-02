#! /usr/bin/env bash

set -euo pipefail

# Description:
#   Deletes a jumphost in openstack environment
#   Requires:
#     - source stackrc file
# Usage:
#  delete_dev_jumphost.sh
#

CI_DIR="$(dirname "$(readlink -f "${0}")")/../.."
OS_SCRIPTS_DIR="${CI_DIR}/scripts/openstack"
COMMON_SCRIPTS_DIR="${CI_DIR}/scripts/common"

# shellcheck source=ci/scripts/common/opts.sh
. "${COMMON_SCRIPTS_DIR}/opts.sh"
# shellcheck source=ci/scripts/common/utils.sh
. "${COMMON_SCRIPTS_DIR}/utils.sh"
# shellcheck source=ci/scripts/openstack/utils.sh
. "${OS_SCRIPTS_DIR}/utils.sh"
# shellcheck source=ci/scripts/openstack/infra_defines.sh
. "${OS_SCRIPTS_DIR}/infra_defines.sh"

USAGE=$(common_make_usage_string \
        --one-liner "Delete a jumphost in openstack environment." \
        ${COMMON_OPT_DRYRUN} \
        ${COMMON_OPT_HELP} \
        ${COMMON_OPT_TARGET} \
        ${COMMON_OPT_VERBOSE})
common_parse_options "${USAGE}" "$@"

# Sanity checks
# =============
common_validate_target

JUMPHOST_NAME="${COMMON_OPT_TARGET_VALUE}_JUMPHOST_NAME"
JUMPOST_EXT_PORT_NAME="${!JUMPHOST_NAME}-ext-port"
JUMPHOST_FLOATING_IP_TAG="${COMMON_OPT_TARGET_VALUE}_JUMPHOST_FLOATING_IP_TAG"
JUMPHOST_EXT_SG="${COMMON_OPT_TARGET_VALUE}_JUMPHOST_EXT_SG"

# Get the jumphost ID
JUMPHOST_SERVER_ID="$(openstack server list --name "${!JUMPHOST_NAME}" -f json \
  | jq -r 'map(.ID) | @csv' \
  | tr ',' '\n' \
  | tr -d '"')"
common_verbose "JUMPHOST_SERVER_ID=${JUMPHOST_SERVER_ID}"

# Get the floating IP
FLOATING_IP_ID="$(openstack floating ip list --tags "${!JUMPHOST_FLOATING_IP_TAG}" -f json \
    | jq -r 'map(.ID) | @csv' \
    | tr ',' '\n' \
    | tr -d '"')"
common_verbose "FLOATING_IP_ID=${FLOATING_IP_ID}"

# Delete the jumphost
if [ -n "${JUMPHOST_SERVER_ID}" ]
then
  common_verbose "Deleting server name=${!JUMPHOST_NAME}..."
  common_run -- openstack server delete "${!JUMPHOST_NAME}"
fi

# Unset the floating ip, keep it to reuse later
if [ -n "${FLOATING_IP_ID}" ]
then
  common_verbose "Disassociate floating IP id=${FLOATING_IP_ID}..."
  common_run -- openstack floating ip unset --port "${FLOATING_IP_ID}"
fi

# Cleanup any stale ports
delete_port "${JUMPOST_EXT_PORT_NAME}"

# Cleanup security group
delete_sg "${!JUMPHOST_EXT_SG}"
