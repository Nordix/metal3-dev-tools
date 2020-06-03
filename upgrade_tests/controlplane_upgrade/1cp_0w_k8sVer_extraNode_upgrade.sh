#!/bin/bash

source ../common.sh

echo '' > ~/.ssh/known_hosts

provision_controlplane_node

CLUSTER_NAME=$(kubectl get clusters -n metal3 | grep Provisioned | cut -f1 -d' ')

wait_for_ctrlplane_provisioning_start

ORIGINAL_NODE=$(kubectl get bmh -n metal3 | grep control | grep -v ready | cut -f1 -d' ')
echo "BareMetalHost ${ORIGINAL_NODE} is in provisioning or provisioned state"
NODE_IP=$(virsh net-dhcp-leases baremetal | grep "${ORIGINAL_NODE}"  | awk '{{print $5}}' | cut -f1 -d\/)

wait_for_ctrlplane_provisioning_complete ${ORIGINAL_NODE} ${NODE_IP} "Original node"

FROM_VERSION=$(kubectl get kcp -n metal3 -oyaml | grep "version: v1" | cut -f2 -d':' | awk '{$1=$1;print}')

if [[ "${FROM_VERSION}" < "${UPGRADED_K8S_VERSION_2}" ]]; then
  TO_VERSION="${UPGRADED_K8S_VERSION_2}"
elif [[ "${FROM_VERSION}" > "${KUBERNETES_VERSION}" ]]; then
  TO_VERSION="${KUBERNETES_VERSION}"
else
  exit 0
fi

echo "Upgrading a control plane node k8s version from ${FROM_VERSION} to ${TO_VERSION} in cluster ${CLUSTER_NAME}"
kubectl get kcp -n metal3 -oyaml | sed "s/version: ${FROM_VERSION}/version: ${TO_VERSION}/" | kubectl replace -f -

wait_for_ug_process_to_complete ${ORIGINAL_NODE}

wait_for_orig_node_deprovisioned ${ORIGINAL_NODE}
