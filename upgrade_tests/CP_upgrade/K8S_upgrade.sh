#!/bin/bash

source ../common.sh

# fix k8s version
# ToDo, export k8s and binaries version here

export UPGRADE_USER=metal3
export INITIAL_K8S_VERSION="v1.18.0"
export INITIAL_BINARY_VERSION="v1.18.0"

export UPGRADED_K8S_VERSION_1="v1.18.1"
export UPGRADED_K8S_VERSION_2="v1.18.2"
export UPGRADED_BINARY_VERSION="v1.18.1"

pushd "${GOPATH}/src/github.com/metal3-dev-env"
echo '' > ~/.ssh/known_hosts

#create_metal3_dev_env_kind
CLUSTER_NAME=$(kubectl get clusters -n metal3 | grep Provisioned | cut -f1 -d' ')
#provision_controlplane_node
#provision_worker_node

#echo "Waiting for the start of provisioning"
#for i in {1..1800};do 
#  kubectl get bmh -n metal3 | grep 'provision'
#  if [ $? -ne 0 ]; then
#	  echo -n "."
#	  sleep 1
#	  if [[ "${i}" -eq '1800' ]];then
#		  echo "Error: provisioning took too long to start"
#		  exit 1
#     fi
#	  continue
#  else
#    break
#  fi
#done

CHOSEN_NODE=$(kubectl get bmh -n metal3 | grep control | grep -v ready | cut -f1 -d' ')
echo "BareMetalHost ${CHOSEN_NODE} is in provisioning or provisioned state"

# CHOSEN_NODE=$(kubectl get bmh -n metal3 | awk ' NR>1 {{print $1"="$3}}' | grep -v ready | cut -f1 -d=)
# NODE_IP=$(sudo virsh net-dhcp-leases baremetal | grep "${CHOSEN_NODE}"  | awk '{{print $5}}' | cut -f1 -d\/)
# for i in {1..100000};do 
#   result=$(ssh -o "StrictHostKeyChecking no" metal3@"${NODE_IP}" -- kubectl version 2>&1 /dev/null)
#   if [[ "$?" == '0' ]]; then
# 	  echo "Successfully provisioned a control plane node"
#           server_version=$(ssh -o "StrictHostKeyChecking no" "${UPGRADE_USER}@${NODE_IP}" -- kubectl version --short | grep Server)
#           client_version=$(ssh -o "StrictHostKeyChecking no" "${UPGRADE_USER}@${NODE_IP}" -- kubectl version --short | grep Client)
#           echo ${server_version}
#           echo ${server_version}
# 	  break
#   else
# 	  echo "Waiting for provisioning of ${CHOSEN_NODE} to complete..."
#   fi
# done

FROM_VERSION=$(kubectl get kcp -n metal3 -oyaml | grep "version: v1" | cut -f2 -d':' | awk '{$1=$1;print}')

if [[ "${FROM_VERSION}" < "${UPGRADED_K8S_VERSION_2}" ]]; then
  TO_VERSION="${UPGRADED_K8S_VERSION_2}"
  #echo "Upgrading the k8s version from ${FROM_VERSION} to ${UPGRADED_K8S_VERSION_2}"
  #kubectl get kcp -n metal3 -oyaml | sed "s/version: ${FROM_VERSION}/version: ${UPGRADED_K8S_VERSION_2}/" | kubectl replace -f -
elif [[ "${FROM_VERSION}" > "${INITIAL_K8S_VERSION}" ]]; then
  TO_VERSION="${INITIAL_K8S_VERSION}"
  #echo "Upgrading the k8s version from ${FROM_VERSION} to ${INITIAL_K8S_VERSION}"
  #kubectl get kcp -n metal3 -oyaml | sed "s/version: ${FROM_VERSION}/version: ${INITIAL_K8S_VERSION}/" | kubectl replace -f -
else
  exit 0
fi

echo "Upgrading a control plane node k8s version from ${FROM_VERSION} to ${TO_VERSION} in cluster ${CLUSTER_NAME}"
kubectl get kcp -n metal3 -oyaml | sed "s/version: ${FROM_VERSION}/version: ${TO_VERSION}/" | kubectl replace -f -

echo "Waiting for upgrade process to complete"
for i in {1..1800};do
  NEW_NODE_NAME=$(kubectl get bmh -n metal3 | grep -v ${CHOSEN_NODE} | grep 'prov' | grep 'control' | awk '{{print $1}}')
  if [ -n "${NEW_NODE_NAME}" ]; then
    NEW_NODE_IP=$(sudo virsh net-dhcp-leases baremetal | grep "${NEW_NODE_NAME}"  | awk '{{print $5}}' | cut -f1 -d\/)
    break
  else
    # Provisioning progress indicator
    echo -n "-"
    sleep 1
  fi
done

echo ''
echo "New node name is ${NEW_NODE_NAME}"
echo "New node IP is ${NEW_NODE_IP}"
for i in {1..1800};do 
  result=$(ssh -o "UserKnownHostsFile=/dev/null" -o "StrictHostKeyChecking no" "${UPGRADE_USER}@${NEW_NODE_IP}" -- kubectl version 2>&1 /dev/null)
  if [[ "$?" == "0" ]]; then
    echo ''
    echo "Successfully upgraded the k8s version of a control plane node"
    server_version=$(ssh -o "UserKnownHostsFile=/dev/null" -o "StrictHostKeyChecking no" "${UPGRADE_USER}@${NEW_NODE_IP}" -- kubectl version --short | grep Server)
    client_version=$(ssh -o "UserKnownHostsFile=/dev/null" -o "StrictHostKeyChecking no" "${UPGRADE_USER}@${NEW_NODE_IP}" -- kubectl version --short | grep Client)
    echo "${server_version}"
    echo "${server_version}"
    break
  fi
  # Upgrade progress indicator
  echo -n "."
  sleep 1
done

# popd

# # Verify that original node is deprovisioned.
# for i in {1..100000};do 
#   ready_nodes=$(kubectl get bmh -n metal3 | grep ready | wc -l)  
#   if [[ "${ready_nodes}" == '3' ]]; then
#     echo "Successfully deprovisioned original node"
# 	  break
#   else
# 	  echo "Waiting for original node to be deprovisioned "
#   fi
# done