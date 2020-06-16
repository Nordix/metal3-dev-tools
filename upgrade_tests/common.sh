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
  IMG_CHKSUM="${4:-http://172.22.0.1/images/bionic-server-cloudimg-amd64.img.md5sum}"

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

function wait_for_cluster_deprovisioned() {
    echo "Waiting for cluster to be deprovisioned"
    for i in {1..3600};do
        cluster_count=$(kubectl get clusters -n metal3  2>/dev/null | awk 'NR>1' | wc -l)
        if [[ "${cluster_count}" -eq "0" ]];then
            ready_bmhs=$(kubectl get bmh -n metal3 | awk 'NR>1'| grep 'ready' | wc -l)
            if [[ "${ready_bmhs}" -eq "4" ]];then
                echo ''
                echo "Successfully deprovisioned the cluster"
                exit 0
            fi
        else
            echo -n "-"
        fi
    done
}

function wait_for_ctrlplane_provisioning_start() {
    echo "Waiting for provisioning of controlplane node to start, number of replicas ${NUM_OF_MASTER_REPLICAS}"
    if [ "${NUM_OF_MASTER_REPLICAS}" -eq 1 ];then
        for i in {1..3600};do
        kubectl get bmh -n metal3 | awk 'NR>1'| grep -i 'provision'
        if [ $? -ne 0 ]; then
            echo -n "."
            sleep 1
            if [[ "${i}" -ge 3600 ]];then
                echo "Error: provisioning took too long to start"
                deprovision_cluster
                wait_for_cluster_deprovisioned
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
            if [[ "${provisioned_bmhs}" -ne "${NUM_OF_MASTER_REPLICAS}" && "${running_machines}" -ne "${NUM_OF_MASTER_REPLICAS}" ]]; then
                echo -n ".:"
                sleep 2
                if [[ "${i}" -ge 3600 ]];then
                    echo "Error: provisioning took too long to start"
                    deprovision_cluster
                    wait_for_cluster_deprovisioned
                    exit 1
                fi
            else
                break
            fi
        done
    fi
}

function wait_for_ctrlplane_provisioning_complete() {
    if [ "${NUM_OF_MASTER_REPLICAS}" -eq 1 ];then
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
        echo "Waiting for provisioning of ${NUM_OF_MASTER_REPLICAS} nodes: ${NODE_LIST[@]} to complete"
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

                if [ "${count}" -eq "${NUM_OF_MASTER_REPLICAS}" ]; then
                    break 2 # ready, jump out
                fi
            else
                echo -n "-"
            fi
            sleep 1
            done
	    node_c=$(($node_c+1))
	    if [ "${node_c}" -eq "${NUM_OF_MASTER_REPLICAS}" ]; then
                break # ready, jump out
            fi
        done
    fi
}

function wait_for_worker_provisioning_start() {
    echo "Waiting for provisioning of worker node to start, number of replicas ${NUM_OF_WORKER_REPLICAS}"
    for i in {1..3600};do
    kubectl get bmh -n metal3 | awk 'NR>1'| grep -i 'provision' | grep 'worker'
    if [ $? -ne 0 ]; then
        echo -n "."
        sleep 1
        if [[ "${i}" -ge 3600 ]];then
            echo "Error: provisioning took too long to start"
            deprovision_cluster
            wait_for_cluster_deprovisioned
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
    TOTAL_NBR_OF_MACHINES_IN_CLUSTER="${1}"
    NODE_NAME="${2}"
    NODE_IP="${3}"
    NODE_DESCRIPTION="${4}"
    echo "Waiting for provisioning of ${NODE_NAME} ${NODE_IP} (${NODE_DESCRIPTION}) to complete"
    for i in {1..3600};do
        running_machines=$(kubectl get machines -n metal3 | awk 'NR>1'| grep 'Running' | wc -l)
        if [[ "${running_machines}" -lt "${TOTAL_NBR_OF_MACHINES_IN_CLUSTER}" ]]; then
            echo -n "::"
            sleep 2
            if [[ "${i}" -ge 3600 ]];then
                echo "Error: provisioning took too long to start"
                deprovision_cluster
                wait_for_cluster_deprovisioned
                exit 1
            fi
        else
            break
        fi
    done
}

