#!/bin/bash

set -x

source ../common.sh

echo '' > ~/.ssh/known_hosts

start_logging "${1}"

set_number_of_master_node_replicas 3
set_number_of_worker_node_replicas 1

provision_controlplane_node

CLUSTER_NAME=$(kubectl get clusters -n metal3 | grep Provisioned | cut -f1 -d' ')

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

provision_worker_node
wait_for_worker_provisioning_start

ORIGINAL_NODE=$(kubectl get bmh -n metal3 | grep worker | grep -v ready | cut -f1 -d' ')
NODE_IP=$(sudo virsh net-dhcp-leases baremetal | grep "${ORIGINAL_NODE}"  | awk '{{print $5}}' | cut -f1 -d\/)

wait_for_worker_provisioning_complete 4 ${ORIGINAL_NODE} ${NODE_IP} "Worker node"

deploy_workload_on_workers

manage_node_taints ${CP_IP}

wait_for_node_to_scale_to 0 ${CP_IP} "worker"

# k8s version upgrade
FROM_VERSION=$(kubectl get kcp -n metal3 -oyaml | grep "version: v1" | cut -f2 -d':' | awk '{$1=$1;print}')

if [[ "${FROM_VERSION}" < "${UPGRADED_K8S_VERSION_2}" ]]; then
  TO_VERSION="${UPGRADED_K8S_VERSION_2}"
elif [[ "${FROM_VERSION}" > "${KUBERNETES_VERSION}" ]]; then
  TO_VERSION="${KUBERNETES_VERSION}"
else
  exit 0
fi

# Node image version upgrade
M3_MACHINE_TEMPLATE_NAME=$(kubectl get Metal3MachineTemplate -n metal3 -oyaml | grep "name: " | grep controlplane | cut -f2 -d':' | awk '{$1=$1;print}')

Metal3MachineTemplate_OUTPUT_FILE="/tmp/new_image.yaml"
CLUSTER_UID=$(kubectl get clusters -n metal3 ${CLUSTER_NAME} -o json |jq '.metadata.uid' | cut -f2 -d\")
IMG_CHKSUM=$(curl -s https://cloud-images.ubuntu.com/bionic/current/MD5SUMS | grep bionic-server-cloudimg-amd64.img | cut -f1 -d' ')
generate_metal3MachineTemplate new-controlplane-image "${CLUSTER_UID}" "${Metal3MachineTemplate_OUTPUT_FILE}" "${IMG_CHKSUM}"
kubectl apply -f "${Metal3MachineTemplate_OUTPUT_FILE}"

echo "Upgrading a control plane node image and k8s version from ${FROM_VERSION} to ${TO_VERSION} in cluster ${CLUSTER_NAME}"
# Trigger the upgrade by replacing node image and k8s version in kcp yaml:
kubectl get kcp -n metal3 -oyaml | sed "s/version: ${FROM_VERSION}/version: ${TO_VERSION}/" | sed "s/name: ${M3_MACHINE_TEMPLATE_NAME}/name: new-controlplane-image/" | kubectl replace -f -

wait_for_ug_process_to_complete

wait_for_orig_node_deprovisioned

# the control plane node might have been replaced by a worker node after the upgrade, discover a control plane ip again
CP_NEW=$(kubectl get bmh -n metal3 | grep control | grep -v ready | cut -f1 -d' ' | head -1)
CP_NEW_IP=$(sudo virsh net-dhcp-leases baremetal | grep "${CP_NEW}"  | awk '{{print $5}}' | cut -f1 -d\/)
echo "New control plane ip ${CP_NEW_IP}"
wait_for_node_to_scale_to 1 ${CP_NEW_IP} "worker"

# taints back to masters, not required by the use case so just comment
# ssh -o PasswordAuthentication=no -o "StrictHostKeyChecking no" "metal3@192.168.111.21" -- kubectl taint nodes ${CP_UG_NODE_LIST} node-role.kubernetes.io/master=value:NoSchedule

echo "successfully run ${1}" >> /tmp/$(date +"%Y.%m.%d_upgrade.result.txt")

deprovision_cluster
wait_for_cluster_deprovisioned
