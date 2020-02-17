#!/bin/bash

set -eux

if [ $# -lt 1 ]; then
  echo 1>&2 "Usage: $0 [ca.crt ca.key] <api end point (https://IP:port or https://domainname:port>"
  exit 3
fi

function generate_ca_certs() {
  openssl genrsa -out ./credentials/ca.key 2048
  openssl req -x509 -new -nodes -key ./credentials/ca.key -subj "/CN=Kubernetes-ca" -days 10000 -out ./credentials/ca.crt
}

# if ca.key and ca.crt are not provided, then create them
# if ca.key and ca.crt are provided, then copy them to the right location.
if [ $# -eq 1 ]; then
   generate_ca_certs
   export K8S_ENDPOINT=${1}
else
   cp "${1}" ./credentials/ca.crt
   cp "${2}" ./credentials/ca.key
   export K8S_ENDPOINT=${3}
fi

openssl genrsa -out ./credentials/admin.key 2048
openssl req -new -key ./credentials/admin.key -subj "/CN=admin/O=system:masters" -out ./credentials/admin.csr
openssl x509 -req -in ./credentials/admin.csr -CA ./credentials/ca.crt -CAkey ./credentials/ca.key -CAcreateserial  -out ./credentials/admin.crt -days 3653

export ADMIN_CERT=$(cat ./credentials/admin.crt | base64 -w 0)
export ADMIN_KEY=$(cat ./credentials/admin.key | base64 -w 0)
export CA_CERT=$(cat ./credentials/ca.crt | base64 -w 0)

echo "apiVersion: v1
clusters:
- cluster:
    certificate-authority-data: ${CA_CERT}
    server: ${K8S_ENDPOINT}
  name: kubernetes
contexts:
- context:
    cluster: kubernetes
    user: kubernetes-admin
  name: kubernetes-admin@kubernetes
current-context: kubernetes-admin@kubernetes
kind: Config
preferences: {}
users:
- name: kubernetes-admin
  user:
    client-certificate-data: ${ADMIN_CERT}
    client-key-data: ${ADMIN_KEY}" > _admin.conf
