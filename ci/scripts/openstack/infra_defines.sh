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

# Global defines for Airship DEV infrastructure
# ============================================

DEV_ROUTER_NAME="airship-dev-ext-router"
DEV_EXT_NET="airship-dev-ext-net"
DEV_EXT_SUBNET_CIDR="10.101.10.0/24"
DEV_INT_NET="airship-dev-int-net"
DEV_INT_SUBNET_CIDR="10.1.10.0/24"


