#!/usr/bin/env bash
# The goal of this script is to backup newly build image and 
#   remove outdated backup node images from artifactory, while retaining the n (RETENTION_NUM) most recent ones

set -eux

IMAGE_OS="${IMAGE_OS:-}"
KUBERNETES_VERSION="${KUBERNETES_VERSION:-"v1.27.1"}"

# The newest n number of artifacts should be kept in the directory 
RETENTION_NUM=5

CI_DIR="$(dirname "$(readlink -f "${0}")")/../.."
RT_SCRIPTS_DIR="${CI_DIR}/scripts/artifactory"
WORK_DIR=/tmp/node_image

if [[ "${IMAGE_OS}" == "Ubuntu" ]]; then
  UBUNTU_VERSION=${UBUNTU_VERSION:-"22.04"}
  IMAGE_NAME=${IMAGE_NAME:-"UBUNTU_${UBUNTU_VERSION}_NODE_IMAGE_K8S_""${KUBERNETES_VERSION}"}
elif [[ "${IMAGE_OS}" == "CentOS" ]]; then
  CENTOS_VERSION="9"
  IMAGE_NAME=${IMAGE_NAME:-"CENTOS_${CENTOS_VERSION}_NODE_IMAGE_K8S_${KUBERNETES_VERSION}"}
else
  echo "Available IMAGE_NAME variables are: CentOS and Ubuntu"
  exit 1
fi

# COMMIT_SHORT defines last commit on the repo
# NODE_IMAGE_IDENTIFIER consists of date of image build and COMMIT_SHORT
# Node image name example: CENTOS_9_NODE_IMAGE_K8S_v1.27.1_20230607T1319Z_22101ef.qcow2
COMMIT_SHORT="$(git rev-parse --short HEAD)"
NODE_IMAGE_IDENTIFIER="$(date --utc +"%Y%m%dT%H%MZ")_${COMMIT_SHORT}"
echo "NODE_IMAGE_IDENTIFIER: ${NODE_IMAGE_IDENTIFIER}"

# shellcheck source=ci/scripts/artifactory/utils.sh
. "${RT_SCRIPTS_DIR}/utils.sh"
SOURCE_PATH="${WORK_DIR}/${IMAGE_NAME}.qcow2"
DST_FOLDER=${DST_FOLDER:-metal3/images/k8s_${KUBERNETES_VERSION}}
DST_PATH="${DST_FOLDER}/${IMAGE_NAME}_${NODE_IMAGE_IDENTIFIER}.qcow2"

# Following environment variables should be set 
# to push the image to artifactory
#   RT_USER: artifactory user name.
#   RT_TOKEN: artifactory password or api token
#   RT_URL: Artifactory URL

rt_upload_artifact  "${SOURCE_PATH}" "${DST_PATH}" "0"

# Remove outdated node images, while retaining the n number of most recent ones

# Gets list of artifacts into an array
mapfile -t < <(rt_list_directory "${DST_FOLDER}" 0 | \
  jq '.children | .[] | .uri' | \
  sort -r |\
  grep "${IMAGE_NAME}_20" | \
  sed -e 's/\"\/\([^"]*\)"/\1/g') 

# deletes artifacts
for ((i="${RETENTION_NUM}"; i<${#MAPFILE[@]}; i++)); do
  rt_delete_artifact "${DST_FOLDER}/${MAPFILE[i]}" "0"
  echo "${MAPFILE[i]} has been deleted!"
done
