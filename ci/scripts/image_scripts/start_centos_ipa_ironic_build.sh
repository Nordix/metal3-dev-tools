#!/bin/bash
# Fail the script if any command fails
set -eu

# VM configuration variables
BUILDER_VM_NAME="${VM_NAME}"
BUILDER_PORT_NAME="${BUILDER_PORT_NAME:-${BUILDER_VM_NAME}-int-port}"
BUILDER_FLAVOR="${BUILDER_FLAVOR:-8C-16GB-200GB}"
CI_DIR="$(dirname "$(readlink -f "${0}")")"
IPA_BUILDER_SCRIPT_NAME="${IPA_BUILDER_SCRIPT_NAME:-build_ipa.sh}"
CI_EXT_NET="airship-ci-ext-net"
IMAGE_NAME="airship-ci-ubuntu-metal3-img"

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

# Send IPA & Ironic script to remote executer
scp \
  -o StrictHostKeyChecking=no \
  -o UserKnownHostsFile=/dev/null \
  -i "${AIRSHIP_CI_USER_KEY}" \
  "${CI_DIR}/${IPA_BUILDER_SCRIPT_NAME}" "${CI_DIR}/../artifactory/utils.sh" \
  "${CI_DIR}/run_build_ironic.sh" \
  "${AIRSHIP_CI_USER}@${BUILDER_IP}:/tmp/" > /dev/null

echo "Running Ironic image building script"
# Execute remote script
# shellcheck disable=SC2029
ssh \
  -o StrictHostKeyChecking=no \
  -o UserKnownHostsFile=/dev/null \
  -o ServerAliveInterval=15 \
  -o ServerAliveCountMax=10 \
  -i "${AIRSHIP_CI_USER_KEY}" \
  "${AIRSHIP_CI_USER}"@"${BUILDER_IP}" \
  PATH=/usr/local/bin:/usr/bin:/usr/local/sbin:/usr/sbin:/sbin:/bin \
  IRONIC_REFSPEC="${IRONIC_REFSPEC:-}" \
  IRONIC_IMAGE_REPO_COMMIT="${IRONIC_IMAGE_REPO_COMMIT:-}" \
  IRONIC_IMAGE_BRANCH="${IRONIC_IMAGE_BRANCH:-}" \
  IRONIC_INSPECTOR_REFSPEC="${IRONIC_INSPECTOR_REFSPEC:-}" \
  DOCKER_USER="${DOCKER_USER}" \
  DOCKER_PASSWORD="${DOCKER_PASSWORD}" /tmp/run_build_ironic.sh

echo "Running IPA building scripts"
# Execute remote script
# shellcheck disable=SC2029
ssh \
  -o StrictHostKeyChecking=no \
  -o UserKnownHostsFile=/dev/null \
  -o ServerAliveInterval=15 \
  -o ServerAliveCountMax=10 \
  -i "${AIRSHIP_CI_USER_KEY}" \
  "${AIRSHIP_CI_USER}"@"${BUILDER_IP}" \
  PATH=/usr/local/bin:/usr/bin:/usr/local/sbin:/usr/sbin:/sbin:/bin \
  RT_USER="${RT_USER}" RT_TOKEN="${RT_TOKEN}" GITHUB_TOKEN="${GITHUB_TOKEN}" STAGING="${STAGING}" \
  IPA_BRANCH="${IPA_BRANCH:-master}" IPA_COMMIT="${IPA_REPO_REF:-HEAD}" \
  IPA_BUILDER_BRANCH="${IPA_BUILDER_BRANCH:-master}" IPA_BUILDER_COMMIT="${IPA_BUILDER_COMMIT:-HEAD}" \
  METAL3_DEV_ENV_BRANCH="${METAL3_DEV_ENV_BRANCH:-master}" METAL3_DEV_ENV_COMMIT="${METAL3_DEV_ENV_COMMIT:-HEAD}" \
  BMO_BRANCH="${BMO_BRANCH:-main}" BMO_COMMIT="${BMO_COMMIT:-HEAD}" \
  "/tmp/${IPA_BUILDER_SCRIPT_NAME}"
