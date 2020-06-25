#!/bin/bash

set -x

source ../common.sh

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
cat <<EOF >clusterctl-settings.json
{
  "providers": [ "cluster-api", "bootstrap-kubeadm", "control-plane-kubeadm"]
}
EOF

cat <<EOF >/home/$USER/.cluster-api/clusterctl.yaml
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
EOF
mv clusterctl-settings-metal3.json "${CAPM3_REPO}/clusterctl-settings.json"

# Install initial version
clusterctl_init_command=$(cmd/clusterctl/hack/local-overrides.py | grep "clusterctl init")
echo ${clusterctl_init_command} --target-namespace t1 --watching-namespace t1 | bash

# Create a new version
cp -r /home/$USER/.cluster-api/overrides/cluster-api/v0.3.0 /home/$USER/.cluster-api/overrides/cluster-api/v0.3.1
cp -r /home/$USER/.cluster-api/overrides/bootstrap-kubeadm/v0.3.0 /home/$USER/.cluster-api/overrides/bootstrap-kubeadm/v0.3.2
cp -r /home/$USER/.cluster-api/overrides/control-plane-kubeadm/v0.3.0 /home/$USER/.cluster-api/overrides/control-plane-kubeadm/v0.3.3

popd
# Make changes on CRDs
sed -i 's/\bma\b/ma2020/g' /home/$USER/.cluster-api/overrides/cluster-api/v0.3.1/core-components.yaml
sed -i 's/singular: kubeadmconfig/singular: kubeadmconfig2020/' /home/$USER/.cluster-api/overrides/bootstrap-kubeadm/v0.3.2/bootstrap-components.yaml
sed -i 's/kcp/kcp2020/' /home/$USER/.cluster-api/overrides/control-plane-kubeadm/v0.3.3/control-plane-components.yaml

# do upgrade
clusterctl upgrade plan | grep "upgrade apply" | xargs | xargs clusterctl

# Verify upgrade
upgraded_controllers_count=$(kubectl api-resources | grep 2020 | wc -l)
upgraded_bootstrap_crd_count=$(kubectl get crds kubeadmconfigs.bootstrap.cluster.x-k8s.io -o json | jq '.spec.names.singular' | wc -l)

if [ $upgraded_controllers_count -ne 2 ]; then
  echo "Failed to upgrade cluster-api and controlplane components"
  log_test_result ${0} "fail"
  exit 1
fi
if [ $upgraded_bootstrap_crd_count -ne 1 ]; then
  echo "Failed to upgrade control-plane-kubeadm components"
  log_test_result ${0} "fail"
  exit 1
fi

echo "Successfully upgraded cluster-api, controlplane and controlplane-kubeadm components"
log_test_result ${0} "pass"
set +x

# status = passed | if done on a new cluster