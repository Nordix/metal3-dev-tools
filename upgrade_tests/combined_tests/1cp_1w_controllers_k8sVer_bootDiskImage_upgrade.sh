#!/bin/bash


set -x

source ../common.sh

echo '' > ~/.ssh/known_hosts

start_logging "${1}"

# MAX_CONTROLLER_VERSION should be one of the available versions
export MAX_CONTROLLER_VERSION="${MAX_CONTROLLER_VERSION:-v0.3.9}"

set_number_of_master_node_replicas 1
set_number_of_worker_node_replicas 1

provision_controlplane_node
wait_for_ctrlplane_provisioning_start

CP_NODE=$(kubectl get bmh -n metal3 | grep control | grep -v ready | cut -f1 -d' ')
echo "BareMetalHost ${CP_NODE} is in provisioning or provisioned state"
CP_NODE_IP=$(sudo virsh net-dhcp-leases baremetal | grep "${CP_NODE}"  | awk '{{print $5}}' | cut -f1 -d\/)

wait_for_ctrlplane_provisioning_complete "${CP_NODE}" "${CP_NODE_IP}" "controlplane node"



CAPM3_REPO="/home/$USER/go/src/github.com/metal3-io/cluster-api-provider-metal3"

# Delete old environment and create new one
rm -rf /home/$USER/.cluster-api
mkdir /home/$USER/.cluster-api
rm -rf /tmp/cluster-api-clone
mkdir /tmp/cluster-api-clone
sudo rm /usr/local/bin/clusterctl

# Build clusterctl 
git clone https://github.com/kubernetes-sigs/cluster-api.git /tmp/cluster-api-clone
pushd /tmp/cluster-api-clone 
make clusterctl
sudo mv bin/clusterctl /usr/local/bin

# # create a new k8s cluster using kind
#kind delete cluster --name upgrade_CAPI_with_clusterctl
#kind create cluster --name upgrade_CAPI_with_clusterctl

# Generate v0.3.0 as initial verion
/tmp/cluster-api-clone/cmd/clusterctl/hack/local-overrides.py

# create required configuration files
cat << EOF > clusterctl-settings.json
{
  "providers": [ "cluster-api", "bootstrap-kubeadm", "control-plane-kubeadm",  "infrastructure-metal3"],
  "provider_repos": ["${CAPM3_REPO}"]
}
EOF

cat << EOF > clusterctl-settings-metal3.json
{
  "name": "infrastructure-metal3",
  "config": {
    "componentsFile": "infrastructure-components.yaml",
    "nextVersion": "v0.3.0"
  }
}
EOF


mv clusterctl-settings-metal3.json "${CAPM3_REPO}/clusterctl-settings.json"

# Install initial version
clusterctl_init_command=$(cmd/clusterctl/hack/local-overrides.py | grep "clusterctl init")
echo ${clusterctl_init_command} | bash 

# Create a new version
cp -r /home/$USER/.cluster-api/overrides/cluster-api/v0.3.0 /home/$USER/.cluster-api/overrides/cluster-api/${MAX_CONTROLLER_VERSION}
cp -r /home/$USER/.cluster-api/overrides/bootstrap-kubeadm/v0.3.0 /home/$USER/.cluster-api/overrides/bootstrap-kubeadm/${MAX_CONTROLLER_VERSION}
cp -r /home/$USER/.cluster-api/overrides/control-plane-kubeadm/v0.3.0 /home/$USER/.cluster-api/overrides/control-plane-kubeadm/${MAX_CONTROLLER_VERSION}
cp -r /home/$USER/.cluster-api/overrides/infrastructure-metal3/v0.3.0 /home/$USER/.cluster-api/overrides/infrastructure-metal3/${MAX_CONTROLLER_VERSION}
popd

# Make changes on CRD
sed -i 's/\bma\b/ma2020/g' /home/$USER/.cluster-api/overrides/cluster-api/${MAX_CONTROLLER_VERSION}/core-components.yaml
sed -i 's/kcp/kcp2020/' /home/$USER/.cluster-api/overrides/control-plane-kubeadm/${MAX_CONTROLLER_VERSION}/control-plane-components.yaml
sed -i 's/singular: kubeadmconfig/singular: kubeadmconfig2020/' /home/$USER/.cluster-api/overrides/bootstrap-kubeadm/${MAX_CONTROLLER_VERSION}/bootstrap-components.yaml
sed -i 's/\bbmh\b/bmh2020/' /home/$USER/.cluster-api/overrides/infrastructure-metal3/${MAX_CONTROLLER_VERSION}/infrastructure-components.yaml
sed -i 's/\bm3c\b/m3c2020/g' /home/$USER/.cluster-api/overrides/infrastructure-metal3/${MAX_CONTROLLER_VERSION}/infrastructure-components.yaml

# Include new components' version into use.
cat << EOF > /home/$USER/.cluster-api/clusterctl.yaml
providers:
  - name: cluster-api
    url: /home/ubuntu/.cluster-api/overrides/cluster-api/${MAX_CONTROLLER_VERSION}/core-components.yaml
    type: CoreProvider
  - name: kubeadm
    url: /home/ubuntu/.cluster-api/overrides/bootstrap-kubeadm/${MAX_CONTROLLER_VERSION}/bootstrap-components.yaml
    type: BootstrapProvider
  - name: kubeadm
    url: /home/ubuntu/.cluster-api/overrides/control-plane-kubeadm/${MAX_CONTROLLER_VERSION}/control-plane-components.yaml
    type: ControlPlaneProvider
  - name: metal3
    url: /home/ubuntu/.cluster-api/overrides/infrastructure-metal3/${MAX_CONTROLLER_VERSION}/infrastructure-components.yaml
    type: InfrastructureProvider
