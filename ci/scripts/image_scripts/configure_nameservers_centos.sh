#!/bin/bash

# Disable cloud-init network configuration that would overwrite the network config.
cat <<EOF | sudo tee /etc/cloud/cloud.cfg.d/01-network.cfg
network:
  config: disabled
# resolv.conf is managed by NetworkManager, cloud-init should not touch it
manage_resolv_conf: false
EOF
# Even with the above, cloud-init will configure NetworkManager to not touch
# resolv.conf *if* there is a nameserver configured for the subnet in openstack.
# This is done in the following file, that we remove to let NM handle resolv.conf
# Ref https://bugs.launchpad.net/cloud-init/+bug/1693251
sudo rm /etc/NetworkManager/conf.d/99-cloud-init.conf || true
sudo systemctl restart NetworkManager
# Configure network (set nameservers, disable peer DNS and remove mac address
# that was automatically added). The rest of the fields are kept as is.
cat <<EOF | sudo tee /etc/sysconfig/network-scripts/ifcfg-eth0
NAME="System eth0"
BOOTPROTO=dhcp
DEVICE=eth0
MTU=1500
ONBOOT=yes
TYPE=Ethernet
USERCTL=no
PEERDNS=no
DNS1=8.8.8.8
DNS2=8.8.4.4
EOF
# Apply the changes
sudo nmcli connection reload
sudo nmcli connection up "System eth0"
