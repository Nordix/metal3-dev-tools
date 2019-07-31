#! /usr/bin/env bash

set -eu

SCRIPTPATH="$(dirname "$(readlink -f "${0}")")"

# shellcheck disable=SC1090
source "${SCRIPTPATH}/infra_defines.sh"

# shellcheck disable=SC1090
source "${SCRIPTPATH}/utils.sh"

# Delete CI Openstack Infrastructure
# ===================================

# Delete CI keypair
delete_keypair "${CI_KEYPAIR_NAME}"

# Delete Internal Networks and associated resources(Subnets and Ports)
delete_network "${CI_INT_NET}"

# Delete External Networks and associated resources(Subnets and Ports)
delete_network "${CI_EXT_NET}"

# Delete Router
delete_router "${CI_ROUTER_NAME}"
