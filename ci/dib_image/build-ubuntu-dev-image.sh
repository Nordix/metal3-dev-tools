#!/usr/bin/env bash

set -eux

export IMAGE_OS="ubuntu"

# Install disk-image-builder
sudo apt-get install python3-pip -y
sudo pip install diskimage-builder

# shellcheck disable=SC1091
. dib-and-image-vars.sh

# Create an image
disk-image-create --no-tmpfs -a amd64 ubuntu-dev ubuntu -o "${IMAGE_NAME}" block-device-mbr

# Install openstackclient
sudo pip3 install python-openstackclient

# shellcheck disable=SC1091
. openstack-vars.sh

# Push image to openstack
openstack image create "${FINAL_IMAGE_NAME}" --file "${IMAGE_NAME}" --disk-format=qcow2
