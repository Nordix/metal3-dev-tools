#!/bin/bash

export IMAGE_OS=${IMAGE_OS:-"Ubuntu"}
export UPGRADE_USER=${UPGRADE_USER:-"metal3"}
export KUBERNETES_VERSION="v1.18.0"
export KUBERNETES_BINARIES_VERSION="v1.18.0"
export METAL3_DEV_ENV_DIR=${METAL3_DEV_ENV_DIR:-"/home/${USER}/metal3-dev-env"}
export UPGRADED_K8S_VERSION_1="v1.18.1"
export UPGRADED_K8S_VERSION_2="v1.18.2"
export UPGRADED_BINARY_VERSION="v1.18.1"

function generate_metal3MachineTemplate() {
  NAME="${1}"
  CLUSTER_UID="${2}"
  Metal3MachineTemplate_OUTPUT_FILE="${3}"
  IMG_CHKSUM="${IMG_CHKSUM:-http://172.22.0.1/images/bionic-server-cloudimg-amd64.img.md5sum}"

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
    uid: "${CLUSTER_UID}"
spec:
  template:
    spec:
      hostSelector: {}
      image:
        checksum: "${IMG_CHKSUM}"
        url: https://cloud-images.ubuntu.com/bionic/current/bionic-server-cloudimg-amd64.img
">"${Metal3MachineTemplate_OUTPUT_FILE}"
}

function set_number_of_node_replicas() {
    export NUM_OF_NODE_REPLICAS="${1}"
}

function set_number_of_master_node_replicas() {
    export NUM_OF_MASTER_REPLICAS="${1}"
}

function set_number_of_worker_node_replicas() {
    export NUM_OF_WORKER_REPLICAS="${1}"
}

function provision_controlplane_node() {
    pushd "${METAL3_DEV_ENV_DIR}"
    echo "Provisioning a controlplane node...."
    bash ./scripts/v1alphaX/provision_cluster.sh
    bash ./scripts/v1alphaX/provision_controlplane.sh
    popd
}

function provision_worker_node() {
    pushd "${METAL3_DEV_ENV_DIR}"
    echo "Provisioning a worker node...."
    bash ./scripts/v1alphaX/provision_worker.sh
    popd
}

function deprovision_cluster() {
    pushd "${METAL3_DEV_ENV_DIR}"
    echo "Deprovisioning the cluster...."
    bash ./scripts/v1alphaX/deprovision_cluster.sh
    popd
}

function wait_for_ctrlplane_provisioning_start() {
    echo "Waiting for provisioning of controlplane node to start, number of replicas ${NUM_OF_NODE_REPLICAS}"
    if [ "${NUM_OF_NODE_REPLICAS}" -eq 1 ];then
        for i in {1..3600};do
        kubectl get bmh -n metal3 | awk 'NR>1'| grep -i 'provision'
        if [ $? -ne 0 ]; then
            echo -n "."
            sleep 1
            if [[ "${i}" -ge 3600 ]];then
                echo "Error: provisioning took too long to start"
                exit 1
            fi
            continue
        else
            echo -n "."
            break
        fi
        done
    else
        for i in {1..3600};do
            provisioned_bmhs=$(kubectl get bmh -n metal3 | awk 'NR>1'| grep -i 'provision' | wc -l)
            running_machines=$(kubectl get machines -n metal3 | awk 'NR>1'| grep 'Running' | wc -l)
            if [[ "${provisioned_bmhs}" -ne "${NUM_OF_NODE_REPLICAS}" && "${running_machines}" -ne "${NUM_OF_NODE_REPLICAS}" ]]; then
                echo -n ".:"
                sleep 2
                if [[ "${i}" -ge 3600 ]];then
                    echo "Error: provisioning took too long to start"
                    exit 1
                fi
            else
                break
            fi
        done
    fi
}

