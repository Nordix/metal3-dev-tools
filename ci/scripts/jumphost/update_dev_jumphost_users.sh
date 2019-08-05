#! /usr/bin/env bash

set -eu

CI_DIR="$(dirname "$(readlink -f "${0}")")/../.."
RT_SCRIPTS_DIR="${CI_DIR}/scripts/artifactory"
JUMPHOST_SCRIPTS_DIR="${CI_DIR}/scripts/jumphost"

# shellcheck disable=SC1090
source "${RT_SCRIPTS_DIR}/utils.sh"
# shellcheck disable=SC1090
source "${JUMPHOST_SCRIPTS_DIR}/utils.sh"

# Fetch List of users from artifactory
USERS="$(rt_list_directory "${RT_USERS_DIR}" \
  | jq -r '.children[] | select(.folder==true) |.uri')"

# Iterate over all users and add user to jumphost
for JH_USER in ${USERS}
do
  USER_KEY_FILE="$(mktemp)"
  _USER_KEYS="$(rt_get_user_public_keys "${JH_USER//\//}")"
  echo "${_USER_KEYS}" > "${USER_KEY_FILE}"
  "${JUMPHOST_SCRIPTS_DIR}/add_jumphost_user.sh" "${JH_USER//\//}" "${USER_KEY_FILE}"
done
