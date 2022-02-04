#!/bin/bash

# This script can be used to run locally one of the image building
# scripts. It reproduces the CI environment.
#
# This requires the openstack.rc file to have been sourced and
# takes two parameters:
# - the file name of the script to run
# - the absolute path to the airshipci user ssh private key

# For example:
# $ source openstack.rc
# $ ./run_local.sh gen_metal3_centos_volume.sh ~/keys/airshipci_id_rsa

set -eux

SCRIPT="${1}"
KEY_PATH="${2}"

CONTAINER_RUNTIME="${CONTAINER_RUNTIME:-docker}"
AIRSHIP_CI_USER="airshipci"
RT_URL="https://artifactory.nordix.org/artifactory"
OS_AUTH_URL="https://kna1.citycloud.com:5000"
OS_USER_DOMAIN_NAME="CCP_Domain_37137"
OS_PROJECT_DOMAIN_NAME="CCP_Domain_37137"
OS_REGION_NAME="Kna1"
OS_PROJECT_NAME="Default Project 37137"
OS_TENANT_NAME="Default Project 37137"
OS_AUTH_VERSION=3
OS_IDENTITY_API_VERSION=3
CR_CMD_ENV="--env AIRSHIP_CI_USER \
  --env AIRSHIP_CI_USER_KEY=/data/id_rsa_airshipci \
  --env RT_URL \
  --env OS_AUTH_URL \
  --env OS_USER_DOMAIN_NAME \
  --env OS_PROJECT_DOMAIN_NAME \
  --env OS_REGION_NAME \
  --env OS_PROJECT_NAME \
  --env OS_TENANT_NAME \
  --env OS_AUTH_VERSION \
  --env OS_IDENTITY_API_VERSION \
  --env OS_USERNAME \
  --env OS_PASSWORD "
CURRENT_DIR="$(dirname "$(readlink -f "${0}")")/../../"

# Run the script in a docker container
"${CONTAINER_RUNTIME}" run --rm \
  ${CR_CMD_ENV}\
  -v ${CURRENT_DIR}:/data \
  -v ${KEY_PATH}:/data/id_rsa_airshipci \
  registry.nordix.org/metal3/image-builder \
  /data/ci/images/${SCRIPT} \
  /data/id_rsa_airshipci 1
