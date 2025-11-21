#!/usr/bin/env bash

# shellcheck disable=SC2034
true

# Global defines for Metal3 CI infrastructure
# ============================================
CI_KEYPAIR_NAME="metal3-jumphost-management-key"
CI_ROUTER_NAME="metal3-ci-ext-router"
CI_EXT_NETWORK="internet"
CI_NETWORK="metal3-ci-int-net"
CI_SUBNET_CIDR="10.10.10.0/24"
CI_JUMPHOST_NAME="metal3-ci-jumphost"
CI_JUMPHOST_FLOATING_IP_TAG="metal3_ci_jumphost_fip"
CI_JUMPHOST_EXT_SG="metal3_ci_jumphost_ext_sg"
CI_JUMPHOST_FLAVOR="c1m2-est"
CI_JUMPHOST_IMAGE="Ubuntu-24.04"

# Global defines for Metal3 DEV infrastructure
# =============================================
DEV_KEYPAIR_NAME="metal3-jumphost-management-key"
DEV_ROUTER_NAME="metal3-dev-new-ext-router"
DEV_EXT_NETWORK="internet"
DEV_NETWORK="metal3-dev-int-net"
DEV_SUBNET_CIDR="10.1.0.0/24"
DEV_JUMPHOST_NAME="metal3-dev-new-jumphost"
DEV_JUMPHOST_FLOATING_IP_TAG="metal3_dev_new_jumphost_fip"
DEV_JUMPHOST_EXT_SG="metal3_dev_new_jumphost_ext_sg"
DEV_JUMPHOST_FLAVOR="c1m2-est"
DEV_JUMPHOST_IMAGE="Ubuntu-24.04"
