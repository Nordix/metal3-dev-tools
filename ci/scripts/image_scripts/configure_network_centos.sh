#!/usr/bin/env bash
# The goal of this script is to prevent NetworkManager set
# dns server addresses on /etc/resolve.conf 

# make NetworkManager to prevent modifying resolv.conf
sudo sed -i '/^\[main\]/a dns=none' /etc/NetworkManager/NetworkManager.conf
sudo systemctl restart NetworkManager.service

# Specify DNS servers for systemd-resolved.
cat <<EOF | sudo tee /etc/resolv.conf
nameserver 1.1.1.1
nameserver 8.8.8.8

EOF
