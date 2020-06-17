#!/bin/bash

set -x

source ../common.sh

echo '' > ~/.ssh/known_hosts

start_logging "${1}"

# Old name does not matter
export new_cp_metal3MachineTemplate_name="test1-new-controlplane-image"

set_number_of_master_node_replicas 3

provision_controlplane_node
wait_for_ctrlplane_provisioning_start

CP_ORIGINAL_NODE_LIST=$(kubectl get bmh -n metal3 | grep control | grep -v ready | cut -f1 -d' ')
echo "BareMetalHosts ${CP_ORIGINAL_NODE_LIST} are in provisioning or provisioned state"

NODE_IP_LIST=()
for node in "${CP_ORIGINAL_NODE_LIST[@]}";do
    NODE_IP_LIST+=$(sudo virsh net-dhcp-leases baremetal | grep "${node}"  | awk '{{print $5}}' | cut -f1 -d\/)
done
echo "NODE_IP_LIST ${NODE_IP_LIST[@]}"
wait_for_ctrlplane_provisioning_complete ${CP_ORIGINAL_NODE_LIST[@]} ${NODE_IP_LIST[@]}

# list consists of 3 ctrl plane node ips
CP_IP="${NODE_IP_LIST[0]}"

# apply CNI
ssh -o PasswordAuthentication=no -o "StrictHostKeyChecking no" "${UPGRADE_USER}@${CP_IP}" -- kubectl apply -f https://docs.projectcalico.org/manifests/calico.yaml

# Upgrade node image of controlplane nodes
echo "Create a new metal3MachineTemplate with new node image for controlplane node"
cp_Metal3MachineTemplate_OUTPUT_FILE="/tmp/cp_new_image.yaml"
CLUSTER_UID=$(kubectl get clusters -n metal3 test1 -o json |jq '.metadata.uid' | cut -f2 -d\")
IMG_CHKSUM=$(curl -s https://cloud-images.ubuntu.com/bionic/current/MD5SUMS | grep bionic-server-cloudimg-amd64.img | cut -f1 -d' ')
generate_metal3MachineTemplate "${new_cp_metal3MachineTemplate_name}" "${CLUSTER_UID}" "${cp_Metal3MachineTemplate_OUTPUT_FILE}" "${IMG_CHKSUM}"
kubectl apply -f "${cp_Metal3MachineTemplate_OUTPUT_FILE}"

# Change metal3MachineTemplate references.
kubectl get kcp -n metal3 test1 -o json | jq '.spec.infrastructureTemplate.name="test1-new-controlplane-image"' | kubectl apply -f-

wait_for_ug_process_to_complete

wait_for_orig_node_deprovisioned
echo "successfully run ${1}" >> /tmp/$(date +"%Y.%m.%d_upgrade.result.txt")

deprovision_cluster
wait_for_cluster_deprovisioned
