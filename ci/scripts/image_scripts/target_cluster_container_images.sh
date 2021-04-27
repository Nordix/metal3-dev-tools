#!/bin/bash

set -uex

# Container images that we pre-pull into the target image.
export CALICO_CNI_IMG="${CALICO_CNI_IMG:-"docker.io/calico/cni:v3.18.2"}"
export CALICO_POD2DAEMON_IMG="${CALICO_POD2DAEMON_IMG:-"docker.io/calico/pod2daemon-flexvol:v3.18.2"}"
export CALICO_NODE_IMG="${CALICO_NODE_IMG:-"docker.io/calico/node:v3.18.1"}"
export CALICO_KUBE_CONTROLLERS_IMG="${CALICO_KUBE_CONTROLLERS_IMG:-"docker.io/calico/kube-controllers:v3.18.1"}"

sudo systemctl enable --now crio

# Download Calico images and other container images
for container in $(env | grep "CALICO_*" | cut -f2 -d'='); do
  sudo crictl pull "${container}"
done