#! /usr/bin/env bash

# This script will empty the /etc/machine-id (machine-id(5)
# file so that the machine-id will be regenerated on the
# next (initial) boot of the image

sudo rm -f /etc/machine-id
sudo touch /etc/machine-id