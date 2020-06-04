#!/bin/bash

source ../common.sh

echo '' > ~/.ssh/known_hosts

# Old name does not matter
export new_wr_metal3MachineTemplate_name="test1-new-workers-image"
export new_cp_metal3MachineTemplate_name="test1-new-controlplane-image"

# provision a controlplane node
provision_controlplane_node
wait_for_ctrlplane_provisioning_start

CP_NODE=$(kubectl get bmh -n metal3 | grep control | grep -v ready | cut -f1 -d' ')
echo "BareMetalHost ${CP_NODE} is in provisioning or provisioned state"
CP_NODE_IP=$(virsh net-dhcp-leases baremetal | grep "${CP_NODE}"  | awk '{{print $5}}' | cut -f1 -d\/)
wait_for_ctrlplane_provisioning_complete ${CP_NODE} ${CP_NODE_IP} "original controlplane node"
# apply CNI
ssh -o PasswordAuthentication=no -o "StrictHostKeyChecking no" "${UPGRADE_USER}@${CP_NODE_IP}" -- kubectl apply -f https://docs.projectcalico.org/manifests/calico.yaml

provision_worker_node
# Wait until the worker joins AND the state is ready
# Workers' upgrade requires CNI and kubernetes nodes' status should be ready.
echo "Waiting for worker to join the cluster"
for i in {1..3600};do
  r_count=$(ssh -o PasswordAuthentication=no -o "StrictHostKeyChecking no" "${UPGRADE_USER}@${CP_NODE_IP}" -- kubectl get nodes | grep Ready | wc -l)
  if [[ "$r_count" == '2' ]]; then
    echo "The worker has joined and all kubernetes nodes are in Ready state"
    break
  fi
  echo -n "*"
  sleep 5
  if [[ "${i}" -ge 3600 ]]; then
	  echo "Error: It took too long for a worker to join the cluster"
	  exit 1
  fi
done

wait_for_worker_to_scale_out ${CP_NODE_IP}

