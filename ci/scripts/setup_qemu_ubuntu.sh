#! /usr/bin/env bash

set -eu

sudo apt install -y qemu qemu-kvm

# Enable nested virtualization
sudo bash -c 'cat << EOF > /etc/modprobe.d/qemu-system-x86.conf
options kvm-intel nested=y enable_apicv=n
EOF'

echo "Reboot required"

