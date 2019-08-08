#! /usr/bin/env bash

set -eu

SCRIPTPATH="$(dirname "$(readlink -f "${0}")")"

# shellcheck disable=SC1090
source "${SCRIPTPATH}/infra_defines.sh"

# shellcheck disable=SC1090
source "${SCRIPTPATH}/utils.sh"

# Delete DEV Openstack Infrastructure
# ===================================

# Delete External Networks and associated resources(Subnets and Ports)
delete_network "${DEV_EXT_NET}"

# Delete Router
delete_router "${DEV_ROUTER_NAME}"