echo "Create a new metal3MachineTemplate with new boot disk image for worker nodes"
wr_Metal3MachineTemplate_OUTPUT_FILE="/tmp/wr_new_image.yaml"
CLUSTER_UID=$(kubectl get clusters -n metal3 test1 -o json |jq '.metadata.uid' | cut -f2 -d\")
generate_metal3MachineTemplate "${new_wr_metal3MachineTemplate_name}" "${CLUSTER_UID}" "${wr_Metal3MachineTemplate_OUTPUT_FILE}"

kubectl apply -f "${wr_Metal3MachineTemplate_OUTPUT_FILE}"

# Change metal3MachineTemplate references.
kubectl get machinedeployment -n metal3 test1 -o json | jq '.spec.strategy.rollingUpdate.maxSurge=1|.spec.strategy.rollingUpdate.maxUnavailable=1' | kubectl apply -f-
kubectl get machinedeployment -n metal3 test1 -o json | jq '.spec.template.spec.infrastructureRef.name="test1-new-workers-image"' | kubectl apply -f-

echo "Waiting for start of boot disk upgrade of all worker nodes"
for i in {1..3600};do
  count=$(kubectl get bmh -n metal3 | awk 'NR>1'| grep -i ${new_wr_metal3MachineTemplate_name} | wc -l)
  if [ $count -lt 3 ]; then
      echo -n "-"
	  if [[ "${i}" -ge 3600 ]];then
		  echo "Error: Upgrade on some or all worker nodes did not start in time"
		  exit 1
      fi
      sleep 5
	  continue
  else
    echo "Upgrade of all worker nodes has started"
	  break
  fi
done

# Verify that all upgraded worker nodes have joined the cluster.
echo "Waiting for all upgraded worker nodes to join the cluster"
for i in {1..3600};do
  echo -n "*"
  replicas=$(ssh "-o LogLevel=quiet" -o "UserKnownHostsFile=/dev/null" -o PasswordAuthentication=no -o "StrictHostKeyChecking no" "${UPGRADE_USER}@${CP_NODE_IP}" -- kubectl get nodes | awk 'NR>1'|grep -v master | wc -l)
  if [[ "$replicas" == "3" ]]; then
    echo ''
    echo "Upgraded worker nodes have joined the cluster"
    break
  fi
  sleep 5
  if [[ "${i}" -ge 3600 ]];then
		  echo "Error: Upgraded worker node did not join the cluster in time"
		  exit 1
  fi
done
# deploy workloads on workers
cat <<EOF | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: workload-1-deployment
spec:
  replicas: 10
  selector:
    matchLabels:
      app: workload-1
  template:
    metadata:
      labels:
        app: workload-1
    spec:
      containers:
      - name: nginx
        image: nginx
EOF

# wait for workloads to be ready


echo "Waiting for workloads to be ready"
for i in {1..1800};do
    #workload_replicas=$(ssh "-o LogLevel=quiet" -o "UserKnownHostsFile=/dev/null" -o PasswordAuthentication=no -o "StrictHostKeyChecking no" "${UPGRADE_USER}@${CP_NODE_IP}" -- kubectl get deployments workload-1-deployment -o json | jq '.status.readyReplicas')
    workload_replicas=$(kubectl get deployments workload-1-deployment -o json | jq '.status.readyReplicas')
    if [[ "$workload_replicas" == "10" ]]; then
        echo ''
        echo "Successfully deployed workloads accross the cluster"
        break
    fi
    echo -n "*"
    sleep 5
    if [[ "${i}" -ge 1800 ]];then
        echo "Error: Workload failed to be deployed on the cluster"
        exit 1
    fi
done

# scale in workers, change replicas to two
echo "Scaling in worker nodes"
kubectl get machinedeployment -n metal3 test1 -o json | jq '.spec.replicas=2' | kubectl apply -f-
for i in {1..1800};do
    replicas=$(ssh "-o LogLevel=quiet" -o "UserKnownHostsFile=/dev/null" -o PasswordAuthentication=no -o "StrictHostKeyChecking no" "${UPGRADE_USER}@${CP_NODE_IP}" -- kubectl get nodes | awk 'NR>1' | grep -v master | wc -l)
    if [[ "$replicas" == "2" ]]; then
        echo ''
        echo "Successfully scaled in worker nodes"
        break
    fi
    echo -n "*"
    sleep 5
    if [[ "${i}" -ge 1800 ]];then
        echo "Error: Scaling in of workers nodes took too long"
        exit 1
    fi
done

# TBD
# upgrade a CP
#   ****** change os reference
#   ****** repeate the waiting and verification as well.

echo "Create a new metal3MachineTemplate with new boot disk image for both controlplane node"
cp_Metal3MachineTemplate_OUTPUT_FILE="/tmp/cp_new_image.yaml"
CLUSTER_UID=$(kubectl get clusters -n metal3 test1 -o json |jq '.metadata.uid' | cut -f2 -d\")
generate_metal3MachineTemplate "${new_cp_metal3MachineTemplate_name}" "${CLUSTER_UID}" "${cp_Metal3MachineTemplate_OUTPUT_FILE}"
kubectl apply -f "${cp_Metal3MachineTemplate_OUTPUT_FILE}"

# Change metal3MachineTemplate references.
kubectl get kcp -n metal3 test1 -o json | jq '.spec.infrastructureTemplate.name="test1-new-controlplane-image"' | kubectl apply -f-

# Wait for the start of provisioning of new controlplane and worker nodes
echo "Waiting for completion of controlplane node upgrade"
for i in {1..3600};do
  echo -n "+"
  sleep 5
  NEW_CP_NODE=$(kubectl get bmh -n metal3 | grep ${new_cp_metal3MachineTemplate_name} | awk '{{print $1}}')
    if [[ "${i}" -ge 3600 ]]; then
		  echo "Error: Upgrade of controlplane node took too long to start"
		  exit 1
  fi
  if [ -z "$NEW_CP_NODE" ]; then
      # CP node not being upgraded yet
      continue
  fi
  NEW_CP_NODE_IP=$(sudo virsh net-dhcp-leases baremetal | grep "${NEW_CP_NODE}"  | awk '{{print $5}}' | cut -f1 -d\/)
  break # if we made it here, then the controlplane node is being upgraded.
done
wait_for_ctrlplane_provisioning_complete ${NEW_CP_NODE} ${NEW_CP_NODE_IP} "upgraded controlplane node"

# scale out workers, change repliacs back three
echo "Scaling out worker nodes"
kubectl get machinedeployment -n metal3 test1 -o json | jq '.spec.replicas=3' | kubectl apply -f-
for i in {1..1800};do
    replicas=$(ssh "-o LogLevel=quiet" -o "UserKnownHostsFile=/dev/null" -o PasswordAuthentication=no -o "StrictHostKeyChecking no" "${UPGRADE_USER}@${CP_NODE_IP}" -- kubectl get nodes | awk 'NR>1' | grep -v master | wc -l)
    if [[ "$replicas" == "3" ]]; then
        echo ''
        echo "Successfully scaled out worker nodes"
        break
    fi
    echo -n "*"
    sleep 5
    if [[ "${i}" -ge 1800 ]];then
        echo "Error: Scaling out of workers nodes took too long"
        exit 1
    fi
done

echo "Upgrading of (1M + 3W) using scaling in of workers has succeeded"

deprovision_cluster
wait_for_cluster_deprovisioned
