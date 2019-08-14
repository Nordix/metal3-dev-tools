#! /usr/bin/env bash

set -eu

# Description:
#   Runs the integration tests for metal3-dev-env in an executer vm
#   Requires:
#     - source stackrc file
#     - openstack ci infra should already be deployed.
#     - environment variables set:
#       - AIRSHIP_CI_USER: Ci user for jumphost.
#       - AIRSHIP_CI_USER_KEY: Path of the CI user private key for jumphost.
# Usage:
#  integration_test.sh
#

CI_DIR="$(dirname "$(readlink -f "${0}")")/../.."
OS_SCRIPTS_DIR="${CI_DIR}/scripts/openstack"
RT_SCRIPTS_DIR="${CI_DIR}/scripts/artifactory"
TESTS_SCRIPTS_DIR="${CI_DIR}/scripts/tests"

# shellcheck disable=SC1090
source "${RT_SCRIPTS_DIR}/utils.sh"
# shellcheck disable=SC1090
source "${OS_SCRIPTS_DIR}/utils.sh"
# shellcheck disable=SC1090
source "${OS_SCRIPTS_DIR}/infra_defines.sh"

TEST_EXECUTER_VM_NAME="${TEST_EXECUTER_VM_NAME:-ci-int-tests-vm}"
TEST_EXECUTER_PORT_NAME="${TEST_EXECUTER_PORT_NAME:-${TEST_EXECUTER_VM_NAME}-int-port}"
TEST_EXECUTER_FLAVOR="${TEST_EXECUTER_FLAVOR:-4C-16GB-50GB}"

METAL3REPO="${METAL3REPO:-https://github.com/metal3-io/metal3-dev-env.git}"
METAL3BRANCH="${METAL3BRANCH:-master}"
BMOREPO="${BMOREPO:-https://github.com/metal3-io/baremetal-operator.git}"
BMOBRANCH="${BMOBRANCH:-master}"
CAPBMREPO="${CAPBMREPO:-https://github.com/metal3-io/cluster-api-provider-baremetal.git}"
CAPBMBRANCH="${CAPBMBRANCH:-master}"

echo "Creating new executer VM."

# Creating new port, needed to immediately get the ip
EXT_PORT_ID="$(openstack port create -f json \
  --network "${CI_EXT_NET}" \
  --fixed-ip subnet="$(get_subnet_name "${CI_EXT_NET}")" \
  "${TEST_EXECUTER_PORT_NAME}" | jq -r '.id')"

# Create new executer vm
openstack server create -f json \
  --image "${CI_METAL3_IMAGE}" \
  --flavor "${TEST_EXECUTER_FLAVOR}" \
  --port "${EXT_PORT_ID}" \
  "${TEST_EXECUTER_VM_NAME}" | jq -r '.id'

# Get the IP
TEST_EXECUTER_IP="$(openstack port show -f json "${TEST_EXECUTER_PORT_NAME}" \
  | jq -r '.fixed_ips' | tr ',' '\n' | grep ip_address | cut -d '=' -f2- \
  | tr -d "'")"

echo "Waiting for the host to come up"
#Wait for the host to come up
wait_for_ssh "${AIRSHIP_CI_USER}" "${AIRSHIP_CI_USER_KEY}" "${TEST_EXECUTER_IP}"

# Send Remote script to Executer
scp \
  -o StrictHostKeyChecking=no \
  -o UserKnownHostsFile=/dev/null \
  -i "${AIRSHIP_CI_USER_KEY}" \
  "${TESTS_SCRIPTS_DIR}/files/run_integration_tests.sh" \
  "${AIRSHIP_CI_USER}@${TEST_EXECUTER_IP}:/tmp/" > /dev/null

echo "Running the tests"
# Execute remote script
# shellcheck disable=SC2029
ssh \
  -o StrictHostKeyChecking=no \
  -o UserKnownHostsFile=/dev/null \
  -i "${AIRSHIP_CI_USER_KEY}" \
  "${AIRSHIP_CI_USER}"@"${TEST_EXECUTER_IP}" \
  /tmp/run_integration_tests.sh "${METAL3REPO}" "${METAL3BRANCH}" \
  "${BMOREPO}" "${BMOBRANCH}" "${CAPBMREPO}" "${CAPBMBRANCH}"
