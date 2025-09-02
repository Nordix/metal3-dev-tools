# Openstack Infrastructure

Author: [Tero Kauppinen](mailto:tero.kauppinen@est.tech)

This folder contain scripts to create/delete/interact with openstack
infrastructure.

## Prerequisites

- Install jq
- Install Openstack Python Client. (pip install python-openstackclient)
- Source Openstack stackrc

## Configuration

In addition to command line arguments and options, scripts read
configuration defined in './infra_defines.sh'. In this file the
configuration is structured in such a way that each configuration
variable of the same deployment is prefixed with the same,
chosen keyword. This keyword is known as `target`.

Here is an example of the deployment which can be selected by
using `DEV` as the `target` name.

```bash
# Global defines for Metal3 DEV infrastructure
# =============================================
DEV_KEYPAIR_NAME="metal3-jumphost-management-key"
DEV_ROUTER_NAME="metal3-dev-ext-router"
DEV_EXT_NETWORK="internet"
DEV_NETWORK="metal3-dev-ext-net"
DEV_SUBNET_CIDR="10.101.10.0/24"
DEV_JUMPHOST_NAME="metal3-dev-jumphost"
DEV_JUMPHOST_FLOATING_IP_TAG="metal3_dev_jumphost_fip"
DEV_JUMPHOST_EXT_SG="metal3_dev_jumphost_ext_sg"
DEV_JUMPHOST_FLAVOR="c1m2-est"
DEV_JUMPHOST_IMAGE="Ubuntu-24.04"
```

The next chapter will illustrate which elements these configuration
variables point in the deployment infrastructure to.

## Overview of the Infrastructure

Below is an illustration of the deployment infrastructure that binds
configuration variables to their corresponding logical entities. In
the figure, the prefix `DEV` represents the chosen `target` name for
this deployment.

```bash
    |                                                       .
  a |                                                       .   +--------+
  c |                                                       .   |        |
  c |           +--------+                                  +---+ node A |
  e |           |        | internal network = DEV_NETWORK   |   |        |
  s +-----------+ router +----------------------------------+   +--------+
  s |           |        | 10.101.10.0/24 = DEV_SUBNET_CIDR |
    |           +--------+                                  |
  n |         DEV_ROUTER_NAME                               |   +----------+
  e |                                                       |   |          |
  t |                                                       +---+ jumphost |
  w |                                                   +-----> |          |
  o | <-- DEV_EXT_NETWORK                               |       +----------+
  r |                                                   |     DEV_JUMPHOST_NAME
  k |                                                   |
    |                                                   |
    |                            public IP's tag = DEV_JUMPHOST_FLOATING_IP_TAG
    |                            security group = DEV_JUMPHOST_EXT_SG
                                 flavor = DEV_JUMPHOST_FLAVOR
                                 image = DEV_JUMPHOST_IMAGE
                                 admin user's key pair = DEV_KEYPAIR_NAME
```

## Management key

In addition to infrastructure management scripts, this folder contains scripts
for handling the management key. The management key is used as the admin key pair
for *jumphost* when it is created. This key pair could be used to manage also
other nodes than just *jumphosts*.

### Inject the management key

Management key can be injected with the following command:

```console
$. /infra_add_key.sh

Usage:

  infra_add_key.sh [opts]

Add management key.

Use the `-h` option to list all available options.
```

Public key for the key pair is specified by the `key-file` option. If no
value is given, `${HOME}/.ssh/id_ed25519.pub` is assumed. If no other `target`
is given, the script assumes the effective user name as the `target` prefix.

### Remove the management key

Management key can be revoked with following command:

```console
$ ./infra_del_key.sh

Usage:

  infra_del_key.sh [opts]

Delete management key.

Use the `-h` option to list all available options.
```

If no other `target` is given, the script assumes the effective user name as
the `target` prefix.

### Create Infrastructure

A new infrastructure can be created simply by running the following script:

```console
$ ./infra_setup.sh

Usage:

  infra_setup.sh [opts]

Setup the target infrastructure.

Use the `-h` option to list all available options.
```

This will create both a ***router*** and an ***internal network***. If no other
`target` is given, the script assumes the effective user name as the `target`
prefix.

### Delete Infrastructure

An existing infrastructure can be removed by running the following script:

```console
$ ./infra_delete.sh

Usage:

  infra_delete.sh [opts]

Delete the target infrastructure.

Use the `-h` option to list all available options.
```

If no other `target` is given, the script assumes the effective user name as
the `target` prefix.
