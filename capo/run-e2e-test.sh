#!/bin/bash

GIT_ROOT=$(git rev-parse --show-toplevel)
CAPO_REPO=$(realpath "${GIT_ROOT}/../cluster-api-provider-openstack")

echo "source relevant variables"
source ./e2e_os_vars.rc
source /tmp/e2e_vars_openstack.sh

# Remove capo-e2e cluster, if it exists
kind delete cluster --name capo-e2e || echo "capo-e2e ind cluster does not exist"
rm -rf  "${CAPO_REPO}/_artifacts/ssh" | echo "No ssh keys found"
docker run --rm -v /tmp/openstackrc:/tmp/openstackrc openstacktools/openstack-client \
    bash -c "source /tmp/openstackrc && openstack keypair delete cluster-api-provider-openstack-sigs-k8s-io 2>/dev/null"
# move to capo repo
pushd "${CAPO_REPO}"
make test-e2e
popd
