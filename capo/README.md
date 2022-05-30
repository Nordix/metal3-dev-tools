# CAPI Openstack Provider dev setup

## Requirements

* Install go version >= 1.16
* Install `kind` and `tilt`
* Install `yq`

```bash
YQ_VERSION="4.23.1"
wget "https://github.com/mikefarah/yq/releases/download/${YQ_VERSION}/yq_linux_amd64"
chmod a+x yq_linux_amd64
sudo mv yq_linux_amd64 /usr/local/bin/yq
```

* Clone the `cluster-api` and `cluster-api-provider-openstack` repos adjacent
  to this repository
* Fetch `cacert.pem` to /tmp/cacert.pem from the password Vault for auth to the
  OpenStack installation
* Copy the openstack.rc file for the project you want to use for CAPO
  deployment to /tmp/openstackrc

Note:
Changes on the CAPI side could break the CAPO setup. In order to avoid that, we are fixing the CAPI version to a known working one, `v1.0.5`. If more recent version is know, please update this document and `configure.sh` script.

Now you need to set up a keypair for SSH access to the machines.

```bash
# Source openstackrc
. /tmp/openstackrc
# Create the keypair in OpenStack and save the private key locally
openstack keypair create capo-key > ~/.ssh/capo-key
# Generate the pubkey from the private key
ssh-keygen -f ~/.ssh/capo-key -y > ~/.ssh/capo-key.pub
# Export the environment variables used in the dev environment to specify the use of your key
export OPENSTACK_SSH_AUTHORIZED_KEY=~/.ssh/capo-key.pub
export OPENSTACK_SSH_KEY_NAME=capo-key
```

Then:

* Run `make` in one tab to bring up a CAPI/CAPO master Kubernetes cluster
  managed by tilt
* Make changes to `cluster-api-provider-openstack`
* Run `make provision` to deploy a 2 node cluster on OpenStack and test your changes.
  Note that you can specify the name of the cluster like this: `make CLUSTER_NAME=${USER}-capo-test provision`.
  This avoids name collisions and makes it easier to tell who created the resources in Openstack.

## Cleanup

The "normal" way to clean up openstack resources created by CAPO is to delete all Cluster objects you created.
The default namespace is `default` and the default cluster name is `basic-1`.
If you followed the suggestion to change the name of the cluster it would be whatever you chose, e.g. `${USER}-capo-test`.

```bash
# kubectl -n <namespace> delete cluster <name-of-cluster>
kubectl -n default delete cluster basic-1
kubectl -n default delete cluster "${USER}-capo-test"
```

Clean up the local resources with

```bash
make clean
```

Finally, there could be still some resources left in openstack due to bugs in CAPO (especially if you are working on itactively).
Clean these up by using the `clean-os-resources.sh` script.

## Devstack setup

In order to add more features, such as trunking, we need to create an Openstack instance using devstack.
Luckily there is a script in the CAPO repository under `hack/ci/create_devstack.sh` that can be used to set this up.

Prerequisites: You will need the openstack python client installed for this.
As of writing, the version used in Ubuntu 20.04 is too old (5.5).
To fix this you can use a python virtual environment where you install a newer version, like this:

```bash
# Ensure you have the venv package
sudo apt install python3.8-venv
# Create a venv and activate it
python3 -m venv .venv
source .venv/bin/activate
# Install the openstack client inside the venv
pip install python-openstackclient
```

1. Create a `clouds.yaml` if you don't have one already.
   It is an alternative to the `OS_*` environment variables and looks like this:
   ```yaml
   clouds:
     "capo-kna1":
       auth:
         auth_url: "https://kna1.citycloud.com:5000"
         username: "user"
         password: "secret"
         domain_name: "CCP_Domain_37137"
         user_domain_name: "CCP_Domain_37137"
         project_name: "CAPO"
         tenant_name: "CAPO"
       region_name: "Kna1"
       verify: false
   ```
   Save it for example at `~/.config/openstack`.
   **Note:** `clouds.yaml` at the root of the CAPO repo is overwritten by `create_devstack.sh` so don't save it there!
2. Export some variables (save these in a file so you can easily source them when needed).
   ```bash
   # This tells create_devstack.sh to use openstack to create the resources
   export RESOURCE_TYPE="openstack"
   # This is the cloud to use in the clouds.yaml file created above
   export OS_CLOUD="capo-kna1"
   # The openstack flavor to use for the devstack servers
   export OPENSTACK_FLAVOR_controller="16C-32GB-200GB"
   export OPENSTACK_FLAVOR_worker="4C-16GB-150GB"
   export OPENSTACK_SSH_KEY_NAME=<openstack-keypair-name>
   export SSH_PUBLIC_KEY_FILE="/home/${USER}/.ssh/id_ed25519.pub"
   export SSH_PRIVATE_KEY_FILE="/home/${USER}/.ssh/id_ed25519"
   export OPENSTACK_PUBLIC_NETWORK="ext-net"
   ```
3. Ensure that there is no old `clouds.yaml` in the root of the CAPO repo that would override the one you created.
   ```bash
   rm ./clouds.yaml
   ```
4. Run the script!
   ```bash
   ./hack/ci/create_devstack.sh
   ```

You should now have a working devstack!
The script also runs `sshuttle` in the background so that it is possible to reach the networks inside the devstack that are used for e2e tests.
Run the e2e tests like this:
```
export OPENSTACK_CLOUD_YAML_FILE=$(pwd)/clouds.yaml
make test-e2e
```

### Cleanup devstack

Note that the devstack is "self contained" in the way that any resources created inside the devstack will be removed with the devstack, so the only thing to clean up is the devstack itself.

1. Remove the devstack `clouds.yaml` so that the scripts don't try to use it instead of the one you created.
2. Export `OS_CLOUD` and check that it points to the correct environment (where the devstack is running).
2. Run `./hack/ci/create_devstack.sh cleanup`.

## TODO

[ ] Add kustomize config for editing the cluster templates
