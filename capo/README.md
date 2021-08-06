# CAPI Openstack Provider dev setup

## Requirements

* Install go version >= 1.16
* Install `kind` and `tilt`
* Install version 3.x of `yq` (note: version 4.x is not compatible)

```
wget https://github.com/mikefarah/yq/releases/download/3.4.1/yq_linux_amd64
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
Changes on the CAPI side could break the CAPO setup. In order to avoid that, we are fixing the CAPI version to a known working one, `v0.4.0`. If more recent version is know, please update this document and `configure.sh` script.

Now you need to set up a keypair for SSH access to the machines.

```
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
* Run `make provision` to deploy a 2 node cluster on OpenStack and test your
  changes

## Devstack setup

In order to add more features, such as trunking, we need to create an Openstack instance using devstack.

1. Create Centos-8 VM with 32GB of RAM and 8 CPU cores.
2. From within the VM, clone the devstack repo

```bash
git clone https://opendev.org/openstack/devstack.git
```
3. Create stack user/group with the proper priviledge
```bash
cd devstack
sudo ./tools/create-stack-user.sh
```
4. Install devstack as stack user

```bash
sudo su
su - stack
```

```bash
git clone https://opendev.org/openstack/devstack.git
cd devstack
sudo mkdir -p /opt/stack/logs
sudo chown stack:stack /opt/stack/
sudo chmod -R 755 /opt/stack/
```

The following error could be seen

```bash
OpenStack Wallaby Repository
Error: Failed to download metadata for repo 'openstack-wallaby': Cannot prepare internal mirrorlist: No URLs in mirrorlist
```
If you see the above error, run the following to fix it.

```bash
sudo sed -i 's/enabled=1/enabled=0/' /etc/yum.repos.d/rdo-release.repo
yum update -y
```

configure trunk support, more information can be found [here](https://docs.openstack.org/ocata/networking-guide/config-trunking.html)

To add trunk supoort edit `lib/neutron_plugins/ovn_agent`

```
ML2_L3_PLUGIN=${ML2_L3_PLUGIN-"ovn-router,trunk"}
```

Now, start the installation.

```bash
./stack.sh
```

Verify installation

```bash
openstack extension list -f json -c Description -f value | grep trunk
  Extensions list not supported by Identity API
  Provides support for trunk ports
  Expose trunk port details
```

## TODO

[ ] Add kustomize config for editing the cluster templates
