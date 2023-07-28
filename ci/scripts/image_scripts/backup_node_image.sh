#!/usr/bin/env bash
# The goal of this script is to backup newly build image and 
# remove outdated backup node images from artifactory, while
# retaining the n (RETENTION_NUM, default is 5) most recent ones

set -eux

CI_DIR="$(dirname "$(readlink -f "${0}")")/../.."
RT_SCRIPTS_DIR="${CI_DIR}/scripts/artifactory"

# shellcheck source=ci/scripts/artifactory/utils.sh
. "${RT_SCRIPTS_DIR}/utils.sh"

IMAGE_OS="${IMAGE_OS:-}"
KUBERNETES_VERSION="${KUBERNETES_VERSION:-"v1.27.4"}"

# The newest n number of artifacts should be kept in the directory 
RETENTION_NUM=5

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

# RT_FOLDER is the folder where images are stored in Artifactory
RT_FOLDER=${RT_FOLDER:-metal3/images/k8s_${KUBERNETES_VERSION}}

# Download newly built image from artifactory
wget -q "${RT_URL}/${RT_FOLDER}/${IMAGE_NAME}.qcow2"  -O "${IMAGE_NAME}.qcow2"

# Define name for backup image
#   COMMIT_SHORT defines last commit on the repo
#   NODE_IMAGE_IDENTIFIER consists of date of image build and COMMIT_SHORT
#   Node image name example: CENTOS_9_NODE_IMAGE_K8S_v1.27.1_20230607T1319Z_22101ef.qcow2
COMMIT_SHORT="$(git rev-parse --short HEAD)"
NODE_IMAGE_IDENTIFIER="$(date --utc +"%Y%m%dT%H%MZ")_${COMMIT_SHORT}"
echo "NODE_IMAGE_IDENTIFIER: ${NODE_IMAGE_IDENTIFIER}"

BACKUP_IMAGE_NAME="${IMAGE_NAME}_${NODE_IMAGE_IDENTIFIER}.qcow2"
echo "BACKUP_IMAGE_NAME: ${BACKUP_IMAGE_NAME}"

# Upload image with new name
rt_upload_artifact  "${IMAGE_NAME}.qcow2" "${RT_FOLDER}/${BACKUP_IMAGE_NAME}" "0"

# Remove outdated node images, keep n number of latest ones
#   Get list of artifacts into an array
mapfile -t < <(rt_list_directory "${RT_FOLDER}" 0 | \
  jq '.children | .[] | .uri' | \
  sort -r |\
  grep "${IMAGE_NAME}_20" | \
  sed -e 's/\"\/\([^"]*\)"/\1/g') 

#   Delete artifacts
for ((i="${RETENTION_NUM}"; i<${#MAPFILE[@]}; i++)); do
  rt_delete_artifact "${RT_FOLDER}/${MAPFILE[i]}" "0"
  echo "${MAPFILE[i]} has been deleted!"
done
