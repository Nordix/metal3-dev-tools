#! /usr/bin/env bash

set -eu

# Description:
# Add New  Jumphost User Key in artifactory.
# If user is not already present. It will create
# the user directory.
# Requires:
#   - RT_USER, RT_TOKEN and RT_URL environment vars
#     to be set.
# Usage:
#   add_user_key.sh <user_name> <user_key_name> <user_public_key>
#

CI_DIR="$(dirname "$(readlink -f "${0}")")/../.."
RT_SCRIPTS_DIR="${CI_DIR}/scripts/artifactory"

NEW_USER="${1:?}"
USER_PUB_KEY_NAME="${2:?}"
USER_PUB_KEY="${3:?}"

# shellcheck disable=SC1090
source "${RT_SCRIPTS_DIR}/utils.sh"

rt_add_user_public_key "${NEW_USER}" "${USER_PUB_KEY_NAME}" "${USER_PUB_KEY}"
