#! /bin/bash

# ================ Image Resize, Shrink and Upload to artifactory ===============

# Description:
# This script does the following:
#   1. downloads an image from openstack
#   2. sparsifies and shrinks it
#   3. resizes it
#   4. uploads it to artifactory
# 
# Usage:
#   ./upload.sh <IMAGE_NAME>
#
set -x
IMAGE_NAME="${1:?}"

CI_DIR="$(dirname "$(readlink -f "${0}")")/../.."
RT_SCRIPTS_DIR="${CI_DIR}/scripts/artifactory"
export KUBERNETES_VERSION=${KUBERNETES_VERSION:-"v1.18.8"}

# Install necessary package
sudo apt update -y 
sudo apt install libguestfs-tools -y

# Download and push the image to artifactory
WORK_DIR=/tmp/node_image
mkdir -p "$WORK_DIR"
echo "Downloading node Image from openstack"
openstack image save --file "${WORK_DIR}"/"$IMAGE_NAME".qcow2 "$IMAGE_NAME"
IMAGE_NAME="$IMAGE_NAME".qcow2

# Resize image  
pushd "${WORK_DIR}"
export LIBGUESTFS_DEBUG=1 LIBGUESTFS_TRACE=1
ls -la
sudo virt-sparsify "$IMAGE_NAME" converted_"$IMAGE_NAME" --compress
sudo rm "$IMAGE_NAME"
sudo mv converted_"$IMAGE_NAME" "$IMAGE_NAME" 
sudo qemu-img resize --shrink "$IMAGE_NAME" 3G
popd

# shellcheck disable=SC1090
source "${RT_SCRIPTS_DIR}/utils.sh"
SOURCE_PATH="${WORK_DIR}/${IMAGE_NAME}"
DST_PATH="airship/images/k8s_${KUBERNETES_VERSION}/${IMAGE_NAME}"

# Following environment variables should be set 
# to push the image to artifactory
#   RT_USER: artifactory user name.
#   RT_TOKEN: artifactory password or api token
#   RT_URL: Artifactory URL
rt_upload_artifact  "${SOURCE_PATH}" "${DST_PATH}" "0"

# Delete the image from local work directory
sudo rm -r ${WORK_DIR}