#! /usr/bin/env bash

set -eu

SCRIPTPATH="$(dirname "$(readlink -f "${0}")")"

# shellcheck source=ci/scripts/openstack/infra_defines.sh
source "${SCRIPTPATH}/infra_defines.sh"

# shellcheck source=ci/scripts/openstack/utils.sh
source "${SCRIPTPATH}/utils.sh"

# Create DEV Infrastructure
# ========================

# Create DEV Router
create_router "${EXT_NET}" "${DEV_ROUTER_NAME}"

# Create DEV External Network
create_external_net "${DEV_EXT_SUBNET_CIDR}" "${DEV_ROUTER_NAME}" "${DEV_EXT_NET}"
