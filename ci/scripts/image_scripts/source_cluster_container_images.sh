#!/bin/bash

set -uex

export CONTAINER_RUNTIME="${CONTAINER_RUNTIME}"
# Container images that we pre-pull into the CI image.
export IMG_REGISTRY="${IMG_REGISTRY:-"docker.io/registry:latest"}"
export IMG_GOLANG_IMG="${IMG_GOLANG_IMG:-"docker.io/golang:1.17"}"
export IMG_CENTOS_IMG="${IMG_CENTOS_IMG:-"docker.io/centos:centos8"}"
export IMG_UBUNTU_IMG="${IMG_UBUNTU_IMG:-"docker.io/ubuntu:latest"}"

if [[ "${IMAGE_OS}" == "Ubuntu" ]]; then
    export KUBERNETES_VERSION=${KUBERNETES_VERSION:-"v1.22.3"}
    export KIND_NODE_IMAGE_VERSION=${KIND_NODE_IMAGE_VERSION:-"v1.22.2"}
    # Since capm3 v1a4 tests can only survive with k8s < v1.22
    # the following docker image also needs to be a part of the disk image.
    export IMG_KIND_NODE_IMAGE="${IMG_KIND_NODE_IMAGE:-"kindest/node:${KIND_NODE_IMAGE_VERSION}"}"
    export IMG_KIND_CAPM3_v1a4="kindest/node:v1.21.2"   
fi

for container in $(env | grep "IMG_*" | cut -f2 -d'='); do
  sudo "${CONTAINER_RUNTIME}" pull "${container}"
done