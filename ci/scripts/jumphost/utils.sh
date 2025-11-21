#!/usr/bin/env bash

# Description:
# Get the public IP of jumphost.
#
# Requires:
#   - source stackrc file.
#   - jumphost should already be deployed.
#
# Usage:
#  get_jumphost_public_ip <tag>
#
get_jumphost_public_ip() {
  local TAG

  TAG=${1:-"I-HAVE-NO-TAG"}

  FLOATING_IP_ADDRESS="$(openstack \
    floating ip list -f json --tags "${TAG}" \
    | jq -r 'map(."Floating IP Address") | @csv' \
    | tr ',' '\n' \
    | tr -d '"')"

  echo "${FLOATING_IP_ADDRESS}"
}
