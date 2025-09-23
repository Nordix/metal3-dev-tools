#! /usr/bin/env bash

set -euo pipefail

# Description:
# Reads all the users and their keys from artifatory and
# create or update those users' keys on dev jumphost.
# Purge non-existing users (if not disabled).
#
#   Requires:
#     - source stackrc file
#     - openstack infra and jumphost should already be deployed
#
# Usage:
#   sync_jumphost_users.sh <user_name> <file_path_containing_all_user_keys>
#

CI_DIR="$(dirname "$(readlink -f "${0}")")/../.."
RT_SCRIPTS_DIR="${CI_DIR}/scripts/artifactory"
JUMPHOST_SCRIPTS_DIR="${CI_DIR}/scripts/jumphost"
COMMON_SCRIPTS_DIR="${CI_DIR}/scripts/common"
OS_SCRIPTS_DIR="${CI_DIR}/scripts/openstack"

# shellcheck source=ci/scripts/common/opts.sh
. "${COMMON_SCRIPTS_DIR}/opts.sh"
# shellcheck source=ci/scripts/common/utils.sh
. "${COMMON_SCRIPTS_DIR}/utils.sh"
# shellcheck source=ci/scripts/artifactory/utils.sh
. "${RT_SCRIPTS_DIR}/utils.sh"
# shellcheck source=ci/scripts/openstack/utils.sh
. "${OS_SCRIPTS_DIR}/utils.sh"
# shellcheck source=ci/scripts/openstack/infra_defines.sh
. "${OS_SCRIPTS_DIR}/infra_defines.sh"
# shellcheck source=ci/scripts/jumphost/utils.sh
. "${JUMPHOST_SCRIPTS_DIR}/utils.sh"

add_jumphost_user() {
  local USER USER_AUTHORIZED_KEYS_FILE

  USER=${1:?}
  USER_AUTHORIZED_KEYS_FILE=${2:?}

  # Send the user's SSH keys to jumphost
  common_verbose "Copy SSH key ${USER_AUTHORIZED_KEYS_FILE} to"\
                 "${JUMPHOST_PUBLIC_IP}:/tmp/${USER}_auth_keys..."

  # Set common SSH options
  SSH_OPTS=(
    -o StrictHostKeyChecking=no
    -o UserKnownHostsFile=/dev/null
    -i "${COMMON_OPT_KEYFILE_VALUE}"
  )

  common_run -- rsync -avz \
    -e "ssh ${SSH_OPTS[*]}" \
    "${USER_AUTHORIZED_KEYS_FILE}" \
    "${COMMON_OPT_USER_VALUE}@${JUMPHOST_PUBLIC_IP}:/tmp/${USER}_auth_keys" > /dev/null

  # Send the remote script to jumphost
  common_verbose "Copy ${JUMPHOST_SCRIPTS_DIR}/files/add_proxy_user.sh to"\
                 "${JUMPHOST_PUBLIC_IP}:/tmp/..."

  common_run -- rsync -avz \
    -e "ssh ${SSH_OPTS[*]}" \
    "${JUMPHOST_SCRIPTS_DIR}/files/add_proxy_user.sh" \
    "${COMMON_OPT_USER_VALUE}@${JUMPHOST_PUBLIC_IP}:/tmp/" > /dev/null

  # Execute the remote scrip
  common_verbose "Running the script with ${USER} /tmp/${USER}_auth_keys"

  common_run -- ssh \
    "${SSH_OPTS[@]}" \
    "${COMMON_OPT_USER_VALUE}"@"${JUMPHOST_PUBLIC_IP}" \
    /tmp/add_proxy_user.sh "${USER}" "/tmp/${USER}_auth_keys" > /dev/null

  echo "User[${USER}] updated"
}

USAGE=$(common_make_usage_string \
        --one-liner "Sync user information on the jumphost." \
        --arguments "<user>" \
        ${COMMON_OPT_DRYRUN} \
        ${COMMON_OPT_HELP} \
        ${COMMON_OPT_KEYFILE} \
        ${COMMON_OPT_PURGE} \
        ${COMMON_OPT_TARGET} \
        ${COMMON_OPT_USER} \
        ${COMMON_OPT_VERBOSE} \
        ${COMMON_OPT_KEEPUSERS})
common_parse_options "${USAGE}" "$@"

# Arguments
_USER=${COMMON_OPT_ARGUMENTS[0]:-"all"}

# Sanity checks
# =============
common_validate_target
common_validate_keyfile
common_validate_rturl
common_validate_user

