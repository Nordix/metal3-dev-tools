#!/usr/bin/env bash

#
# The goal of this script is to clean artifacts from specified Artifactory
# directories.
#
set -eu

# General artifactory variables
RT_UTILS="${RT_UTILS:-/tmp/utils.sh}"
HARBOR_UTILS="${HARBOR_UTILS:-/tmp/harbor_utils.sh}"
RT_URL="https://artifactory.nordix.org/artifactory"
IPA_ROOT_ARTIFACTORY="metal3/images/ipa"
DRY_RUN="${DRY_RUN:-false}"
ANONYM="${ANONYM:-0}"
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
declare -a IPA_BASE_DISTROS=('centos-8-stream' 'centos-9-stream')

# shellcheck disable=SC1090
source "${RT_UTILS}"
export "RT_URL=${RT_URL}"

# Centos Stream configuration
CENTOS_STREAM_ROOT="${IPA_ROOT_ARTIFACTORY}"

for DISTRO in "${IPA_BASE_DISTROS[@]}"; do
  # clean review artifacts
  echo "IPA BASE IMAGE: $DISTRO"
  CENTOS_STREAM_REVIEW="${CENTOS_STREAM_ROOT}/review/centos/${DISTRO#*-}"
  CENTOS_STREAM_REVIEW_PINNED="${SCRIPT_DIR}/${DISTRO}-review-pinned.txt"
  CENTOS_STREAM_REVIEW_RETENTION_NUM="${CENTOS_STREAM_REVIEW_RETENTION_NUM:-5}"

  rt_delete_multiple_artifacts "${CENTOS_STREAM_REVIEW}" "${ANONYM}" \
    "${DRY_RUN}" "${CENTOS_STREAM_REVIEW_PINNED}" \
    "${CENTOS_STREAM_REVIEW_RETENTION_NUM}"

  # clean staging artifacts
  CENTOS_STREAM_STAGING="${CENTOS_STREAM_ROOT}/staging/centos/${DISTRO#*-}"
  CENTOS_STREAM_STAGING_PINNED="${SCRIPT_DIR}/${DISTRO}-staging-pinned.txt"
  CENTOS_STREAM_STAGING_RETENTION_NUM="${CENTOS_STREAM_STAGING_RETENTION_NUM:-10}"

  rt_delete_multiple_artifacts "${CENTOS_STREAM_STAGING}" "${ANONYM}" \
    "${DRY_RUN}" "${CENTOS_STREAM_STAGING_PINNED}" \
    "${CENTOS_STREAM_STAGING_RETENTION_NUM}"
done

# Harbor metal3 project cleanup
# shellcheck disable=SC1090
source "${HARBOR_UTILS}"
echo "Harbor images:"
PINNED_IRONIC_IMAGE_ARTIFACTS="${PINNED_IRONIC_IMAGE_ARTIFACTS:-${SCRIPT_DIR}/ironic-image-pinned.txt}"

# Clean (delete) ironic-image container images
harbor_clean_OCI_repository \
  "ironic-image" "${PINNED_IRONIC_IMAGE_ARTIFACTS}" "5" "${DRY_RUN}"

# Clean (delete) image-builder container images
harbor_clean_OCI_repository "image-builder" "/dev/null" "5" "${DRY_RUN}"
