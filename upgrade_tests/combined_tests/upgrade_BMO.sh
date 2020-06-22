#!/bin/bash

# This needs to run in an environment where the following variables are set.
# DEPLOY_KERNEL_URL
# DEPLOY_RAMDISK_URL
# IRONIC_URL
# IRONIC_INSPECTOR_URL

set -x

start_logging "${1}"

CAPM3_REPO="/home/$USER/go/src/github.com/metal3-io/cluster-api-provider-metal3"

# Delete old environment and create new one
rm -rf /home/$USER/.cluster-api
mkdir /home/$USER/.cluster-api
rm -rf /tmp/cluster-api-clone
mkdir /tmp/cluster-api-clone
rm /usr/local/bin/clusterctl

# Build clusterctl 
git clone https://github.com/kubernetes-sigs/cluster-api.git /tmp/cluster-api-clone
pushd /tmp/cluster-api-clone 
make clusterctl
sudo mv bin/clusterctl /usr/local/bin

# create a new k8s cluster using kind
kind delete cluster --name upgrade_CAPI_with_clusterctl
kind create cluster --name upgrade_CAPI_with_clusterctl

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

cat << EOF > /home/$USER/.cluster-api/clusterctl.yaml
providers:
  - name: cluster-api
    url: /home/$USER/.cluster-api/overrides/cluster-api/v0.3.1/core-components.yaml
    type: CoreProvider
  - name: kubeadm
    url: /home/$USER/.cluster-api/overrides/bootstrap-kubeadm/v0.3.2/bootstrap-components.yaml
    type: BootstrapProvider
  - name: kubeadm
    url: /home/$USER/.cluster-api/overrides/control-plane-kubeadm/v0.3.3/control-plane-components.yaml
    type: ControlPlaneProvider
  - name: metal3
    url: /home/$USER/.cluster-api/overrides/infrastructure-metal3/v0.3.5/infrastructure-components.yaml
    type: InfrastructureProvider
EOF
mv clusterctl-settings-metal3.json "${CAPM3_REPO}/clusterctl-settings.json"

# Install initial version
clusterctl_init_command=$(cmd/clusterctl/hack/local-overrides.py | grep "clusterctl init")
echo ${clusterctl_init_command} --target-namespace t1 --watching-namespace t1 | bash 

# Create a new version
cp -r /home/$USER/.cluster-api/overrides/infrastructure-metal3/v0.3.0 /home/$USER/.cluster-api/overrides/infrastructure-metal3/v0.3.5

popd

# Make changes on CRD
sed -i 's/\bbmh\b/bmh2020/' /home/$USER/.cluster-api/overrides/infrastructure-metal3/v0.3.5/infrastructure-components.yaml

# show upgrade plan
clusterctl upgrade plan

# do upgrade
clusterctl upgrade plan | grep "upgrade apply" | xargs | xargs clusterctl 

# Verify upgrade
upgraded_controllers_count=$(kubectl api-resources | grep bmh2020 | wc -l)

if [ $upgraded_controllers_count -ne 1 ]
then
  echo "Failed to upgrad baremetal operator using clusterctl"
  exit 1
fi

echo "Successfully upgraded baremetal operator using clusterctl"
echo "successfully run ${1}" >> /tmp/$(date +"%Y.%m.%d_upgrade.bmo.result.txt")
set +x
