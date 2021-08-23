#! /usr/bin/env bash

set -eu

VM_PORT_NAME="${VM_PORT_NAME:-${VM_NAME}-int-port}"

# Delete executer vm
echo "Deleting executer VM."
openstack server delete "${VM_NAME}"

# Delete executer VM port
echo "Deleting executer VM port."
openstack port delete "${VM_PORT_NAME}"

