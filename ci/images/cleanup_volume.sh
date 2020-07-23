#! /usr/bin/env bash

set -eu

CI_DIR="$(dirname "$(readlink -f "${0}")")/.."
OS_SCRIPTS_DIR="${CI_DIR}/scripts/openstack"

# shellcheck disable=SC1090
source "${OS_SCRIPTS_DIR}/utils.sh"

# shellcheck disable=SC1090
source "${OS_SCRIPTS_DIR}/infra_defines.sh"

echo "Cleaning old resources"

VM_LIST=$(openstack server list -f json \
  | jq -r ".[] | select(.Name==\"${VM_PREFIX_CENTOS}-${VM_KEY}\" or .Name==\"${VM_PREFIX}-${VM_KEY}\") | .ID")

for VM_ID in $VM_LIST
do
  echo "Deleting executer VM ${VM_ID}."
  openstack server delete "${VM_ID}"
done

VOLUME_LIST=$(openstack volume list -f json \
  | jq -r ".[] | select(.Name==\"${VM_PREFIX_CENTOS}-${VM_KEY}\" or .Name==\"${VM_PREFIX}-${VM_KEY}\") | .ID")

for VOLUME_ID in $VOLUME_LIST
do
  echo "Waiting until volume status is available, to proceed with proper volume deletion."
  until openstack volume show "${VOLUME_ID}" -f json \
    | jq .status | grep "available"
  do
    sleep 10
  done
  openstack volume delete "${VOLUME_ID}"
done

PORT_LIST=$(openstack port list -f json \
  | jq -r ".[] | select(.Name==\"${VM_PREFIX_CENTOS}-${VM_KEY}-int-port\" or .Name==\"${VM_PREFIX}-${VM_KEY}-int-port\") | .ID")

for VM_PORT_ID in $PORT_LIST
do
  FLOATING_IP_LIST=$(openstack floating ip list -f json \
    | jq -r ".[] | select(.Port==\"${VM_PORT_ID}\") | .ID")
  for FLOATING_IP_ID in $FLOATING_IP_LIST; do
    echo "Deleting the package installer VM's floating IP."
    openstack floating ip delete "${FLOATING_IP_ID}"
  done
  # Delete executer vm
  echo "Deleting executer VM port ${VM_PORT_ID}."
  openstack port delete "${VM_PORT_ID}"
done