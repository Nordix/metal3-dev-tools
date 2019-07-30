#! /usr/bin/env bash

set -eu

SCRIPTPATH="$(dirname "$(readlink -f "${0}")")"

# shellcheck disable=SC1090
source "${SCRIPTPATH}/infra_defines.sh"

# shellcheck disable=SC1090
source "${SCRIPTPATH}/utils.sh"

# Create CI Infrastructure
# ========================

# Create Router
create_router "${EXT_NET}" "${CI_ROUTER_NAME}"

# Create CI External Network
create_external_net "${CI_EXT_SUBNET_CIDR}" "${CI_ROUTER_NAME}" "${CI_EXT_NET}"

# Create CI Internal Network
create_network_and_subnet "${CI_INT_SUBNET_CIDR}" 0 "${CI_INT_NET}"
