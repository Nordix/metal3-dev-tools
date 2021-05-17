#!/bin/bash

set -euxo pipefail

CLUSTER_NAME="$1"

GIT_ROOT=$(git rev-parse --show-toplevel)
CAPI_REPO=$(realpath "${GIT_ROOT}/../cluster-api")
CAPO_REPO=$(realpath "${GIT_ROOT}/../cluster-api-provider-openstack")

CLUSTERCTL="${CAPI_REPO}/bin/clusterctl"
CAPO_ENVRC="${CAPO_REPO}/templates/env.rc"

make -C "$CAPI_REPO" clusterctl

source "$CAPO_ENVRC" /tmp/clouds.yaml openstack
source ./capo_os_vars.rc

"$CLUSTERCTL" config cluster "$CLUSTER_NAME" \
    --kubernetes-version v1.19.1 \
    --from "${CAPO_REPO}/templates/cluster-template-without-lb.yaml" \
    --control-plane-machine-count=1 \
    --worker-machine-count=1 > /tmp/$CLUSTER_NAME.yaml
