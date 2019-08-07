#!/bin/bash

set -eux

export METAL3REPO="${1:-https://github.com/metal3-io/metal3-dev-env.git}"
export METAL3BRANCH="${2:-master}"
export BMOREPO="${3:-https://github.com/metal3-io/baremetal-operator.git}"
export BMOBRANCH="${4:-master}"
export CAPBMREPO="${5:-https://github.com/metal3-io/cluster-api-provider-baremetal.git}"
export CAPBMBRANCH="${6:-master}"
export CONTAINER_RUNTIME="docker"

git clone "${METAL3REPO}" metal3
pushd metal3
git checkout "${METAL3BRANCH}"
make
