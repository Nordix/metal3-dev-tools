#!/bin/bash

_prefix=${1:-"cluster-e2e"}

echo "===Removing openstack servers==="
servers=$(openstack server list -c Name -f value | grep ${_prefix})
for server in ${servers};do 
  echo "Removing server: ${server}"
  openstack server delete "${server}";
done

echo "===Removing floating IPs==="
openstack router list -c Name -f value | grep ${_prefix} > routers.txt
for router in $(cat routers.txt);do 
	port=$(openstack floating ip list --router=${router} -c Port -f value)
	echo "Deleting port: ${port}"
	openstack port delete ${port}
done

echo "===Remove gateway from routers==="
for router in $(cat routers.txt);do
    echo "removing gateway from ${router}"
	openstack router unset --external-gateway "${router}"
done

echo "===Removing ports from router==="
for router in $(cat routers.txt);do
    port=$(openstack port list --router=${router} -c ID -f value)
    echo "removing port: ${port} from router: ${router}"
    openstack router remove port ${router} ${port}
done

echo "===Remove router==="
for router in $(cat routers.txt);do
    echo "removing router: ${router}"
    openstack router delete ${router}
done

# Get networks
openstack network list -c Name -f value| grep ${_prefix} > networks.txt

echo "Removing networks"
for net in $(cat networks.txt);do
  ports=$(openstack port list --network=${net} -c id -f value)
  for port in ${ports}; do openstack port delete ${port}; done
  echo "Removing network: ${net}"
  openstack network delete ${net}
done

echo "Removing security group"
sgs=$(openstack security group list -c Name -f value | grep ${_prefix})
for sg in ${sgs};do
  echo "Deleting security group: ${sg}" 
  openstack security group delete ${sg}
done