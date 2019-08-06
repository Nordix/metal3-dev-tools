#! /usr/bin/env bash

set -eu

# Description:
# Delete Jumphost User Key in artifactory.
#
# Usage:
#   del_user_key.sh <user_name> <user_key_name>
#

CI_DIR="$(dirname "$(readlink -f "${0}")")/../.."
RT_SCRIPTS_DIR="${CI_DIR}/scripts/artifactory"

_USER="${1:?}"
USER_PUB_KEY_NAME="${2:?}"

# shellcheck disable=SC1090
source "${RT_SCRIPTS_DIR}/utils.sh"

rt_del_user_public_key "${_USER}" "${USER_PUB_KEY_NAME}"
