#!/bin/bash

set -x

source ../common.sh

echo '' >~/.ssh/known_hosts

start_logging "${1}"

set_number_of_master_node_replicas 1

provision_controlplane_node

wait_for_ctrlplane_provisioning_start

# Verify that original controlplane node is provisioned such that Kubernetes is up and running
ORIGINAL_NODE=$(kubectl get bmh -n metal3 | awk ' NR>1 {{print $1"="$3}}' | grep -v ready | cut -f1 -d=)
NODE_IP=$(sudo virsh net-dhcp-leases baremetal | grep "${ORIGINAL_NODE}" | awk '{{print $5}}' | cut -f1 -d\/)

wait_for_ctrlplane_provisioning_complete ${ORIGINAL_NODE} ${NODE_IP} "Original node"

# Create and update resources for upgrading OS image
echo "Upgrading the image for the control plane node for cluster"
Metal3MachineTemplate_OUTPUT_FILE="/tmp/new_image.yaml"
CLUSTER_UID=$(kubectl get clusters -n metal3 test1 -o json | jq '.metadata.uid' | cut -f2 -d\")
IMG_CHKSUM=$(curl -s https://cloud-images.ubuntu.com/bionic/current/MD5SUMS | grep bionic-server-cloudimg-amd64.img | cut -f1 -d' ')
generate_metal3MachineTemplate test1-new-image "${CLUSTER_UID}" "${Metal3MachineTemplate_OUTPUT_FILE}" "${IMG_CHKSUM}"
kubectl apply -f "${Metal3MachineTemplate_OUTPUT_FILE}"

# Change metal3MatchineTemplate reference
kubectl get kubeadmcontrolplane -n metal3 test1 -o yaml >/tmp/patch-kubeadmcontrolplane.yaml
sed -i 's/name: test1-controlplane/name: test1-new-image/g' /tmp/patch-kubeadmcontrolplane.yaml
kubectl patch kubeadmcontrolplane test1 -n metal3 --type merge --patch "$(cat /tmp/patch-kubeadmcontrolplane.yaml)"

wait_for_ug_process_to_complete

wait_for_orig_node_deprovisioned master 3

echo "Upgrade of OS Image of controlplane node succeeded"
log_test_result ${0} "pass"

deprovision_cluster
wait_for_cluster_deprovisioned
