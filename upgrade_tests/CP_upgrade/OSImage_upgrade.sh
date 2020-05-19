#!/bin/bash

# ToDos
#   Repalce waiting times by a variable (MAX_WAIT_TIME)
#   Fix initial kubernetes and binaries version

source ../common.sh

echo '' > ~/.ssh/known_hosts

# provision a control plane node
provision_controlpalne_node

# Verify that provisioning of control plane node is started.
for i in {1..3600};do 
  kubectl get bmh -n metal3 | awk 'NR>1'| grep -i 'provision'
  if [ $? -ne 0 ]; then
	  echo "Waiting for the start of provisioning"
	  sleep 1
	  if [[ "${i}" -ge 3600 ]];then
		  echo "Eroro: provisioning took too long to start"
		  exit 1
          fi
	  continue
  else
     echo "provisioning of controlplane node has started"
	  break
  fi
done

# Verify that original controlplane node is provisioned such that Kubernetes is up and running
ORIGINAL_NODE=$(kubectl get bmh -n metal3 | awk ' NR>1 {{print $1"="$3}}' | grep -v ready | cut -f1 -d=)
NODE_IP=$(sudo virsh net-dhcp-leases baremetal | grep "${ORIGINAL_NODE}"  | awk '{{print $5}}' | cut -f1 -d\/)
for i in {1..3600};do 
  result=$(ssh -o PasswordAuthentication=no -o "StrictHostKeyChecking no" metal3@"${NODE_IP}" -- kubectl version 2>&1 /dev/null)
  if [[ "$?" == '0' ]]; then
	  echo "Successfully provisioned a controlplane node"
          server_version=$(ssh -o "StrictHostKeyChecking no" "${UPGRADE_USER}@${NODE_IP}" -- kubectl version --short | grep -i server)
          client_version=$(ssh -o "StrictHostKeyChecking no" "${UPGRADE_USER}@${NODE_IP}" -- kubectl version --short | grep -i client)
          echo ${server_version}
          echo ${server_version}
	  break
  else
	  echo "Waiting for provisioning of ${ORIGINAL_NODE} to complete..."
  fi
  sleep 1
done

# Create and update resources for upgrading OS image
echo "Upgrading the image for the control plane node for cluster"
Metal3MachineTemplate_OUTPUT_FILE="/tmp/new_image.yaml"
CLUSTER_UID=$(kubectl get clusters -n metal3 test1 -o json |jq '.metadata.uid' | cut -f2 -d\") 
generate_metal3MachineTemplate test1-new-image "${CLUSTER_UID}" "${Metal3MachineTemplate_OUTPUT_FILE}"
kubectl apply -f "${Metal3MachineTemplate_OUTPUT_FILE}"

# Change metal3MatchineTemplate reference
# ToDo: parameterize the name
kubectl get kubeadmcontrolplane -n metal3 test1 -o yaml > /tmp/patch-kubeadmcontrolplane.yaml
sed -i 's/name: test1-controlplane/name: test1-new-image/g' /tmp/patch-kubeadmcontrolplane.yaml
kubectl patch kubeadmcontrolplane test1 -n metal3 --type merge --patch "$(cat /tmp/patch-kubeadmcontrolplane.yaml)"

# starting to provision a new control plane node
NEW_NODE_NAME=$(kubectl get bmh -n metal3 | grep -v ${ORIGINAL_NODE} | grep 'prov' | awk '{{print $1}}')
NEW_NODE_IP=$(sudo virsh net-dhcp-leases baremetal | grep "${NEW_NODE_NAME}"  | awk '{{print $5}}' | cut -f1 -d\/)

echo "new node is ${NEW_NODE_NAME}"
echo "new ip is ${NEW_NODE_IP}"
for i in {1..3600};do 
  result=$(ssh -o PasswordAuthentication=no -o "StrictHostKeyChecking no" metal3@"${NEW_NODE_IP}" -- kubectl version 2>&1 /dev/null)
  if [[ "$?" == '0' ]]; then	  
    echo "Successfully upgrade image of a control plane node"
 	  echo "Successfully provisioned a control plane node"
      server_version=$(ssh -o "StrictHostKeyChecking no" "${UPGRADE_USER}@${NEW_NODE_IP}" -- kubectl version --short | grep Server)
      client_version=$(ssh -o "StrictHostKeyChecking no" "${UPGRADE_USER}@${NEW_NODE_IP}" -- kubectl version --short | grep Client)
      echo ${server_version}
      echo ${server_version}
    break
  fi
  echo "Waiting for the ugprade of ${NEW_NODE_NAME}" to complete"
  sleep 1
  if [[ "${i}" -ge 3600 ]];then
		  echo "Error: Upgrading process took too long to complete"
		  exit 1
  fi
done

# Verify that original node is deprovisioned.
for i in {1..3600};do 
  ready_nodes=$(kubectl get bmh -n metal3 | grep ready | wc -l)  
  if [[ "${ready_nodes}" == '3' ]]; then
    echo "Successfully deprovisioned ${ORIGINAL_NODE}"
	  break
  else
	  echo "Waiting for ${ORIGINAL_NODE} to be deprovisioned"
  fi
  sleep 1
  if [[ "${i}" -ge 3600 ]];then
		  echo "Error: deprovisioning of original node too too long to complete"
		  exit 1
  fi
done

echo "Upgrade of OS Image of controlplane node succeeded"
