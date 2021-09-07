#!/bin/bash
# The goal of this script is to clean artifacts from specified Artifactory directories.

set -eu

# General artifactory variables
RT_UTILS="${RT_UTILS:-/tmp/utils.sh}"
RT_URL="https://artifactory.nordix.org/artifactory"
IPA_ROOT_ARTIFACTORY="airship/images/ipa"
DRY_RUN="${DRY_RUN:-false}"
ANONYM="${ANONYM:-0}"
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"

# shellcheck disable=SC1090
source "${RT_UTILS}"
export "RT_URL=${RT_URL}"

# Centos Stream configuration
CENTOS_STREAM_ROOT="${IPA_ROOT_ARTIFACTORY}"

# Centos Stream Review
CENTOS_STREAM_REVIEW="${CENTOS_STREAM_ROOT}/review/centos/8-stream"
CENTOS_STREAM_REVIEW_PINNED="${CENTOS_STREAM_REVIEW_PINNED:-${SCRIPT_DIR}/centos_stream_review_pinned.txt}"
CENTOS_STREAM_REVIEW_RETENTION_NUM="${CENTOS_STREAM_REVIEW_RETENTION_NUM:-5}"

rt_delete_multiple_artifacts "${CENTOS_STREAM_REVIEW}" "${ANONYM}" "${DRY_RUN}" \
    "${CENTOS_STREAM_REVIEW_PINNED}" "${CENTOS_STREAM_REVIEW_RETENTION_NUM}"

# Centos Stream Staging
CENTOS_STREAM_STAGING="${CENTOS_STREAM_ROOT}/staging/centos/8-stream"
CENTOS_STREAM_STAGING_PINNED="${CENTOS_STREAM_STAGING_PINNED:-${SCRIPT_DIR}/centos_stream_staging_pinned.txt}"
CENTOS_STREAM_STAGING_RETENTION_NUM="${CENTOS_STREAM_STAGING_RETENTION_NUM:-10}"

rt_delete_multiple_artifacts "${CENTOS_STREAM_STAGING}" "${ANONYM}" "${DRY_RUN}" \
    "${CENTOS_STREAM_STAGING_PINNED}" "${CENTOS_STREAM_STAGING_RETENTION_NUM}"

