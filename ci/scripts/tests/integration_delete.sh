#! /usr/bin/env bash

set -eu

# Description:
#   Cleans the executer vm after integration tests
#   Requires:
#     - source stackrc file
# Usage:
#  integration_delete.sh
#

CI_DIR="$(dirname "$(readlink -f "${0}")")/../.."
OS_SCRIPTS_DIR="${CI_DIR}/scripts/openstack"
RT_SCRIPTS_DIR="${CI_DIR}/scripts/artifactory"

# shellcheck disable=SC1090
source "${RT_SCRIPTS_DIR}/utils.sh"
# shellcheck disable=SC1090
source "${OS_SCRIPTS_DIR}/utils.sh"
# shellcheck disable=SC1090
source "${OS_SCRIPTS_DIR}/infra_defines.sh"

TEST_EXECUTER_PORT_NAME="${TEST_EXECUTER_PORT_NAME:-${TEST_EXECUTER_VM_NAME}-int-port}"

# Delete executer vm
echo "Deleting executer VM."
openstack server delete "${TEST_EXECUTER_VM_NAME}"

openstack port delete "${TEST_EXECUTER_PORT_NAME}"
