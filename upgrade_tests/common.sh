#!/bin/bash

export IMAGE_OS=${IMAGE_OS:-"Ubuntu"}
export UPGRADE_USER=${UPGRADE_USER:-"metal3"}
export KUBERNETES_VERSION="v1.18.0"
export KUBERNETES_BINARIES_VERSION="v1.18.0"​
export METAL3_DEV_ENV_DIR=${METAL3_DEV_ENV_DIR:-"/home/${USER}/metal3-dev-env"}
export UPGRADED_K8S_VERSION_1="v1.18.1"
export UPGRADED_K8S_VERSION_2="v1.18.2"
export UPGRADED_BINARY_VERSION="v1.18.1"

function generate_metal3MachineTemplate() {
NAME="${1}"
CLUSTER_UID="${2}"
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
    uid: "${CLUSTER_UID}"
spec:
  template:
    spec:
      hostSelector: {}
      image:
        checksum: http://172.22.0.1/images/bionic-server-cloudimg-amd64.img.md5sum
        url: https://cloud-images.ubuntu.com/bionic/current/bionic-server-cloudimg-amd64.img
">"${Metal3MachineTemplate_OUTPUT_FILE}"
}
​
function provision_controlplane_node() {
    pushd "${METAL3_DEV_ENV_DIR}"
    echo "Provisioning a controlplane node...."
    bash ./scripts/v1alphaX/provision_cluster.sh
    bash ./scripts/v1alphaX/provision_controlplane.sh
    popd
}
​
function provision_worker_node() {
    pushd "${METAL3_DEV_ENV_DIR}"
    echo "Provisioning a worker node...."
    bash ./scripts/v1alphaX/provision_worker.sh
    popd
}

function wait_for_ctrlplane_provisioning_start() {
    echo "Waiting for provisioning of controlplane node to start"
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
}

function wait_for_ctrlplane_provisioning_complete() {
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
}

function wait_for_ug_process_to_complete() {
    ORIGINAL_NODE="${1}"
    echo "Waiting for upgrade process to complete"
    for i in {1..1800};do
    export NEW_NODE_NAME=$(kubectl get bmh -n metal3 | grep -v ${ORIGINAL_NODE} | grep 'prov' | grep 'control' | awk '{{print $1}}')
    if [ -n "${NEW_NODE_NAME}" ]; then
        export NEW_NODE_IP=$(virsh net-dhcp-leases baremetal | grep "${NEW_NODE_NAME}"  | awk '{{print $5}}' | cut -f1 -d\/)
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
}

function wait_for_orig_node_deprovisioned() {
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
}
