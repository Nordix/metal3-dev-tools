#!/bin/bash

CACERT_PATH="${1}"

if [ $# -eq 0 ]; then
    echo "Cacert path is required"
    exit 1
fi

if [ ! -f "${CACERT_PATH}" ]; then
    echo "Cacert file not found"
    exit 1
fi

source /tmp/openstackrc 

echo "
clouds:
  os_instance_1:
    auth:
      auth_url: "${OS_AUTH_URL}"
      project_name: Default Project 37137
      username: "${OS_USERNAME}"
      password: "${OS_PASSWORD}"
      version: "${OS_AUTH_VERSION}"
      domain_name: "${OS_PROJECT_DOMAIN_NAME}"
      user_domain_name: "${OS_USER_DOMAIN_NAME}"
      project_name: "${OS_PROJECT_NAME}"
      tenant_name: "${OS_PROJECT_NAME}"
    region_name: "${OS_REGION_NAME}"
    cacert: /work_dir/cacert.pem
" > "clouds.yaml"

docker run -it \
	-v /tmp/openstackrc:/tmp/openstackrc \
	-v $(pwd):/work_dir \
	-w /work_dir golang:yq > /tmp/capo_openstackrc

