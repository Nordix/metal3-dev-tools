# Openstack Infrastructure

This folder contain scripts to create/delete/interact with openstack infrastructure for CI and DEV environments.

## Prerequisites

- Install jq
- Install Openstack Python Client. (pip install python-openstackclient)
- Source Openstack stackrc

## CI Infrastructure

CI Infrastructure contains Router, external network, internal network, SSH Keys, Bastion server, base images e.t.c. There are scripts to delete and create complete infra from scratch. Any changes to the bare minimal infrastructure like routers and networks would require deletion of infrastructure and creating again from scratch.

### Create Infrastructure

```sh
./infra_setup_ci.sh
```

### Delete Infrastructure

```sh
./infra_delete_ci.sh
```

### DEV Infrastructure

DEV Infrastructure like CI infra contains basic components like routers, external network and internal network and Bastion server e.t.c. Apart from bare minimal infra rest of the things are left to developers. There are scripts to delete and create complete infra from scratch. Any changes to the bare minimal infrastructure like routers and networks would require deletion of infrastructure and creating again from scratch.

Resources which developers can use directly are

- ***External Network***: airship-dev-ext-net
- ***External Network Subnet***: airship-dev-ext-net-subnet
- ***Internal Network***: airship-dev-int-net
- ***Internal Network Subnet***: airship-dev-int-net-subnet

#### Create Dev Infrastructure

```sh
./infra_setup_dev.sh
```

#### Delete Dev Infrastructure

```sh
./infra_delete_dev.sh
```