function wait_for_ctrlplane_provisioning_complete() {
    if [ "${NUM_OF_NODE_REPLICAS}" -eq 1 ];then
        NODE_NAME="${1}"
        NODE_IP="${2}"
        NODE_DESCRIPTION="${3}"
        echo "Waiting for provisioning of ${NODE_NAME} (${NODE_DESCRIPTION}) to complete"
        for i in {1..3600};do
        result=$(ssh -o "UserKnownHostsFile=/dev/null" -o PasswordAuthentication=no -o "StrictHostKeyChecking no" "${UPGRADE_USER}@${NODE_IP}" -- kubectl version 2>&1 /dev/null)
        if [[ "$?" == '0' ]]; then
            echo "Successfully provisioned a controlplane node"
                server_version=$(ssh -o "UserKnownHostsFile=/dev/null" -o "StrictHostKeyChecking no" "${UPGRADE_USER}@${NODE_IP}" -- kubectl version --short | grep -i server)
                client_version=$(ssh -o "UserKnownHostsFile=/dev/null" -o "StrictHostKeyChecking no" "${UPGRADE_USER}@${NODE_IP}" -- kubectl version --short | grep -i client)
                echo "${server_version}"
                echo "${server_version}"
            break
        else
            echo -n "-"
        fi
        sleep 1
        done
    else
	    NODE_LIST=( "${@}" )
        count=0
	    node_c=0
        echo "Waiting for provisioning of ${NUM_OF_NODE_REPLICAS} nodes: ${NODE_LIST[@]} to complete"
	    for node in ${NODE_LIST[@]}; do
            for i in {1..3600};do
            result=$(ssh -o "UserKnownHostsFile=/dev/null" -o PasswordAuthentication=no -o "StrictHostKeyChecking no" "${UPGRADE_USER}@${NODE_LIST[${node_c}+3]}" -- kubectl version 2>&1 /dev/null)
            if [[ "$?" == '0' ]]; then
                echo "Successfully provisioned a controlplane node"
                    server_version=$(ssh -o "UserKnownHostsFile=/dev/null" -o "StrictHostKeyChecking no" "${UPGRADE_USER}@${NODE_LIST[${node_c}+3]}" -- kubectl version --short | grep -i server)
                    client_version=$(ssh -o "UserKnownHostsFile=/dev/null" -o "StrictHostKeyChecking no" "${UPGRADE_USER}@${NODE_LIST[${node_c}+3]}" -- kubectl version --short | grep -i client)
                    echo "${server_version}"
                    echo "${server_version}"
                    count=$(($count+1))
                break # jump to outer loop

                if [ "${count}" -eq "${NUM_OF_NODE_REPLICAS}" ]; then
                    break 2 # ready, jump out
                fi
            else
                echo -n "-"
            fi
            sleep 1
            done
	    node_c=$(($node_c+1))
	    if [ "${node_c}" -eq "${NUM_OF_NODE_REPLICAS}" ]; then
                break # ready, jump out
            fi
        done
    fi
}

function wait_for_worker_provisioning_start() {
    echo "Waiting for provisioning of worker node to start, number of replicas ${NUM_OF_NODE_REPLICAS}"
    for i in {1..3600};do
    kubectl get bmh -n metal3 | awk 'NR>1'| grep -i 'provision' | grep 'worker'
    if [ $? -ne 0 ]; then
        echo -n "."
        sleep 1
        if [[ "${i}" -ge 3600 ]];then
            echo "Error: provisioning took too long to start"
            exit 1
        fi
        continue
    else
        echo -n "."
        break
    fi
    done
}

function wait_for_worker_provisioning_complete() {
    TOTAL_NBR_OF_MACHINES="${1}"
    NODE_NAME="${2}"
    NODE_IP="${3}"
    NODE_DESCRIPTION="${4}"
    echo "Waiting for provisioning of ${NODE_NAME} ${NODE_IP} (${NODE_DESCRIPTION}) to complete"
    for i in {1..3600};do
        running_machines=$(kubectl get machines -n metal3 | awk 'NR>1'| grep 'Running' | wc -l)
        if [[ "${running_machines}" -lt "${TOTAL_NBR_OF_MACHINES}" ]]; then
            echo -n "::"
            sleep 2
            if [[ "${i}" -ge 3600 ]];then
                echo "Error: provisioning took too long to start"
                exit 1
            fi
        else
            break
        fi
    done
}

