#!/bin/bash

set -x

source ../common.sh

echo '' > ~/.ssh/known_hosts

start_logging "${1}"

set_number_of_master_node_replicas 1
set_number_of_worker_node_replicas 1

provision_controlplane_node

NAMESPACE=${NAMESPACE:-"metal3"}
CLUSTER_NAME=$(kubectl get clusters -n "${NAMESPACE}" | grep Provisioned | cut -f1 -d' ')

wait_for_ctrlplane_provisioning_start

ORIGINAL_NODE_LIST=$(kubectl get bmh -n "${NAMESPACE}" | grep control | grep -v ready | cut -f1 -d' ')
echo "BareMetalHosts ${ORIGINAL_NODE_LIST} are in provisioning or provisioned state"

NODE_IP_LIST=()
for node in "${ORIGINAL_NODE_LIST[@]}";do
    NODE_IP_LIST+=$(sudo virsh net-dhcp-leases baremetal | grep "${node}"  | awk '{{print $5}}' | cut -f1 -d\/)
done
echo "NODE_IP_LIST ${NODE_IP_LIST[@]}"
wait_for_ctrlplane_provisioning_complete ${ORIGINAL_NODE_LIST[@]} ${NODE_IP_LIST[@]}

kubectl get kcp -n "${NAMESPACE}" -oyaml | sed "s/release\/v1.18.0\/bin/release\/v1.18.1\/bin/g" | kubectl replace -f -

if [ $? -eq 0 ]; then
    echo "Mutating KubeadmControlPlane is succeeded"
else
    echo "Mutating KubeadmControlPlane is failed"
fi

wait_for_ug_process_to_complete

wait_for_orig_node_deprovisioned master_and_worker 2

echo "Mutation of kubeadm data has succeded"
echo "successfully run ${1}" >> /tmp/$(date +"%Y.%m.%d_upgrade.result.txt")

deprovision_cluster
wait_for_cluster_deprovisioned
