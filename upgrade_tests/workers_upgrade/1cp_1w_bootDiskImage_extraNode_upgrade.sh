#!/bin/bash

source ../common.sh

echo '' > ~/.ssh/known_hosts

# TODO: cleanup
set_number_of_node_replicas 1
set_number_of_master_node_replicas 1
set_number_of_worker_node_replicas 1

provision_controlplane_node

wait_for_ctrlplane_provisioning_start

CP_NODE=$(kubectl get bmh -n metal3 | grep control | grep -v ready | cut -f1 -d' ')
echo "BareMetalHost ${CP_NODE} is in provisioning or provisioned state"
CP_NODE_IP=$(virsh net-dhcp-leases baremetal | grep "${CP_NODE}"  | awk '{{print $5}}' | cut -f1 -d\/)
wait_for_ctrlplane_provisioning_complete ${CP_NODE} ${CP_NODE_IP} "controlplane node"

# apply CNI
ssh -o PasswordAuthentication=no -o "StrictHostKeyChecking no" "${UPGRADE_USER}@${CP_NODE_IP}" -- kubectl apply -f https://docs.projectcalico.org/manifests/calico.yaml      
#provision_worker_node

# Verify that provisioning of a worker node is started.
for i in {1..3600};do 
  count=$(kubectl get bmh -n metal3 | awk 'NR>1'| grep -i 'provision' | wc -l)
  if [ $count -lt 2 ]; then
	  echo "Waiting for start of provisioning of a worker node"
	  sleep 1
	  if [[ "${i}" -ge 3600 ]];then
		  echo "Error: provisioning of a worker node took too long to start"
		  exit 1
    fi
	  continue
  else
    echo "provisioning of a worker node has started"
	  break
  fi
done
# -----------------------------------------------------------------------------------------------------------------------
CP_NODE="node-3" # remove me
WR_NODE=$(kubectl get bmh -n metal3 | grep 'provision' | grep -v ${CP_NODE} | cut -f1 -d' ')
WR_NODE_IP=$(sudo virsh net-dhcp-leases baremetal | grep "${WR_NODE}"  | awk '{{print $5}}' | cut -f1 -d\/)

echo $WR_NODE
echo $WR_NODE_IP
# echo $CP_NODE
# echo $WR_NODE

# Wait until the worker joins AND the state 
# Workers' upgrade requires CNI and kubernetes nodes' status should be ready.
for i in {1..3600};do
  r_count=$(ssh -o PasswordAuthentication=no -o "StrictHostKeyChecking no" "${UPGRADE_USER}@${CP_NODE_IP}" -- kubectl get nodes | grep Ready | wc -l)
  if [[ "$r_count" == '2' ]]; then
    echo "The worker has joined and all kubernetes nodes are in Ready state"
    break
  fi
  echo "Waiting for worker to join the cluster"
  if [[ "${i}" -ge 3600 ]]; then
	  echo "Error: It took too long for a worker to join the cluster"
	  exit 1
  fi
done

# CP_NODE="node-0"
# WR_NODE="node-2"
echo "Create a new metal3MachineTemplate with new OS Image"
Metal3MachineTemplate_OUTPUT_FILE="/tmp/new_image.yaml"
CLUSTER_UID=$(kubectl get clusters -n metal3 test1 -o json |jq '.metadata.uid' | cut -f2 -d\")
IMG_CHKSUM=$(curl -s https://cloud-images.ubuntu.com/bionic/current/MD5SUMS | grep bionic-server-cloudimg-amd64.img | cut -f1 -d' ')
generate_metal3MachineTemplate "test1-new-workers-image" "${CLUSTER_UID}" "${Metal3MachineTemplate_OUTPUT_FILE}" "${IMG_CHKSUM}"
kubectl apply -f "${Metal3MachineTemplate_OUTPUT_FILE}"
kubectl get machinedeployment -n metal3 test1 -o json | jq '.spec.template.spec.infrastructureRef.name="test1-new-workers-image"' | kubectl apply -f-

# starting to provision a new worker node
for i in {1..3600};do 
  NEW_W_NODE=$(kubectl get bmh -n metal3 | grep -v ${CP_NODE} | grep -v ${WR_NODE}  | grep 'prov' | awk '{{print $1}}')
  if [[ "$?" == '0' ]]; then	  
    # provisioing of a new worker node has started. Wait until it joins the cluster
    new_worker_count=$(ssh -o "StrictHostKeyChecking no" "${UPGRADE_USER}@${CP_NODE}" -- kubectl get nodes | grep ${NEW_W_NODE} | wc -l)
    if [[ "$new_worker_count" == '1' ]]; then	  
         
    echo "Worker was upgraded and has joined the cluster"
    break
    fi
  fi
  echo "Waiting for the ugprade of the new worker node, ${NEW_W_NODE}, to complete"
  if [[ "${i}" -ge 3600 ]]; then
		  echo "Error: Upgrading of a worker's boot disk image took to long"
		  exit 1
  fi
  sleep 1

done
# Verify that original node is deprovisioned.
for i in {1..3600};do 
  ready_nodes=$(ssh -o "StrictHostKeyChecking no" "${UPGRADE_USER}@${NEW_W_NODE_IP}" -- kubectl get nodes | grep ${NEW_W_NODE} | wc -l)  
  if [[ "${ready_nodes}" == '2' ]]; then
    echo "Successfully deprovisioned orginal worker node, "
	  break
  else
	  echo "Waiting for the original worker node, ${WR_NODE}, to be deprovisioned"
  fi
  sleep 1
  if [[ "${i}" -ge 3600 ]];then
		  echo "Error: deprovisioning of the original worker node, ${WR_NODE}, took too long to complete"
		  exit 1
  fi
done

echo "Upgrade of OS Image of worker node succeeded"

deprovision_cluster
wait_for_cluster_deprovisioned