function wait_for_ug_process_to_complete() {
    total_nbr_of_bmhs=$(kubectl get bmh -n metal3 | awk 'NR>1' | wc -l)
    # expected number of non-provisioned bmhs
    exp_count=$((${total_nbr_of_bmhs}-${NUM_OF_MASTER_REPLICAS}))
    ug_ongoing=1
    node_c=0

    echo "Waiting for upgrade process to complete, ${NUM_OF_MASTER_REPLICAS} nodes"
    for i in {1..1800};do
        ug_started=$(kubectl get bmh -n metal3 | awk 'NR>1' | grep 'provisioning' | wc -l)
        if [[ "${ug_started}" -gt "0" ]]; then
            break
        fi
    done
    while [ ${ug_ongoing} -eq 1 ]; do
        running_machines=$(kubectl get machines -n metal3 | awk 'NR>1'| grep 'Running' | wc -l)
        other_machines=$(kubectl get machines -n metal3 | awk 'NR>1'| grep -v 'Running' | wc -l)
            if [[ "${other_machines}" -eq "0" && "${running_machines}" -eq "${NUM_OF_MASTER_REPLICAS}" ]]; then
                provisioned_bmhs=$(kubectl get bmh -n metal3 | awk 'NR>1'| grep 'provisioned' | wc -l)
                other_bmhs=$(kubectl get bmh -n metal3 | awk 'NR>1'| grep -v 'provisioned' | wc -l)
                ready_bmhs=$(kubectl get bmh -n metal3 | awk 'NR>1'| grep 'ready' | wc -l)
                if [[ "${other_bmhs}" -eq "${exp_count}" && "${provisioned_bmhs}" -eq "${NUM_OF_MASTER_REPLICAS}" && "${ready_bmhs}" -eq "${exp_count}" ]]; then
                    echo ''
                    echo "Successfully upgraded the k8s version of ${NUM_OF_MASTER_REPLICAS} control plane nodes"
                    ug_ongoing=0
                fi
            fi
            # Upgrade progress indicator
            echo -n "-"
            sleep 2

            node_c=$(($node_c+1))
            if [[ "${node_c}" -eq "7200" ]]; then
                ug_ongoing=2
                echo "Upgrade failed, resource(s) are hanging."
                deprovision_cluster
                wait_for_cluster_deprovisioned
                exit 1
            fi
    done

    # Upgrade succeeded, test connectivity
    if [[ "${ug_ongoing}" -eq "0" ]]; then
        # pick the first node and test ssh on it
        new_node_name=$(kubectl get bmh -n metal3 | awk 'NR>1' | grep 'prov' | grep 'control' | awk '{{print $1}}' | head -1)
        if [ -n "${NEW_NODE_NAME}" ]; then
            new_node_ip=$(sudo virsh net-dhcp-leases baremetal | grep "${new_node_name}" | awk '{{print $5}}' | cut -f1 -d\/)
            for i in {1..1800};do
                result=$(ssh -o "UserKnownHostsFile=/dev/null" -o PasswordAuthentication=no -o "StrictHostKeyChecking no" "${UPGRADE_USER}@${new_node_ip}" -- kubectl version 2>&1 /dev/null)
                if [[ "$?" == "0" ]]; then
                    echo ''
                    echo "Successfully connected over ssh to an upgraded control plane node"
                    server_version=$(ssh -o "UserKnownHostsFile=/dev/null" -o "StrictHostKeyChecking no" "${UPGRADE_USER}@${new_node_ip}" -- kubectl version --short | grep Server)
                    client_version=$(ssh -o "UserKnownHostsFile=/dev/null" -o "StrictHostKeyChecking no" "${UPGRADE_USER}@${new_node_ip}" -- kubectl version --short | grep Client)
                    echo "${server_version}"
                    echo "${server_version}"
                    break
                fi
                # Upgrade progress indicator
                echo -n ".ssh."
                sleep 1
            done
        else
            echo "Connectivity test after upgrade skipped"
        fi
    fi
}