function wait_for_ug_process_to_complete() {
    if [ "${NUM_OF_NODE_REPLICAS}" -eq 1 ];then
        ORIGINAL_NODE="${1}"
        echo "Waiting for upgrade process to complete"
        for i in {1..1800};do
        export NEW_NODE_NAME=$(kubectl get bmh -n metal3 | grep -v ${ORIGINAL_NODE} | grep 'prov' | grep 'control' | awk '{{print $1}}')
        if [ -n "${NEW_NODE_NAME}" ]; then
            export NEW_NODE_IP=$(sudo virsh net-dhcp-leases baremetal | grep "${NEW_NODE_NAME}"  | awk '{{print $5}}' | cut -f1 -d\/)
            break
        else
            # Process progress indicator
            echo -n "-"
            sleep 1
        fi
        done

        echo ''
        echo "New node name is ${NEW_NODE_NAME}"
        echo "New node IP is ${NEW_NODE_IP}"

        for i in {1..1800};do
        result=$(ssh -o "UserKnownHostsFile=/dev/null" -o PasswordAuthentication=no -o "StrictHostKeyChecking no" "${UPGRADE_USER}@${NEW_NODE_IP}" -- kubectl version 2>&1 /dev/null)
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
        echo -n "+."
        sleep 1
        done
    else
        ug_ongoing=1
        echo "Waiting for upgrade process to complete, ${NUM_OF_NODE_REPLICAS} nodes"
        for i in {1..1800};do
            ug_started=$(kubectl get bmh -n metal3 | awk 'NR>1' | grep 'provisioning' | wc -l)
            if [[ "${ug_started}" -gt "0" ]]; then
                break
            fi
        done
        while [ ${ug_ongoing} -eq 1 ]; do
            running_machines=$(kubectl get machines -n metal3 | awk 'NR>1'| grep 'Running' | wc -l)
            other_machines=$(kubectl get machines -n metal3 | awk 'NR>1'| grep -v 'Running' | wc -l)
                if [[ "${other_machines}" -eq "0" && "${running_machines}" -eq "${NUM_OF_NODE_REPLICAS}" ]]; then
                    provisioned_bmhs=$(kubectl get bmh -n metal3 | awk 'NR>1'| grep 'provisioned' | wc -l)
                    other_bmhs=$(kubectl get bmh -n metal3 | awk 'NR>1'| grep -v 'provisioned' | wc -l)
                    ready_bmhs=$(kubectl get bmh -n metal3 | awk 'NR>1'| grep 'ready' | wc -l)
                    if [[ "${other_bmhs}" -eq "1" && "${provisioned_bmhs}" -eq "${NUM_OF_NODE_REPLICAS}" && "${ready_bmhs}" -eq "1" ]]; then
                        echo ''
                        echo "Successfully upgraded the k8s version of ${NUM_OF_NODE_REPLICAS} control plane nodes"
                        ug_ongoing=0
                    fi
                fi
                # Upgrade progress indicator
                echo -n "-"
                sleep 2
        done
    fi
}

function wait_for_orig_node_deprovisioned() {
    if [ "${NUM_OF_NODE_REPLICAS}" -eq 1 ];then
    ORIGINAL_NODE="${1}"
    echo "Waiting for ${ORIGINAL_NODE} to be deprovisioned"
    for i in {1..3600};do
        ready_nodes=$(kubectl get bmh -n metal3 | grep ready | wc -l)
        if [[ "${ready_nodes}" == '3' ]]; then
            echo ''
            echo "Successfully deprovisioned ${ORIGINAL_NODE}"
            break
        else
            echo -n "-."
        fi
        sleep 1
        if [[ "${i}" -ge 3600 ]];then
                echo "Error: deprovisioning of original node too too long to complete"
                exit 1
        fi
        done
    else
       echo "Successfully deprovisioned all ${NUM_OF_NODE_REPLICAS} original nodes"
    fi
}

function wait_for_ctrlplane_to_scale_out {
    ORIGINAL_NODE="${1}"
    echo "Scaling out controlplane nodes"
    kubectl get kcp -n metal3 test1 -o json | jq '.spec.replicas=3' | kubectl apply -f-
    for i in {1..1800};do
        replicas=$(ssh "-o LogLevel=quiet" -o "UserKnownHostsFile=/dev/null" -o PasswordAuthentication=no -o "StrictHostKeyChecking no" "${UPGRADE_USER}@${ORIGINAL_NODE}" -- kubectl get nodes| grep master | wc -l)
        if [[ "$replicas" == "3" ]]; then
            echo ''
            echo "Successfully scaledout controlplane nodes"
            break
        fi
        # Upgrade progress indicator
        echo -n "+"
        sleep 5
        if [[ "${i}" -ge 1800 ]];then
            echo "Error: Scaling out of controlplane nodes took to long"
            exit 1
        fi        
    done
}

