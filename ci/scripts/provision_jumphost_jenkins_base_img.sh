#! /usr/bin/env bash

set -eux

# This script sets up jenkins slave image for
# CI operations and can also be used as a jumphost.

SCRIPTS_DIR="$(dirname "$(readlink -f "${0}")")"

# Wait for package manager lock to be released

sudo killall apt apt-get || true
sudo rm -f /var/lib/dpkg/lock-frontend
sudo rm -f /var/lib/dpkg/lock
sudo rm -f /var/lib/apt/lists/lock
sudo rm -f /var/cache/apt/archives/lock

until sudo dpkg --configure -a
do
  sleep 1
done

# Install required packages.
sudo apt install -y \
  openjdk-8-jre

# Reset cloud-init to run on next boot.
"${SCRIPTS_DIR}"/reset_cloud_init.sh
