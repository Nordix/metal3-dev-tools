#! /usr/bin/env bash

set -eu

SCRIPTPATH="$(dirname "$(readlink -f "${0}")")"

# shellcheck source=ci/scripts/openstack/infra_defines.sh
source "${SCRIPTPATH}/infra_defines.sh"

# shellcheck source=ci/scripts/openstack/utils.sh
source "${SCRIPTPATH}/utils.sh"

# Delete CI Openstack Infrastructure
# ===================================

# Delete CI keypair
delete_keypair "${CI_KEYPAIR_NAME}"

# Delete External Networks and associated resources(Subnets and Ports)
delete_network "${CI_EXT_NET}"

# Delete Router
delete_router "${CI_ROUTER_NAME}"
