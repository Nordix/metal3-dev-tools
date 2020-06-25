#!/bin/bash

set -x

source ../common.sh

echo '' >~/.ssh/known_hosts

start_logging "${1}"

# Old name does not matter
export new_wr_metal3MachineTemplate_name="test1-new-workers-image"
export new_cp_metal3MachineTemplate_name="test1-new-controlplane-image"

set_number_of_master_node_replicas 1
set_number_of_worker_node_replicas 3

provision_controlplane_node
wait_for_ctrlplane_provisioning_start

CP_NODE=$(kubectl get bmh -n metal3 | grep control | grep -v ready | cut -f1 -d' ')
echo "BareMetalHost ${CP_NODE} is in provisioning or provisioned state"
CP_NODE_IP=$(sudo virsh net-dhcp-leases baremetal | grep "${CP_NODE}" | awk '{{print $5}}' | cut -f1 -d\/)
wait_for_ctrlplane_provisioning_complete "${CP_NODE}" "${CP_NODE_IP}" "original controlplane node"

# apply CNI
ssh -o PasswordAuthentication=no -o "StrictHostKeyChecking no" "${UPGRADE_USER}@${CP_NODE_IP}" -- kubectl apply -f https://docs.projectcalico.org/manifests/calico.yaml

provision_worker_node
wait_for_worker_provisioning_start

echo "Create a new metal3MachineTemplate with new node image for worker nodes"
wr_Metal3MachineTemplate_OUTPUT_FILE="/tmp/wr_new_image.yaml"

CLUSTER_UID=$(kubectl get clusters -n metal3 test1 -o json | jq '.metadata.uid' | cut -f2 -d\")
IMG_CHKSUM=$(curl -s https://cloud-images.ubuntu.com/bionic/current/MD5SUMS | grep bionic-server-cloudimg-amd64.img | cut -f1 -d' ')
generate_metal3MachineTemplate "${new_wr_metal3MachineTemplate_name}" "${CLUSTER_UID}" "${wr_Metal3MachineTemplate_OUTPUT_FILE}" "${IMG_CHKSUM}"

kubectl apply -f "${wr_Metal3MachineTemplate_OUTPUT_FILE}"

# Change metal3MachineTemplate references.
kubectl get machinedeployment -n metal3 test1 -o json | jq '.spec.strategy.rollingUpdate.maxSurge=1|.spec.strategy.rollingUpdate.maxUnavailable=1' | kubectl apply -f-
kubectl get machinedeployment -n metal3 test1 -o json | jq '.spec.template.spec.infrastructureRef.name="test1-new-workers-image"' | kubectl apply -f-

wait_for_worker_ug_process_to_complete "${CP_NODE_IP}" "${new_wr_metal3MachineTemplate_name}"

deploy_workload_on_workers

set_number_of_worker_node_replicas 2
wait_for_node_to_scale_to 2 ${CP_NODE_IP} "worker"

# upgrade a Controlplane
echo "Create a new metal3MachineTemplate with new node image for both controlplane node"
cp_Metal3MachineTemplate_OUTPUT_FILE="/tmp/cp_new_image.yaml"
CLUSTER_UID=$(kubectl get clusters -n metal3 test1 -o json | jq '.metadata.uid' | cut -f2 -d\")
IMG_CHKSUM=$(curl -s https://cloud-images.ubuntu.com/bionic/current/MD5SUMS | grep bionic-server-cloudimg-amd64.img | cut -f1 -d' ')
generate_metal3MachineTemplate "${new_cp_metal3MachineTemplate_name}" "${CLUSTER_UID}" "${cp_Metal3MachineTemplate_OUTPUT_FILE}" "${IMG_CHKSUM}"
kubectl apply -f "${cp_Metal3MachineTemplate_OUTPUT_FILE}"

# Change metal3MachineTemplate references.
kubectl get kcp -n metal3 test1 -o json | jq '.spec.infrastructureTemplate.name="test1-new-controlplane-image"' | kubectl apply -f-

echo "Waiting for completion of controlplane node upgrade"
for i in {1..3600}; do
  echo -n "+"
  sleep 10
  NEW_CP_NODE=$(kubectl get bmh -n metal3 | grep ${new_cp_metal3MachineTemplate_name} | awk '{{print $1}}')
  if [[ "${i}" -ge 3600 ]]; then
    echo "Error: Upgrade of controlplane node took too long to start"
    deprovision_cluster
    wait_for_cluster_deprovisioned
    log_test_result ${0} "fail"
    exit 1
  fi
  if [ -z "$NEW_CP_NODE" ]; then
    # CP node not being upgraded yet
    continue
  fi
  NEW_CP_NODE_IP=$(sudo virsh net-dhcp-leases baremetal | grep "${NEW_CP_NODE}" | awk '{{print $5}}' | cut -f1 -d\/)
  break # if we make it to here, then the controlplane node is being upgraded.
done

set_number_of_worker_node_replicas 3
wait_for_node_to_scale_to 3 ${NEW_CP_NODE_IP} "worker"

echo "Upgrading of both (1M + 3W) using scaling in of workers has succeeded"
log_test_result ${0} "pass"

deprovision_cluster
wait_for_cluster_deprovisioned

#status: passed