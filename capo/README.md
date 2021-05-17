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

Then:

* Run `make` in one tab to bring up a CAPI/CAPO master Kubernetes cluster
  managed by tilt
* Make changes to `cluster-api-provider-openstack`
* Run `make provision` to deploy a 2 node cluster on OpenStack and test your
  changes

## TODO

[ ] Add kustomize config for editing the cluster templates
