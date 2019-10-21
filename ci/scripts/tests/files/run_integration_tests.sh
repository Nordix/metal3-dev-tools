#!/bin/bash

set -eux

export METAL3REPO='https://github.com/metal3-io/metal3-dev-env.git'
export METAL3BRANCH='master'
export BMOREPO='https://github.com/metal3-io/baremetal-operator.git'
export BMOBRANCH='master'
export CAPBMREPO='https://github.com/metal3-io/cluster-api-provider-baremetal.git'
export CAPBMBRANCH='master'
export CONTAINER_RUNTIME="docker"

git clone "${METAL3REPO}" metal3
pushd metal3
git checkout "${METAL3BRANCH}"
sleep 25m
make
make test
make clean
