#! /usr/bin/env bash

set -eu

CI_DIR="$(dirname "$(readlink -f "${0}")")/.."
OS_SCRIPTS_DIR="${CI_DIR}/scripts/openstack" 

# shellcheck disable=SC1090
source "${OS_SCRIPTS_DIR}/infra_defines.sh"

# shellcheck disable=SC1090
source "${OS_SCRIPTS_DIR}/utils.sh"

BUILDER_VOLUME_NAME="metal3-centos-builder"
BASE_VOLUME_NAME="metal3-centos"
VOLUME_SIZE="50"

# Convert image to bootable volume
echo "Creating a bootable volume..."
create_volume "${CI_METAL3_CENTOS_IMAGE}" "${VOLUME_SIZE}" "${BUILDER_VOLUME_NAME}"

# Wait for a volume to be available...
echo "Waiting for a volume to be available..."
retry=0
until openstack volume show "${BUILDER_VOLUME_NAME}" -f json \
  | jq .status | grep "available"
do
  sleep 10
  # Check if volume creation is failed
  if [[ "$(openstack volume show "${BUILDER_VOLUME_NAME}" -f json \
    | jq .status)" == *"error"* ]];
  then
    echo "Volume creation is failed"
    # If volume creation is failed, then retry volume creation only once
    if [ $retry -eq 0 ]; then
      echo "Deleting a volume that failed to be created..."
      openstack volume delete "${BUILDER_VOLUME_NAME}"
      echo "Creating another new volume..."
      create_volume "${CI_METAL3_CENTOS_IMAGE}" "${VOLUME_SIZE}" "${BUILDER_VOLUME_NAME}"
      retry=1
    else
      exit 1
    fi
    continue
  fi
done

# Replace the base volume with final volume
echo "Replacing the base volume with final volume..."
replace_volume "${BUILDER_VOLUME_NAME}" "${BASE_VOLUME_NAME}"
set_volume_readonly
