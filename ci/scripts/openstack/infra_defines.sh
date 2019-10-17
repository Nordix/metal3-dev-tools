#! /usr/bin/env bash

# shellcheck disable=SC2034
true

# External network for Airship Openstack Tenant
EXT_NET="ext-net"

# Global defines for Airship CI infrastructure
# ============================================

CI_ROUTER_NAME="airship-ci-ext-router"
CI_EXT_NET="airship-ci-ext-net"
CI_EXT_SUBNET_CIDR="10.100.10.0/24"
CI_INT_NET="airship-ci-int-net"
CI_INT_SUBNET_CIDR="10.0.10.0/24"
CI_KEYPAIR_NAME="airshipci-key"
CI_BASE_IMAGE="airship-ci-ubuntu-base-img"
CI_JENKINS_IMAGE="airship-ci-ubuntu-jenkins-img"
CI_METAL3_IMAGE="airship-ci-ubuntu-metal3-img"
CI_METAL3_CENTOS_IMAGE="airship-ci-centos-metal3-img"
CI_NODE_CENTOS_IMAGE="airship-ci-centos-node-img"
CI_SSH_USER_NAME="airshipci"

# Global defines for Airship DEV infrastructure
# =============================================

DEV_ROUTER_NAME="airship-dev-ext-router"
DEV_EXT_NET="airship-dev-ext-net"
DEV_EXT_SUBNET_CIDR="10.101.10.0/24"
DEV_INT_NET="airship-dev-int-net"
DEV_INT_SUBNET_CIDR="10.1.10.0/24"
DEV_JUMPHOST_NAME="airship-dev-jumphost"
DEV_JUMPHOST_FLOATING_IP_TAG="airship_dev_jumphost_fip"
DEV_JUMPHOST_EXT_SG="airship_dev_jumphost_ext_sg"
