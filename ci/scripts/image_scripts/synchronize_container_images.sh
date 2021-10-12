#!/bin/bash

set -eu

# This script makes sure to synchronize container images hosted in Nordix/Harbor
# with the ones hosted in quay.io/metal3 based on the container image digest as tag.

# Container image related variables
UPSTREAM_IMAGE_REGISTRY="quay.io"
UPSTREAM_CONTAINER_IMAGE_REPO="metal3-io"
HARBOR_IMAGE_REGISTRY="registry.nordix.org"
HARBOR_CONTAINER_IMAGE_REPO="airship"
CAPM3_v1a4_RELEASE_TAG="release-0.4"
IPAM_v1a4_RELEASE_TAG="release-0.0"
v1a5_RELEASE_TAG="master"

# Container runtime
export CONTAINER_RUNTIME="${CONTAINER_RUNTIME:-docker}"

# Declare a string array with container image names
declare -a ContainerImagesArray=(
    "vbmc" "sushy-tools" "ironic-ipa-downloader" "ironic" \
    "ironic-client" "keepalived" "baremetal-operator" \
    "cluster-api-provider-metal3:${CAPM3_v1a4_RELEASE_TAG}" \
    "cluster-api-provider-metal3:${v1a5_RELEASE_TAG}" \
    "ip-address-manager:${IPAM_v1a4_RELEASE_TAG}" \
    "ip-address-manager:${v1a5_RELEASE_TAG}"
)

# Loop over the container images and do:
for container in "${ContainerImagesArray[@]}"; do
    # Pull container image from quay.io
    "${CONTAINER_RUNTIME}" pull "${UPSTREAM_IMAGE_REGISTRY}/${UPSTREAM_CONTAINER_IMAGE_REPO}/${container}"
    # Get the sha256 digest of the container image
    digest=$("${CONTAINER_RUNTIME}" inspect --format='{{index .RepoDigests 0}}' \
        "${UPSTREAM_IMAGE_REGISTRY}/${UPSTREAM_CONTAINER_IMAGE_REPO}/${container}" \
        | grep -o 'sha256:.*' | cut -f2- -d: | cut -c1-6)
    echo "$container container image digest is $digest"
    # Tag and push quay container image only if it doesn't already exist in the Nordix Harbor registry.
    if "${CONTAINER_RUNTIME}" manifest inspect "${HARBOR_CONTAINER_IMAGE_REPO}/$container:${digest}"  > /dev/null; then
        echo "${HARBOR_CONTAINER_IMAGE_REPO}/$container:${digest} container image already exists -> skip pushing container image to Nordix Harbor registry"
    else
        # Use digest of container image to tag and push it to Nordix Harbor registry
        echo "${HARBOR_CONTAINER_IMAGE_REPO}/$container:${digest} container image doesn't exist -> tag and push container image to Nordix Harbor registry"
        "${CONTAINER_RUNTIME}" tag "${UPSTREAM_IMAGE_REGISTRY}/${UPSTREAM_CONTAINER_IMAGE_REPO}/${container} \
        ${HARBOR_IMAGE_REGISTRY}/${HARBOR_CONTAINER_IMAGE_REPO}/${container}:${digest}"
        "${CONTAINER_RUNTIME}" push "${HARBOR_IMAGE_REGISTRY}/${HARBOR_CONTAINER_IMAGE_REPO}/${container}:${digest}"
    fi
done
