#!/bin/bash

set -x

source ../common.sh

echo '' > ~/.ssh/known_hosts

start_logging "${1}"

set_number_of_master_node_replicas 1

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

M3_MACHINE_TEMPLATE_NAME=$(kubectl get Metal3MachineTemplate -n metal3 -oyaml | grep "name: " | grep controlplane | cut -f2 -d':' | awk '{$1=$1;print}')

Metal3MachineTemplate_OUTPUT_FILE="/tmp/new_image.yaml"
CLUSTER_UID=$(kubectl get clusters -n metal3 ${CLUSTER_NAME} -o json |jq '.metadata.uid' | cut -f2 -d\")
IMG_CHKSUM=$(curl -s https://cloud-images.ubuntu.com/bionic/current/MD5SUMS | grep bionic-server-cloudimg-amd64.img | cut -f1 -d' ')
generate_metal3MachineTemplate new-controlplane-image "${CLUSTER_UID}" "${Metal3MachineTemplate_OUTPUT_FILE}" "${IMG_CHKSUM}"
kubectl apply -f "${Metal3MachineTemplate_OUTPUT_FILE}"

echo "Upgrading a control plane node image and k8s version from ${FROM_VERSION} to ${TO_VERSION} in cluster ${CLUSTER_NAME}"
# replace node image and k8s version in kcp yaml:
kubectl get kcp -n metal3 -oyaml | sed "s/version: ${FROM_VERSION}/version: ${TO_VERSION}/" | sed "s/name: ${M3_MACHINE_TEMPLATE_NAME}/name: new-controlplane-image/" | kubectl replace -f -

wait_for_ug_process_to_complete

wait_for_orig_node_deprovisioned master 1

echo "Upgrading a control plane node image and k8s version from ${FROM_VERSION} to ${TO_VERSION} in cluster ${CLUSTER_NAME} has succeeded"
echo "successfully run ${1}" >> /tmp/$(date +"%Y.%m.%d_upgrade.result.txt")

deprovision_cluster
wait_for_cluster_deprovisioned