if [[ "${COMMON_OPT_PURGE_VALUE}" == "true" ]]; then
  if [[ "${_USER}" == "all" ]]; then
    echo >&2 "Error: unable to purge all users"
    exit 1
  fi
  if [[ "${COMMON_OPT_KEEPUSERS_VALUE}" == "true" ]]; then
    echo >&2 "Error: 'purge' and 'keep-users' both set"
    exit 1
  fi
fi

export RT_URL="${COMMON_OPT_RTURL_VALUE}"
JUMPHOST_FLOATING_IP_TAG="${COMMON_OPT_TARGET_VALUE}_JUMPHOST_FLOATING_IP_TAG"

# Resolve jumphost's IP
common_verbose "Resolving public IP for a jumpost with tag"\
               "${!JUMPHOST_FLOATING_IP_TAG}"
JUMPHOST_PUBLIC_IP="$(get_jumphost_public_ip "${!JUMPHOST_FLOATING_IP_TAG}")"
if [[ -z "${JUMPHOST_PUBLIC_IP}" ]]; then
  echo >&2 "Error: no public IP found for a jumpost with tag"\
           "${!JUMPHOST_FLOATING_IP_TAG}"
  exit 1
fi
common_verbose "Jumphost public IP = ${JUMPHOST_PUBLIC_IP}"

if [[ "${COMMON_OPT_PURGE_VALUE}" == "false" ]]; then
  # Fetch list of users from artifactory
  common_verbose "Fetching user list from ${RT_URL}/${RT_USERS_DIR}..."
  ARTIFACTORY_USERS="$(rt_list_directory "${RT_USERS_DIR}" \
    | jq -r '.children[] | select(.folder==true) |.uri')"
else
  ARTIFACTORY_USERS=
fi

# Fetch list of current users in artifactory
common_verbose "Fetching user list via ssh ${COMMON_OPT_USER_VALUE}@${JUMPHOST_PUBLIC_IP}"
JUMPHOST_USERS="$(ssh \
  -o StrictHostKeyChecking=no \
  -o UserKnownHostsFile=/dev/null \
  -i "${COMMON_OPT_KEYFILE_VALUE}" \
  "${COMMON_OPT_USER_VALUE}@${JUMPHOST_PUBLIC_IP}" ls /home)"

# Iterate over all users in the artifactory
FOUND_USERS=()

for JH_USER in ${ARTIFACTORY_USERS}; do
  JH_USER=${JH_USER//\//}
  # If a user name is given, process only the specified user
  [[ -n "${_USER}" ]] && \
     [[ "${_USER}" != "all" ]] && \
     [[ "${JH_USER}" != "${_USER}" ]] && continue
  USER_KEY_FILE="$(mktemp)"
  common_verbose "Fetching public key for ${JH_USER}..."
  _USER_KEYS="$(rt_get_user_public_keys "${JH_USER}")"
  echo "${_USER_KEYS}" > "${USER_KEY_FILE}"
  common_verbose "Injecting public key for ${JH_USER}..."
  add_jumphost_user "${JH_USER}" "${USER_KEY_FILE}"
  rm -f "${USER_KEY_FILE}"
  FOUND_USERS+=("${JH_USER}")
done

# Remove users no longer in the artifactory but still on the jumphost
if [[ "${COMMON_OPT_KEEPUSERS_VALUE}" == "false" ]]; then
  for SSH_USER in ${JUMPHOST_USERS}; do

    # Don't remove the admin user
    if [[ "${COMMON_OPT_USER_VALUE}" == "${SSH_USER}" ]]; then
      continue
    fi

    # If a user name is given, process only the specified user
    [[ -n "${_USER}" ]] && \
    [[ "${_USER}" != "all" ]] && \
    [[ "${SSH_USER}" != "${_USER}" ]] && continue

    # If the user is no longer in the artifactory, remove the user
    if [[ ! " ${FOUND_USERS[*]} " =~ [[:space:]]${SSH_USER}[[:space:]] ]]; then
      common_verbose "Removing user ${SSH_USER}..."
      common_run -- ssh \
        -o StrictHostKeyChecking=no \
        -o UserKnownHostsFile=/dev/null \
        -i "${COMMON_OPT_KEYFILE_VALUE}" \
        "${COMMON_OPT_USER_VALUE}"@"${JUMPHOST_PUBLIC_IP}" \
        "sudo deluser --remove-all-files ${SSH_USER}"
    fi
  done
fi
