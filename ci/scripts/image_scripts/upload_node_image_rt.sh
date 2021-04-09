#! /bin/bash

# ================ Image Resize, Shrink and Upload to artifactory ===============

# Description:
# This script does the following:
#   1. downloads an image from openstack
#   2. uploads it to artifactory
# 
# Usage:
#   ./upload_node_image_rt.sh <IMAGE_NAME>
#   ./upload_node_image_rt.sh CENTOS_8.2_NODE_IMAGE_K8S_v1.18.8
# Don't include the image format, only the name.
# Example: CENTOS_8.2_NODE_IMAGE_K8S_v1.18.8 instead of CENTOS_8.2_NODE_IMAGE_K8S_v1.18.8.qcow2
set -x
IMAGE_NAME="${1:?}"

CI_DIR="$(dirname "$(readlink -f "${0}")")/../.."
RT_SCRIPTS_DIR="${CI_DIR}/scripts/artifactory"
export KUBERNETES_VERSION=${KUBERNETES_VERSION:-"v1.21.0"}

# Download and push the image to artifactory
WORK_DIR=/tmp/node_image
mkdir -p "$WORK_DIR"
echo "Downloading node Image from openstack"
openstack image save --file "${WORK_DIR}"/"$IMAGE_NAME".qcow2 "$IMAGE_NAME"
IMAGE_NAME="$IMAGE_NAME".qcow2

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