images:
  cert-manager:
    repository: quay.io/jetstack
    tag: v0.11.1
EOF

# show upgrade plan
clusterctl upgrade plan

# do upgrade
clusterctl upgrade plan | grep "upgrade apply" | xargs | xargs clusterctl 

# ------------------------------- Upgrade k8s version and boot disk image ------------------------- #
# We starting upgrading both while the controlplane components are being upgraded
# 

FROM_VERSION=$(kubectl get kcp -n metal3 -oyaml | grep "version: v1" | cut -f2 -d':' | awk '{$1=$1;print}')

if [[ "${FROM_VERSION}" < "${UPGRADED_K8S_VERSION_2}" ]]; then
  TO_VERSION="${UPGRADED_K8S_VERSION_2}"
elif [[ "${FROM_VERSION}" > "${KUBERNETES_VERSION}" ]]; then
  TO_VERSION="${KUBERNETES_VERSION}"
else
  exit 0
fi

M3_MACHINE_TEMPLATE_NAME=$(kubectl get Metal3MachineTemplate -n metal3 -oyaml | grep "name: " | grep controlplane | cut -f2 -d':' | awk '{$1=$1;print}')

Metal3MachineTemplate_OUTPUT_FILE="/tmp/new_image.yaml"
CLUSTER_UID=$(kubectl get clusters -n metal3 ${CLUSTER_NAME} -o json |jq '.metadata.uid' | cut -f2 -d\")
IMG_CHKSUM=$(curl -s https://cloud-images.ubuntu.com/bionic/current/MD5SUMS | grep bionic-server-cloudimg-amd64.img | cut -f1 -d' ')
generate_metal3MachineTemplate new-controlplane-image "${CLUSTER_UID}" "${Metal3MachineTemplate_OUTPUT_FILE}" "${IMG_CHKSUM}"
kubectl apply -f "${Metal3MachineTemplate_OUTPUT_FILE}"

echo "Upgrading a control plane node image and k8s version from ${FROM_VERSION} to ${TO_VERSION} in cluster ${CLUSTER_NAME}"
# replace node image and k8s version in kcp yaml:
kubectl get kcp -n metal3 -oyaml | sed "s/version: ${FROM_VERSION}/version: ${TO_VERSION}/" | sed "s/name: ${M3_MACHINE_TEMPLATE_NAME}/name: new-controlplane-image/" | kubectl replace -f -

wait_for_ug_process_to_complete

echo "Upgrading a control plane node image and k8s version from ${FROM_VERSION} to ${TO_VERSION} in cluster ${CLUSTER_NAME} has succeeded"

# -------------------------------- End of upgrading k8s version and boot disk image
# Verify upgrade
upgraded_infra_controllers_count=$(kubectl api-resources | grep m3c2020 | wc -l) # "Failed to upgrad infrastructure components"
if [ $upgraded_infra_controllers_count -ne 1 ]
then
  echo "Failed to upgrad infrastructure components"
  exit 1
fi
# ToDo: Enable me
# upgraded_bmo_controller_count=$(kubectl api-resources | grep bmh2020 | wc -l) #  bmo Failed to upgrad baremetal operator using clusterctl"
# if [ $upgraded_bmo_controller_count -ne 1 ]
# then
#   echo "Failed to upgrad baremetal operator using clusterctl"
#   exit 1
# fi
upgraded_capi_cp_controllers_count=$(kubectl api-resources | egrep "kcp2020|ma2020" | wc -l) #Failed to upgrade cluster-api and controlplane components
if [ $upgraded_capi_cp_controllers_count -ne 2 ]
then
  echo "Failed to upgrade cluster-api and controlplane components"
  exit 1
fi
upgraded_bootstrap_crd_count=$(kubectl get crds kubeadmconfigs.bootstrap.cluster.x-k8s.io -o json | jq '.spec.names.singular' | wc -l) #"Failed to upgrade control-plane-kubeadm components"
if [ $upgraded_bootstrap_crd_count -ne 1 ]
then
  echo "Failed to upgrade control-plane-kubeadm components"
  exit 1
fi

# Verify image upgrade
new_image_count=$(kubectl get pods -n cert-manager -o yaml  | grep 'image:' | cut -f3 -d: | sort -u | grep v0.11.1 | wc -l)
# ToDo: new_image_count is should be 1
if [ $new_image_count -ne 0 ] # 0 is temporary. It should be set to 1.
then
  echo "Failed to upgrade cert-manager using clusterctl"
  exit 1
fi

echo "Successfully upgraded CAPI, CAPM3, BMO and cert-manager controlers" # This needs to be updated as more components are added
echo "successfully run ${0}" >> /tmp/$(date +"%Y.%m.%d_upgrade.combined.result.txt")

set +x
 
deprovision_cluster
wait_for_cluster_deprovisioned