function wait_for_worker_to_scale_out {
    ORIGINAL_NODE="${1}"
    echo "Scaling out worker nodes"    
    kubectl get machinedeployment -n metal3 test1 -o json | jq '.spec.replicas=3' | kubectl apply -f-
    for i in {1..1800};do
        replicas=$(ssh "-o LogLevel=quiet" -o "UserKnownHostsFile=/dev/null" -o PasswordAuthentication=no -o "StrictHostKeyChecking no" "${UPGRADE_USER}@${ORIGINAL_NODE}" -- kubectl get nodes | awk 'NR>1' | grep -v master)
        if [[ "$replicas" == "3" ]]; then
            echo ''
            echo "Successfully scaledout worker nodes"
            break
        fi
        # Upgrade progress indicator
        echo -n "*"
        sleep 5
        if [[ "${i}" -ge 1800 ]];then
            echo "Error: Scaling out of workers nodes took to long"
            exit 1
        fi
    done
}

function wait_for_worker_to_scale_to {
    SCALE_TO="${1}"
    ORIGINAL_NODE="${2}"
    echo "Scaling worker nodes to ${SCALE_TO}"
    kubectl get machinedeployment -n metal3 test1 -o json | jq '.spec.replicas='"${SCALE_TO}"'' | kubectl apply -f-
    for i in {1..1800};do
        replicas=$(ssh "-o LogLevel=quiet" -o "UserKnownHostsFile=/dev/null" -o PasswordAuthentication=no -o "StrictHostKeyChecking no" "${UPGRADE_USER}@${ORIGINAL_NODE}" -- kubectl get nodes | awk 'NR>1' | grep -v master | wc -l)
        if [[ "$replicas" == "${SCALE_TO}" ]]; then
            echo ''
            echo "Successfully scaled worker nodes to ${SCALE_TO}"
            break
        fi
        # Scaling progress indicator
        echo -n "*"
        sleep 5
        if [[ "${i}" -ge 1800 ]];then
            echo "Error: Scaling of workers nodes took to long"
            exit 1
        fi
    done
}

function deploy_workload_on_workers {
echo "Deploy workloads on workers"
# Deploy workloads
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

echo "Waiting for workloads to be ready"
for i in {1..1800};do
    workload_replicas=$(kubectl get deployments workload-1-deployment -o json | jq '.status.readyReplicas')
    if [[ "$workload_replicas" == "10" ]]; then
        echo ''
        echo "Successfully deployed workloads across the cluster"
        break
    fi
    echo -n "*"
    sleep 5
    if [[ "${i}" -ge 1800 ]];then
        echo "Error: Workload failed to be deployed on the cluster"
        exit 1
    fi
done
}

function manage_node_taints {
    # Enable workload on masters
    ssh -o PasswordAuthentication=no -o "StrictHostKeyChecking no" "${UPGRADE_USER}@${1}" -- sudo apt-get install jq -y
    # kubectl get nodes -o json | jq ".items[]|{name:.metadata.name, taints:.spec.taints}"
    # untaint all masters (one workers also gets untainted, doesn't matter):
    ssh -o PasswordAuthentication=no -o "StrictHostKeyChecking no" "${UPGRADE_USER}@${1}" -- kubectl taint nodes --all node-role.kubernetes.io/master-
}

function wait_for_cluster_deprovisioned() {
    for i in {1..3600};do
        cluster_count=$(kubectl get clusters -n metal3  2>/dev/null | awk 'NR>1' | wc -l)
        if [[ "${cluster_count}" -eq "0" ]];then
            ready_bmhs=$(kubectl get bmh -n metal3 | awk 'NR>1'| grep 'ready' | wc -l)
            if [[ "${ready_bmhs}" -eq "4" ]];then
                echo "Successfully deprovisioned the cluster"
                exit 1
            fi
        else
            echo "Waiting for cluster to be deprovisioned"
        fi
    done
}