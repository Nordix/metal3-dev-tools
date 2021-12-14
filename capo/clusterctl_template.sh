#!/bin/bash

set -euxo pipefail

CLUSTER_NAME="$1"
OS_CLOUD_NAME="$2"

GIT_ROOT=$(git rev-parse --show-toplevel)
CAPI_REPO=$(realpath "${GIT_ROOT}/../cluster-api")
CAPO_REPO=$(realpath "${GIT_ROOT}/../cluster-api-provider-openstack")

CLUSTERCTL="${CAPI_REPO}/bin/clusterctl"
CAPO_ENVRC="${CAPO_REPO}/templates/env.rc"

make -C "$CAPI_REPO" clusterctl

source "$CAPO_ENVRC" /tmp/clouds.yaml "${OS_CLOUD_NAME}"
env | grep OPENSTACK_CLOUD | sed 's/^/export /' > /tmp/capo_vars_openstack.sh

source ./capo_os_vars.rc
source /tmp/capo_vars_openstack.sh

"$CLUSTERCTL" generate cluster "$CLUSTER_NAME" \
    --kubernetes-version "$KUBERNETES_VERSION" \
    --from "${CAPO_REPO}/templates/cluster-template-without-lb.yaml" \
    --control-plane-machine-count=1 \
    --worker-machine-count=1 > /tmp/$CLUSTER_NAME.yaml

# Required to run in our openstack instances
sed -i 's/cloud-provider: openstack/cloud-provider: external/' /tmp/$CLUSTER_NAME.yaml

# inset provider-id field
sed -i '/kubeletExtraArgs/a provider-id: "openstack:///{{ ds.meta_data.uuid }}"' /tmp/basic-1.yaml
# correct indentation
for line_number in $(sed -n '/kubeletExtraArgs/=' /tmp/basic-1.yaml);do
	num_spaces=$(( $(sed -n "${line_number}p" /tmp/basic-1.yaml | tr -dC '[:blank:]'| wc -c) + 2))
        spaces=$(head -c $num_spaces /dev/zero | tr '\0' ' ')
	sed -i "$(( $line_number + 1 ))s/^provider-id:/${spaces}provider-id:/g" /tmp/basic-1.yaml
done