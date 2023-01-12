#! /usr/bin/env bash

set -eu

SCRIPTPATH="$(dirname "$(readlink -f "${0}")")"

# shellcheck source=ci/scripts/openstack/infra_defines.sh
source "${SCRIPTPATH}/infra_defines.sh"

# shellcheck source=ci/scripts/openstack/utils.sh
source "${SCRIPTPATH}/utils.sh"

# Delete DEV Openstack Infrastructure
# ===================================

# Delete External Networks and associated resources(Subnets and Ports)
delete_network "${DEV_EXT_NET}"

# Delete Router
delete_router "${DEV_ROUTER_NAME}"
