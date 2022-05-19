#! /usr/bin/env bash

set -eux

# This script sets up fresh ubuntu 18.04+ installation
# to create a base image for our applications.

SCRIPTS_DIR="$(dirname "$(readlink -f "${0}")")"
# Needrestart and packer does not seem to work well together. Needrestart is
# propmpting for what services to restart and packer cannot answer, so it get stuck.
# This makes needrestart (l)ist the packages instead of prompting with a dialog.
# The alternative would be sudo apt-get remove -y needrestart.
echo '$nrconf{restart} = "l";' | sudo tee /etc/needrestart/needrestart.conf || true

# Upgrade all packages
sudo apt-get update
sudo apt-get dist-upgrade -f -y                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                             

# Install required packages.
sudo apt install -y \
  vim \
  jq \
  git \
  coreutils \
  wget \
  curl \
  apt-transport-https \
  ca-certificates \
  tree \
  make \
  gnupg-agent \
  software-properties-common \
  openssl

# Install docker.
"${SCRIPTS_DIR}"/setup_docker_ubuntu.sh

# Configure chrony.
"${SCRIPTS_DIR}"/setup_chrony_ubuntu.sh

# Enable nested virtualization.
"${SCRIPTS_DIR}"/setup_qemu_ubuntu.sh

# Perform security hardening.
"${SCRIPTS_DIR}"/hardening_base_image.sh


# Reset cloud-init to run on next boot.
"${SCRIPTS_DIR}"/reset_cloud_init.sh
