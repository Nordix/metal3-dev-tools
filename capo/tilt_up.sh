#!/bin/bash

set -euxo pipefail

GIT_ROOT=$(git rev-parse --show-toplevel)
CAPI_REPO=$(realpath "${GIT_ROOT}/../cluster-api")
CAPO_REPO=$(realpath "${GIT_ROOT}/../cluster-api-provider-openstack")

cat << EOF >"$CAPI_REPO/tilt-settings.json"
{
  "default_registry": "gcr.io/cluster-api-provider",
  "provider_repos": ["${CAPO_REPO}"],
  "enable_providers": ["openstack", "kubeadm-bootstrap", "kubeadm-control-plane"],
  "kind_cluster_name": "kind-capo"
}
EOF

cd "$CAPI_REPO" && tilt up
