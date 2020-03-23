!/bin/bash

# fix k8s version
# call make
# provision a control plane node
# provision a cluster
# provisoin a worker

export UPGRADE_USER=metal3
export INITIAL_K8S_VERSION="v1.18.0"
export INITIAL_BINARY_VERSION="v1.18.0"

export UPGRADED_K8S_VERSION_1="v1.18.1"
export UPGRADED_K8S_VERSION_2="v1.18.2"
export UPGRADED_BINARY_VERSION="v1.18.1"


pushd "/home/ubuntu/metal3-dev-env"

echo '' > ~/.ssh/known_hosts

function generate_metal3MachineTemplate () {
  NAME="${1}"
  C_UID="${2}"
  Metal3MachineTemplate_OUTPUT_FILE="${3}"

echo "
apiVersion: infrastructure.cluster.x-k8s.io/v1alpha3
kind: Metal3MachineTemplate
metadata:
  name: ${NAME}
  namespace: metal3
  ownerReferences:
  - apiVersion: cluster.x-k8s.io/v1alpha3
    kind: Cluster
    name: test1
    uid: "${C_UID}"
spec:
  template:
    spec:
      hostSelector: {}
      image:
        checksum: http://172.22.0.1/images/bionic-server-cloudimg-amd64.img.md5sum
        url: https://cloud-images.ubuntu.com/bionic/current/bionic-server-cloudimg-amd64.img
" > "${Metal3MachineTemplate_OUTPUT_FILE}"
}

# echo "Provisioning a control plane node ...."
# #./scripts/v1alphaX/provision_cluster.sh
# #./scripts/v1alphaX/provision_controlplane.sh

# for i in {1..1800};do 
#   kubectl get bmh -n metal3 | grep 'provision'
#   if [ $? -ne 0 ]; then
# 	  echo "Waiting for the start of provisioning"
# 	  sleep 1
# 	  if [[ "${i}" -eq '1800' ]];then
# 		  echo "Eroro: provisioning took too long to start"
# 		  exit 1
#           fi
# 	  continue
#   else
# 	  break
#   fi
#
# #done
# echo 'BareMetalHost is in provisioning or provisioned state'
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

# echo "Upgrading the image for the control plane node for cluster"
# Metal3MachineTemplate_OUTPUT_FILE="/tmp/new_image.yaml"
# CLUSTER_UID=$(kubectl get clusters -n metal3 test1 -o json |jq '.metadata.uid' | cut -f2 -d\") 
# generate_metal3MachineTemplate test1-new-image "${CLUSTER_UID}" "${Metal3MachineTemplate_OUTPUT_FILE}"
# kubectl apply -f "${Metal3MachineTemplate_OUTPUT_FILE}"

# # Change metal3MatchineTemplate reference
# # ToDo: parameterize the name
kubectl get machinedeployments -n metal3 test1 -o yaml > /tmp/machinedeployment.yaml
sed -i 's/name: test1-workers/name: test1-new-image/g' /tmp/machinedeployment.yaml
kubectl apply -f /tmp/machinedeployment.yaml

# # kubectl patch kubeadmcontrolplane test1 -n metal3 --type merge --patch "$(cat /tmp/patch-kubeadmcontrolplane.yaml)"

# echo "Waiting for upgrade process to complete ...."
# # parameterize node1
# NEW_NODE_NAME=$(kubectl get bmh -n metal3 | grep -v node-1 | grep 'prov' | awk '{{print $1}}')
# NEW_NODE_IP=$(sudo virsh net-dhcp-leases baremetal | grep "${NEW_NODE_NAME}"  | awk '{{print $5}}' | cut -f1 -d\/)

# echo "new node is ${NEW_NODE_NAME}"
# echo "new ip is ${NEW_NODE_IP}"
# for i in {1..1800};do 
#   result=$(ssh -o "StrictHostKeyChecking no" metal3@"${NEW_NODE_IP}" -- kubectl version 2>&1 /dev/null)
#   if [[ "$?" == '0' ]]; then	  
#     echo "Successfully upgrade image of a control plane node"
#  	  echo "Successfully provisioned a control plane node"
#       server_version=$(ssh -o "StrictHostKeyChecking no" "${UPGRADE_USER}@${NEW_NODE_IP}" -- kubectl version --short | grep Server)
#       client_version=$(ssh -o "StrictHostKeyChecking no" "${UPGRADE_USER}@${NEW_NODE_IP}" -- kubectl version --short | grep Client)
#       echo ${server_version}
#       echo ${server_version}
#     break
#   fi
#   echo "Waiting for the ugprade process to complete"
#   sleep 1
# done

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



# waiting for worker to be provisioned., parameterize this name
# test1-workers-47z4p , search for this
kubectl get bmh -n metal3 | grep test1-workers | wc -l
# ssh to the master and count nodes | grep for the newly added worker
ssh metal3@192.168.111.23 -- kubectl get nodes  

# waiting for worker upgraded
# ugpraded-workers-newos-image  presence
# test1-workers absence
# kubect get nodes on the master