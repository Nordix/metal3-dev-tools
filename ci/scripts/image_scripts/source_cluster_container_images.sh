#!/bin/bash

set -uex

export CONTAINER_RUNTIME="${CONTAINER_RUNTIME}"
# Container images that we pre-pull into the CI image.
export IMG_REGISTRY="${IMG_REGISTRY:-"docker.io/registry:latest"}"
export IMG_GOLANG_IMG="${IMG_GOLANG_IMG:-"registry.hub.docker.com/library/golang:1.16"}"
export IMG_CENTOS_IMG="${IMG_CENTOS_IMG:-"docker.io/centos:centos8"}"

if [[ "${IMAGE_OS}" == "Ubuntu" ]]; then
    export KUBERNETES_VERSION=${KUBERNETES_VERSION:-"v1.21.2"}
    export KIND_NODE_IMAGE_VERSION=${KIND_NODE_IMAGE_VERSION:-"v1.21.2"}   
    export IMG_KIND_NODE_IMAGE="${IMG_KIND_NODE_IMAGE:-"kindest/node:${KIND_NODE_IMAGE_VERSION}"}"
fi

if [[ "${CONTAINER_RUNTIME}" == "docker" ]]; then
    for container in $(env | grep "IMG_*" | cut -f2 -d'='); do
      sudo "${CONTAINER_RUNTIME}" pull "${container}"
    done
else
    for container in $(env | grep "IMG_*" | cut -f2 -d'='); do
      "${CONTAINER_RUNTIME}" pull "${container}"
    done    
fi