function wait_for_worker_ug_process_to_complete() {
    CP_NODE_IP="${1}"
    NEW_M3M_TEMPL_NAME="${2}"
    echo "Node image upgrade started for ${NUM_OF_WORKER_REPLICAS} worker nodes"
    for i in {1..3600};do
        count=$(kubectl get bmh -n metal3 | awk 'NR>1'| grep -i ${NEW_M3M_TEMPL_NAME} | wc -l)
        if [[ "${count}" -lt "${NUM_OF_WORKER_REPLICAS}" ]]; then
            echo -n "-"	  
            if [[ "${i}" -ge 3600 ]];then
                echo "Error: Upgrade on some or all worker nodes did not start in time"
                deprovision_cluster
                wait_for_cluster_deprovisioned
                exit 1
            fi
            sleep 5
            continue
        else
            echo "Upgrade of all worker nodes has finished"
            break
        fi
    done

    # Verify that all upgraded worker nodes have joined the cluster.
    echo "Waiting for ${NUM_OF_WORKER_REPLICAS} upgraded worker nodes to join the cluster"
    for i in {1..3600};do
        echo -n "*"
        replicas=$(ssh "-o LogLevel=quiet" -o "UserKnownHostsFile=/dev/null" -o PasswordAuthentication=no -o "StrictHostKeyChecking no" "${UPGRADE_USER}@${CP_NODE_IP}" -- kubectl get nodes| grep -v master | wc -l)
        if [[ "${replicas}" == "${NUM_OF_WORKER_REPLICAS}" ]]; then
            echo ''
            echo "Upgraded worker nodes have joined the cluster"
            break
        fi
        sleep 5
        if [[ "${i}" -ge 3600 ]];then
            echo "Error: Upgraded worker node did not join the cluster in time"
            deprovision_cluster
            wait_for_cluster_deprovisioned
            exit 1
        fi
    done
    echo "Successfully upgraded multiple workers"
}

function wait_for_orig_node_deprovisioned() {
    node_type="${1:-master}"
    expected_ready_nodes="${2:-3}"
    nbr_replicas=0
    if [[ "${node_type}" == "master" ]]; then
        nbr_replicas="${NUM_OF_MASTER_REPLICAS}"
    elif [[ "${node_type}" == "worker" ]]; then
        nbr_replicas="${NUM_OF_WORKER_REPLICAS}"   
    else
        nbr_replicas=$(("${NUM_OF_MASTER_REPLICAS}"+"${NUM_OF_WORKER_REPLICAS}"))
    fi
    if [ "${nbr_replicas}" -eq 1 ];then
        ORIGINAL_NODE="${1}"
        echo "Waiting for ${ORIGINAL_NODE} ("${node_type}") to be deprovisioned"
        for i in {1..3600};do
            ready_nodes=$(kubectl get bmh -n metal3 | grep ready | wc -l)
            if [[ "${ready_nodes}" == "${expected_ready_nodes}" ]]; then
                echo ''
                echo "Successfully deprovisioned ${ORIGINAL_NODE}"
                break
            else
                echo -n "-."
            fi
            sleep 1
            if [[ "${i}" -ge 3600 ]];then
                echo "Error: deprovisioning of original node too too long to complete"
                deprovision_cluster
                wait_for_cluster_deprovisioned
                exit 1
            fi
        done
    else
       echo "Successfully deprovisioned all ${nbr_replicas} original nodes"
    fi
}

function wait_for_node_to_scale_to {
    scale_to="${1}"
    cp_node_ip="${2}"
    node_type="${3:-master}"
    replicas=0

    echo "Scaling ${node_type} nodes to ${scale_to}"
    if [[ "${node_type}" == "master" ]]; then
        kubectl get kcp -n metal3 test1 -o json | jq '.spec.replicas='"${scale_to}"'' | kubectl apply -f-
    else
        kubectl get machinedeployment -n metal3 test1 -o json | jq '.spec.replicas='"${scale_to}"'' | kubectl apply -f-
    fi

    for i in {1..1800};do
        if [[ "${node_type}" == "master" ]]; then
            replicas=$(ssh "-o LogLevel=quiet" -o "UserKnownHostsFile=/dev/null" -o PasswordAuthentication=no -o "StrictHostKeyChecking no" "${UPGRADE_USER}@${cp_node_ip}" -- kubectl get nodes| grep master | wc -l)
        else
            replicas=$(ssh "-o LogLevel=quiet" -o "UserKnownHostsFile=/dev/null" -o PasswordAuthentication=no -o "StrictHostKeyChecking no" "${UPGRADE_USER}@${cp_node_ip}" -- kubectl get nodes | awk 'NR>1' | grep -v master | wc -l)
        fi

        if [[ "$replicas" == "${scale_to}" ]]; then
            echo ''
            echo "Successfully scaled ${node_type} nodes to ${scale_to}"
            break
        fi
        # Scaling progress indicator
        echo -n "*"
        sleep 5
        if [[ "${i}" -ge 1800 ]];then
            echo "Error: Scaling of ${node_type} nodes took to long"
            deprovision_cluster
            wait_for_cluster_deprovisioned
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
        deprovision_cluster
        wait_for_cluster_deprovisioned
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

function start_logging() {
	log_file="${1}"
	log_file+=$(date +".%Y.%m.%d-%T-upgrade.result.txt")

	echo "${log_file}"

	exec > >(tee /tmp/${log_file})
}
