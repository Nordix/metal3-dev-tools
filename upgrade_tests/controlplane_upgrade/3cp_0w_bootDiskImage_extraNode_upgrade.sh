#!/bin/bash

set -x

source ../common.sh

echo '' > ~/.ssh/known_hosts

start_logging "${0}"

# Old name does not matter
export new_cp_metal3MachineTemplate_name="test1-new-controlplane-image"

# TODO: cleanup
set_number_of_node_replicas 3
set_number_of_master_node_replicas 3

provision_controlplane_node
wait_for_ctrlplane_provisioning_start

CP_NODE=$(kubectl get bmh -n metal3 | grep control | grep -v ready | cut -f1 -d' ')
echo "BareMetalHost ${CP_NODE} is in provisioning or provisioned state"
CP_NODE_IP=$(virsh net-dhcp-leases baremetal | grep "${CP_NODE}"  | awk '{{print $5}}' | cut -f1 -d\/)
wait_for_ctrlplane_provisioning_complete ${CP_NODE} ${CP_NODE_IP} "original controlplane node"
# apply CNI
ssh -o PasswordAuthentication=no -o "StrictHostKeyChecking no" "${UPGRADE_USER}@${CP_NODE_IP}" -- kubectl apply -f https://docs.projectcalico.org/manifests/calico.yaml

wait_for_ctrlplane_to_scale_out ${CP_NODE_IP}

# Upgrade boot disk image of controlplane nodes
echo "Create a new metal3MachineTemplate with new boot disk image for controlplane node"
cp_Metal3MachineTemplate_OUTPUT_FILE="/tmp/cp_new_image.yaml"
CLUSTER_UID=$(kubectl get clusters -n metal3 test1 -o json |jq '.metadata.uid' | cut -f2 -d\")
IMG_CHKSUM=$(curl -s https://cloud-images.ubuntu.com/bionic/current/MD5SUMS | grep bionic-server-cloudimg-amd64.img | cut -f1 -d' ')
generate_metal3MachineTemplate "${new_cp_metal3MachineTemplate_name}" "${CLUSTER_UID}" "${cp_Metal3MachineTemplate_OUTPUT_FILE}" "${IMG_CHKSUM}"
kubectl apply -f "${cp_Metal3MachineTemplate_OUTPUT_FILE}"

# Change metal3MachineTemplate references.
kubectl get kcp -n metal3 test1 -o json | jq '.spec.infrastructureTemplate.name="test1-new-controlplane-image"' | kubectl apply -f-

echo "Waiting for start of boot disk upgrade of all controlplane nodes"
for i in {1..3600};do
  count=$(kubectl get bmh -n metal3 | awk 'NR>1'| grep -i ${new_cp_metal3MachineTemplate_name} | wc -l)
  if [ $count -lt 3 ]; then
      echo -n "-"
	  if [[ "${i}" -ge 3600 ]];then
		  echo "Error: Upgrade of controlplane nodes did not start in time"
		  exit 1
      fi
      sleep 5
	  continue
  else
    echo "Upgrade of all controlplane nodes has started"
	  break
  fi
done

# Out of the three, choose one of the controlplane nodes.
UG_CP_NODE=$(kubectl get bmh -n metal3 | grep 'new-workers-image' | awk '{{print $1}}' | head -n 1)
UG_CP_NODE_IP=$(sudo virsh net-dhcp-leases baremetal | grep "${UG_CP_NODE}"  | awk '{{print $5}}' | cut -f1 -d\/)

# Verify that all upgraded controlplane nodes have joined the cluster.
echo "Waiting for all upgraded controlplane nodes to join the cluster"
for i in {1..3600};do
  echo -n "*"
  replicas=$(ssh "-o LogLevel=quiet" -o "UserKnownHostsFile=/dev/null" -o PasswordAuthentication=no -o "StrictHostKeyChecking no" "${UPGRADE_USER}@${UG_CP_NODE_IP}" -- kubectl get nodes| grep master | wc -l)
  if [[ "$replicas" == "3" ]]; then
    echo ''
    echo "Upgraded ontrolplane nodes have joined the cluster"
    break
  fi
  sleep 5
  if [[ "${i}" -ge 3600 ]];then
		  echo "Error: Upgraded controlplane node did not join the cluster in time"
		  exit 1
  fi
done

# We expect one free node
echo "Waiting for the deprovisioning of a controlplane node"
for i in {1..3600};do
  count_freed_nodes=$(kubectl get bmh -n metal3 | awk '{{print $3}}' | grep ready | wc -l)
  if [[ "${count_freed_nodes}" == '2' ]]; then
    echo "Successfully deprovisioned a controlplane and node"
	  break
  else
	  echo -n "-"
  fi
  sleep 5
  if [[ "${i}" -ge 3600 ]];then
		  echo "Error: deprovisioning of the a controlplane node took too long"
		  exit 1
  fi
done

deprovision_cluster
wait_for_cluster_deprovisioned