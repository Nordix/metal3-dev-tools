function generate_metal3MachineTemplate () {

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
    " > "${Metal3MachineTemplate_OUTPUT_FILE}"
}

function provision_controlpalne_node() {
    #pushd "/home/ubuntu/metal3-dev-env"
    echo "Provisioning a controlplane node...."
    bash /home/ubuntu/metal3-dev-env/scripts/v1alphaX/provision_cluster.sh
    bash /home/ubuntu/metal3-dev-env/scripts/v1alphaX/provision_controlplane.sh
    #popd
}

function provision_worker_node() {
    #pushd "/home/ubuntu/metal3-dev-env"
    echo "Provisioning a worker node...."
    bash /home/ubuntu/metal3-dev-env/scripts/v1alphaX/provision_worker.sh
    #popd
}

function create_metal3_dev_env() {
    pushd "/home/ubuntu/metal3-dev-env"
    export DEFAULT_HOSTS_MEMORY=4096
    export IMAGE_OS=Ubuntu
    export CAPI_VERSION=v1alpha3
    export NUM_NODES=4
    export EPHEMERAL_CLUSTER=minikube
    make clean
    make
    popd
}