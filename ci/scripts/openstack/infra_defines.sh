#! /usr/bin/env bash

# shellcheck disable=SC2034
true

# External network for Airship Openstack Tenant
EXT_NET="ext-net"

# Global defines for Airship CI infrastructure
# ============================================

CI_ROUTER_NAME="metal3-ci-ext-router"
CI_EXT_NET="metal3-ci-ext-net"
CI_EXT_SUBNET_CIDR="10.100.10.0/24"
CI_INT_SUBNET_CIDR="10.0.10.0/24"
CI_KEYPAIR_NAME="airshipci-key"
CI_BASE_IMAGE="airship-ci-ubuntu-base-img"
CI_JENKINS_IMAGE="airship-ci-ubuntu-jenkins-img"
CI_METAL3_IMAGE="airship-ci-ubuntu-metal3-img"
CI_METAL3_CENTOS_IMAGE="airship-ci-centos-metal3-img"
CI_NODE_CENTOS_IMAGE="airship-ci-centos-node-img"
CI_SSH_USER_NAME="airshipci"
VM_KEY=${VM_KEY:-local}
VM_PREFIX="ubuntu"
VM_PREFIX_CENTOS="centos"

# Global defines for Airship DEV infrastructure
# =============================================

DEV_ROUTER_NAME="metal3-dev-ext-router"
DEV_EXT_NET="metal3-dev-ext-net"
DEV_EXT_SUBNET_CIDR="10.101.10.0/24"
DEV_INT_SUBNET_CIDR="10.1.10.0/24"
DEV_JUMPHOST_NAME="airship-dev-jumphost"
DEV_JUMPHOST_FLOATING_IP_TAG="airship_dev_jumphost_fip"
DEV_JUMPHOST_EXT_SG="airship_dev_jumphost_ext_sg"
