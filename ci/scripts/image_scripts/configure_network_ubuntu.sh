#!/bin/bash

# Configure network (set nameservers and disable peer DNS).
cat <<EOF | sudo tee /etc/netplan/90-nameservers.yaml
network:
  version: 2
  ethernets:
    ens3:
      dhcp4-overrides:
        use-dns: no
      nameservers:
        addresses: [1.1.1.1, 8.8.8.8]

EOF
# Apply the changes
sudo netplan apply
