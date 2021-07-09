#!/bin/bash

set -euxo pipefail

GIT_ROOT=$(git rev-parse --show-toplevel)
CAPI_REPO=$(realpath "${GIT_ROOT}/../cluster-api")
CAPO_REPO=$(realpath "${GIT_ROOT}/../cluster-api-provider-openstack")

CACERT_PATH="/tmp/cacert.pem"
OPENSTACK_RC_PATH="/tmp/openstackrc"
OS_CLOUD_NAME="$1"

if ! [[ -d "$CAPI_REPO" ]]; then
  echo "Expected to find directory $CAPI_REPO, but couldn't find it."
  echo "Clone this repo from https://github.com/kubernetes-sigs/cluster-api"
  exit 1
fi

if ! [[ -d "$CAPO_REPO" ]]; then
  echo "Expected to find directory $CAPO_REPO, but couldn't find it."
  echo "Clone this repo from https://github.com/Nordix/cluster-api-provider-openstack"
  exit 1
fi

if ! [[ -f "$CACERT_PATH" ]]; then
  echo "Expected to find OpenStack auth cacert.pem at $CACERT_PATH"
  exit 1
fi

if ! [[ -f "$OPENSTACK_RC_PATH" ]]; then
  echo "Expected to find OpenStack RC file at $OPENSTACK_RC_PATH"
  echo "You can get this PEM file from 1Password."
  exit 1
fi

if ! [[ -f ~/.ssh/id_rsa.pub ]]; then
  echo "Couldn't find a pubkey to use at ~/.ssh/id_rsa.pub"
  echo "Set your pubkey in capo_os_vars.rc"
  exit 1
fi

if ! command -v kind &> /dev/null; then
  echo "Couldn't find 'kind'. Install from https://kind.sigs.k8s.io/"
  exit 1
fi

if ! command -v tilt &> /dev/null; then
  echo "Couldn't find 'tilt'. Install from https://docs.tilt.dev/install.html"
  exit 1
fi

source "$OPENSTACK_RC_PATH"
echo "Configuring CAPO deployment for project: ${OS_PROJECT_NAME}"

cat << EOF >/tmp/clouds.yaml
clouds:
  "${OS_CLOUD_NAME}":
    auth:
      auth_url: "${OS_AUTH_URL}"
      username: "${OS_USERNAME}"
      password: "${OS_PASSWORD}"
      version: "${OS_AUTH_VERSION}"
      domain_name: "${OS_PROJECT_DOMAIN_NAME}"
      user_domain_name: "${OS_USER_DOMAIN_NAME}"
      project_name: "${OS_PROJECT_NAME}"
      tenant_name: "${OS_PROJECT_NAME}"
    region_name: "${OS_REGION_NAME}"
    cacert: "${CACERT_PATH}"
    verify: false
EOF
