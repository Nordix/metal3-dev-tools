#!/bin/bash

set -uex

export CONTAINER_RUNTIME="${CONTAINER_RUNTIME}"
# Container images that we pre-pull into the CI image.
export IMG_REGISTRY="${IMG_REGISTRY:-"docker.io/registry:latest"}"
export IMG_GOLANG_IMG="${IMG_GOLANG_IMG:-"docker.io/golang:1.19"}"
export IMG_CENTOS_IMG="${IMG_CENTOS_IMG:-"quay.io/centos/centos:stream9"}"
export IMG_UBUNTU_IMG="${IMG_UBUNTU_IMG:-"docker.io/ubuntu:22.04"}"

if [[ "${IMAGE_OS}" == "Ubuntu" ]]; then
    export KUBERNETES_VERSION=${KUBERNETES_VERSION:-"v1.28.2"}
    export KIND_NODE_IMAGE_VERSION=${KIND_NODE_IMAGE_VERSION:-"v1.28.0"}
    export IMG_KIND_NODE_IMAGE="${IMG_KIND_NODE_IMAGE:-"kindest/node:${KIND_NODE_IMAGE_VERSION}"}"
fi

for container in $(env | grep "IMG_*" | cut -f2 -d'='); do
  sudo "${CONTAINER_RUNTIME}" pull "${container}"
done
