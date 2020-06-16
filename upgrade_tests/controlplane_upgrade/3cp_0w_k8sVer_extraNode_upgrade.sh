#!/bin/bash

set -x

source ../common.sh

echo '' > ~/.ssh/known_hosts

start_logging "${0}"

set_number_of_master_node_replicas 3

provision_controlplane_node

CLUSTER_NAME=$(kubectl get clusters -n metal3 | grep Provisioned | cut -f1 -d' ')

wait_for_ctrlplane_provisioning_start

ORIGINAL_NODE_LIST=$(kubectl get bmh -n metal3 | grep control | grep -v ready | cut -f1 -d' ')
echo "BareMetalHosts ${ORIGINAL_NODE_LIST} are in provisioning or provisioned state"

NODE_IP_LIST=()
for node in "${ORIGINAL_NODE_LIST[@]}";do
    NODE_IP_LIST+=$(sudo virsh net-dhcp-leases baremetal | grep "${node}"  | awk '{{print $5}}' | cut -f1 -d\/)
done
echo "NODE_IP_LIST ${NODE_IP_LIST[@]}"
wait_for_ctrlplane_provisioning_complete ${ORIGINAL_NODE_LIST[@]} ${NODE_IP_LIST[@]}

FROM_VERSION=$(kubectl get kcp -n metal3 -oyaml | grep "version: v1" | cut -f2 -d':' | awk '{$1=$1;print}')

if [[ "${FROM_VERSION}" < "${UPGRADED_K8S_VERSION_2}" ]]; then
  TO_VERSION="${UPGRADED_K8S_VERSION_2}"
elif [[ "${FROM_VERSION}" > "${KUBERNETES_VERSION}" ]]; then
  TO_VERSION="${KUBERNETES_VERSION}"
else
  exit 0
fi

echo "Upgrading a control plane nodes k8s version from ${FROM_VERSION} to ${TO_VERSION} in cluster ${CLUSTER_NAME}"
kubectl get kcp -n metal3 -oyaml | sed "s/version: ${FROM_VERSION}/version: ${TO_VERSION}/" | kubectl replace -f -

wait_for_ug_process_to_complete

wait_for_orig_node_deprovisioned

echo "Upgrading a control plane nodes k8s version from ${FROM_VERSION} to ${TO_VERSION} in cluster ${CLUSTER_NAME}, has succeeded"
echo "successfully run ${0}" >> /tmp/$(date +"%Y.%m.%d_upgrade.result.txt")

deprovision_cluster
wait_for_cluster_deprovisioned
