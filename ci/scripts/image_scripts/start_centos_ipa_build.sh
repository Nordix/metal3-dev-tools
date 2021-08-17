#!/bin/bash
# Fail the script if any command fails
set -eu

# VM configuration variables
VM_TIMELABEL="${VM_TIMELABEL:-$(date '+%Y%m%d%H%M%S')}"
BUILDER_VM_NAME="${BUILDER_VM_NAME:-ci-builder-vm-${VM_TIMELABEL}}"
BUILDER_PORT_NAME="${BUILDER_PORT_NAME:-${BUILDER_VM_NAME}-int-port}"
BUILDER_FLAVOR="${BUILDER_FLAVOR:-2C-8GB}"
CI_DIR="$(dirname "$(readlink -f "${0}")")"
IPA_BUILDER_SCRIPT_NAME="${IPA_BUILDER_SCRIPT_NAME:-build_ipa.sh}"

# shellcheck disable=SC1090
source "${CI_DIR}/../openstack/utils.sh"

# Creating new port, needed to immediately get the ip
EXT_PORT_ID="$(openstack port create -f json \
  --network "${CI_EXT_NET}" \
  --fixed-ip subnet="$(get_subnet_name "${CI_EXT_NET}")" \
  "${BUILDER_PORT_NAME}" | jq -r '.id')"

# Create new builder vm
openstack server create -f json \
  --image "${IMAGE_NAME}" \
  --flavor "${BUILDER_FLAVOR}" \
  --port "${EXT_PORT_ID}" \
  "${BUILDER_VM_NAME}" | jq -r '.id'

# Get the IP
BUILDER_IP="$(openstack port show -f json "${BUILDER_PORT_NAME}" \
  | jq -r '.fixed_ips[0].ip_address')"

echo "Waiting for the host ${BUILDER_VM_NAME} to come up"
# Wait for the host to come up
wait_for_ssh "${AIRSHIP_CI_USER}" "${AIRSHIP_CI_USER_KEY}" "${BUILDER_IP}"

# Send Remote script to Executer
scp \
  -o StrictHostKeyChecking=no \
  -o UserKnownHostsFile=/dev/null \
  -i "${AIRSHIP_CI_USER_KEY}" \
  "${CI_DIR}/"${IPA_BUILDER_SCRIPT_NAME}" "${CI_DIR}/../artifactory/utils.sh" \
  "${AIRSHIP_CI_USER}@${BUILDER_IP}:/tmp/" > /dev/null

echo "Running the tests"
# Execute remote script
# shellcheck disable=SC2029
ssh \
  -o StrictHostKeyChecking=no \
  -o UserKnownHostsFile=/dev/null \
  -o ServerAliveInterval=15 \
  -o ServerAliveCountMax=10 \
  -i "${AIRSHIP_CI_USER_KEY}" \
  "${AIRSHIP_CI_USER}"@"${BUILD_EXECUTER_IP}" \
  PATH=/usr/local/bin:/usr/bin:/usr/local/sbin:/usr/sbin:/sbin:/bin \
  "/tmp/${IPA_BUILDER_SCRIPT_NAME}" "${RT_USER}" "${RT_TOKEN}"

