#! /usr/bin/env bash

get_dev_jumphost_public_ip() {

  FLOATING_IP_ADDRESS="$(openstack floating ip list -f json \
  --tags "${DEV_JUMPHOST_FLOATING_IP_TAG}" \
  | jq -r 'map(."Floating IP Address") | @csv' \
  | tr ',' '\n' \
  | tr -d '"')"

  echo "${FLOATING_IP_ADDRESS}"
}
