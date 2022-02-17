#! /usr/bin/env bash

set -eu

CI_DIR="$(dirname "$(readlink -f "${0}")")"
DISTRIBUTION="${DISTRIBUTION:-ubuntu}"
BUILD_TAG="${BUILD_TAG:-logs_integration_tests}"

TEST_EXECUTER_PORT_NAME="${TEST_EXECUTER_PORT_NAME:-${VM_NAME}-int-port}"

# Get the IP
TEST_EXECUTER_IP="$(openstack port show -f json "${TEST_EXECUTER_PORT_NAME}" \
  | jq -r '.fixed_ips[0].ip_address')"

# Send Remote script to Executer
scp \
  -o StrictHostKeyChecking=no \
  -o UserKnownHostsFile=/dev/null \
  -i "${METAL3_CI_USER_KEY}" \
  "${CI_DIR}/run_fetch_logs.sh" \
  "${METAL3_CI_USER}@${TEST_EXECUTER_IP}:/tmp/" > /dev/null

echo "Fetching logs"
# Execute remote script
# shellcheck disable=SC2029
ssh \
  -o StrictHostKeyChecking=no \
  -o UserKnownHostsFile=/dev/null \
  -o ServerAliveInterval=15 \
  -i "${METAL3_CI_USER_KEY}" \
  "${METAL3_CI_USER}"@"${TEST_EXECUTER_IP}" \
  PATH=/usr/local/bin:/usr/bin:/usr/local/sbin:/usr/sbin:/sbin:/bin \
  /tmp/run_fetch_logs.sh "logs-${BUILD_TAG}.tgz" \
  "logs-${BUILD_TAG}" "${DISTRIBUTION}"

# fetch logs tarball
scp \
  -o StrictHostKeyChecking=no \
  -o UserKnownHostsFile=/dev/null \
  -i "${METAL3_CI_USER_KEY}" \
  "${METAL3_CI_USER}@${TEST_EXECUTER_IP}:logs-${BUILD_TAG}.tgz" \
  "./" > /dev/null

