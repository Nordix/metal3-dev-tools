#!/bin/bash

set -x

GIT_ROOT=$(git rev-parse --show-toplevel)
CAPI_REPO=$(realpath "${GIT_ROOT}/../cluster-api")
CAPO_REPO=$(realpath "${GIT_ROOT}/../cluster-api-provider-openstack")

CACERT_PATH="/tmp/cacert.pem"
OPENSTACK_RC_PATH="/tmp/openstackrc"
OS_CLOUD_NAME="$1"

if ! [[ -d "$CAPI_REPO" ]]; then
	echo "Unable to find cluster-api repo, please clone it."
	return
fi

if ! [[ -d "$CAPO_REPO" ]]; then
	echo "Unable to find cluster-api-provider-openstack, please clone it."
	return
fi

if ! [[ -f "$CACERT_PATH" ]];then
	echo "Unable to find cacert.pem file, please the cert file"
	return
fi
if ! [[ -f "$OPENSTACK_RC_PATH" ]];then
	echo "Unable to find OpenStackrc file, It can be retrieved the PEM file from 1Password."
	return
fi

if ! command -v kind &> /dev/null;then
	echo "Couldn't find 'kind'. Install from https://kind.sigs.k8s.io/"
	return
fi
if ! command -v tilt &> /dev/null;then
	echo "Couldn't find 'tilt'. Install from https://docs.tilt.dev/install.html"
	return
fi

if ! ssh-keygen -l -f <(echo $OPENSTACK_SSH_AUTHORIZED_KEY);then
  echo "Invalid public key"
	return
fi
PRIVATE_KEY="~/.ssh/$OPENSTACK_SSH_KEY_NAME"
if ! ssh-keygen -l -f $(eval echo $PRIVATE_KEY);then
	echo "Invalid or non-existing private key"
	return
fi

pubKey=$(ssh-keygen -l -f <(echo $OPENSTACK_SSH_AUTHORIZED_KEY) | cut -f1,2 -d' ')
priKey=$(ssh-keygen -l -f $(eval echo $OPENSTACK_SSH_PRIVATE_KEY_PATH) | cut -f1,2 -d' ')
priKey=$(ssh-keygen -l -f $(eval echo $PRIVATE_KEY) | cut -f1,2 -d' ')
if ! diff  <(echo "$pubKey" ) <(echo "$priKey");then
	echo "public and private key do not match, export the correct values in capo_os_vars.rc"
	return
fi
# use a known working CAPI version
pushd  "$CAPI_REPO"
git fetch --all --tags --prune && git checkout v1.0.1
popd

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

set +x
