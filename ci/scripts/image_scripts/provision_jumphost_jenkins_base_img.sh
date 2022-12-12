#! /usr/bin/env bash

set -eux

# This script sets up jenkins slave image for
# CI operations and can also be used as a jumphost.

SCRIPTS_DIR="$(dirname "$(readlink -f "${0}")")"

# Install required packages.
sudo apt-get install -y \
  openjdk-11-jre \
  python3-pip

sudo pip3 install \
  python-openstackclient

# Reset cloud-init to run on next boot.
"${SCRIPTS_DIR}"/reset_cloud_init.sh
