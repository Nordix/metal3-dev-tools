#!/usr/bin/env bash

set -euo pipefail

# Description:
# Reads all the users and their public keys.
# Create or update those users' keys on dev jumphost.
# Purge non-existing users (if not disabled).
#
#   Requires:
#     - source stackrc file
#     - openstack infra and jumphost should already be deployed
#
# Usage:
#   sync_jumphost_users.sh <user_name>
#

CI_DIR="$(dirname "$(readlink -f "${0}")")/../.."
JUMPHOST_SCRIPTS_DIR="${CI_DIR}/scripts/jumphost"
COMMON_SCRIPTS_DIR="${CI_DIR}/scripts/common"
OS_SCRIPTS_DIR="${CI_DIR}/scripts/openstack"

# shellcheck source=ci/scripts/common/opts.sh
. "${COMMON_SCRIPTS_DIR}/opts.sh"
# shellcheck source=ci/scripts/common/utils.sh
. "${COMMON_SCRIPTS_DIR}/utils.sh"
# shellcheck source=ci/scripts/openstack/utils.sh
. "${OS_SCRIPTS_DIR}/utils.sh"
# shellcheck source=ci/scripts/openstack/infra_defines.sh
. "${OS_SCRIPTS_DIR}/infra_defines.sh"
# shellcheck source=ci/scripts/jumphost/utils.sh
. "${JUMPHOST_SCRIPTS_DIR}/utils.sh"

# Description:
# Gets all the keys for a user from <directory>.
#
# Usage:
#   get_user_public_keys <directory> <username>
#
get_user_public_keys() {
  local USER DIR _KEY USER_KEYS

  DIR=${1:?}
  USER=${2:?}

  USER_KEYS=
  for _KEY in "${DIR}/${USER}/"*; do
    _KEY=$(basename "${_KEY}")
    if [[ "${_KEY}" == "*" ]]; then
      return
    fi
    USER_KEYS="$(printf '%s\n%s' \
      "$(cat "${DIR}/${USER}/${_KEY}")" "${USER_KEYS}")"
  done

  echo "${USER_KEYS}"
}

# Description:
# Replace the authorized keys file for a given user.
# If the user does not exist in the target host,
# the user will be created. The function takes
# also common SSH options as arguments.
#
# Usage:
#   add_jumphost_user <username> <authorized_keys_file> <opts>
#
add_jumphost_user() {
  local USER USER_AUTHORIZED_KEYS_FILE ARGS OPTS

  USER=${1:?}
  USER_AUTHORIZED_KEYS_FILE=${2:?}
  shift 2
  OPTS=("${@:?}")

  # Send the user's SSH keys to jumphost
  ARGS=(
    rsync
    -avz
    -e "ssh ${OPTS[*]}"
    "${USER_AUTHORIZED_KEYS_FILE}"
    "${COMMON_OPT_USER_VALUE}@${JUMPHOST_PUBLIC_IP}:/tmp/${USER}_auth_keys"
  )
  common_verbose "Copy SSH key ${USER_AUTHORIZED_KEYS_FILE} to"\
                 "${JUMPHOST_PUBLIC_IP}:/tmp/${USER}_auth_keys..."

  common_run -- "${ARGS[@]}" > /dev/null

  # Send the remote script to jumphost
  ARGS=(
    rsync -avz
    -e "ssh ${OPTS[*]}"
    "${JUMPHOST_SCRIPTS_DIR}/files/add_proxy_user.sh"
    "${COMMON_OPT_USER_VALUE}@${JUMPHOST_PUBLIC_IP}:/tmp/"
  )
  common_verbose "Copy ${JUMPHOST_SCRIPTS_DIR}/files/add_proxy_user.sh to"\
                 "${JUMPHOST_PUBLIC_IP}:/tmp/..."

  common_run -- "${ARGS[@]}" > /dev/null

  # Execute the remote script
  ARGS=(
    ssh
    "${OPTS[@]}"
    "${COMMON_OPT_USER_VALUE}"@"${JUMPHOST_PUBLIC_IP}"
    /tmp/add_proxy_user.sh "${USER}" "/tmp/${USER}_auth_keys"
  )
  common_verbose "Running the script with ${USER} /tmp/${USER}_auth_keys"

  common_run -- "${ARGS[@]}" > /dev/null

  echo "User[${USER}] updated"
}

# Description:
# Check if the given user matches with the user given as an argument
# (ARG_USER), which may also not be set or is 'all'.
#
# For safety reasons if the user matches with the admin user the
# function return always "false" in order to prevent actions on the
# admin user account.
#
# The function returns "true" in case of a match otherwise "false" is
# returned.
#
# Usage:
#   is_selected_user <user_to_match>
#
is_selected_user() {
  local USER

  USER=${1:?}

  # Paranoid: exclude the admin user
  if [[ "${COMMON_OPT_USER_VALUE}" == "${USER}" ]]; then
    echo "false"
    return
  fi

  if [[ -n "${ARG_USER}" ]] \
     && [[ "${ARG_USER}" != "all" ]] \
     && [[ "${USER}" != "${ARG_USER}" ]]; then
    echo "false"
    return
  fi

  echo "true"
}

# Description:
# Remove a specified SSH user from the jumphost.
#
# Usage:
#   remove_ssh_user <user_to_remove>
#
remove_ssh_user() {
  local SSH_USER ARGS

  SSH_USER=${1:?}

  ARGS=(
    ssh
    "${SSH_OPTS[@]}"
    "${COMMON_OPT_USER_VALUE}"@"${JUMPHOST_PUBLIC_IP}"
    "sudo deluser --remove-all-files ${SSH_USER}"
  )
  common_verbose "Removing user ${SSH_USER}..."
  common_run -- "${ARGS[@]}"
}

# Description:
# Process users in the jumphost.
#
# If USERS list was specified, this function will remove either
# a single user that is not on the USERS list if the user was specified on the
# command line. If no user or 'all' users was specified on the command line,
# this function will remove all such users that are not on the USERS list.
#
# If no list of USERS is given, only the selected user(s) will be removed.
#
# Usage:
#   remove_ssh_users <user_list>
#
remove_ssh_users() {
  local USERS SSH_USER

  USERS=${1:-}

  for SSH_USER in ${JUMPHOST_USERS}; do

    # If a user name is given, process only the specified user
    if [[ "$(is_selected_user "${SSH_USER}")" == "false" ]]; then
      continue
    fi

    if [[ -z "${USERS}" ]] \
       || [[ ! " ${USERS[*]} " =~ [[:space:]]${SSH_USER}[[:space:]] ]]; then
      remove_ssh_user "${SSH_USER}"
    fi
  done
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
ARG_USER=${COMMON_OPT_ARGUMENTS[0]:-"all"}

# Sanity checks
# =============
common_validate_target
common_validate_keyfile
common_validate_user

if [[ "${COMMON_OPT_PURGE_VALUE}" == "true" ]]; then
  if [[ "${ARG_USER}" == "all" ]]; then
    echo >&2 "Error: unable to purge all users"
    exit 1
  fi
  if [[ "${COMMON_OPT_KEEPUSERS_VALUE}" == "true" ]]; then
    echo >&2 "Error: 'purge' and 'keep-users' both set"
    exit 1
  fi
fi

PUBLIC_KEY_DIR="${CI_DIR}/scripts/public_keys"
if [[ ! -d "${PUBLIC_KEY_DIR}" ]]; then
  echo >&2 "Error: public key directory '${PUBLIC_KEY_DIR}' not available"
  exit 1
fi

# Set common SSH options
SSH_OPTS=(
  -o StrictHostKeyChecking=no
  -o UserKnownHostsFile=/dev/null
  -i "${COMMON_OPT_KEYFILE_VALUE}"
)

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

# Get a list of jumphost users by fetching all members of the
# PROXY_USERS_GROUP group
PROXY_USERS_GROUP="proxy_users"
CMD="for user in \$(awk -F: '{print \$1}' /etc/passwd); do groups \$user; "
CMD+="done | grep '${PROXY_USERS_GROUP}' | cut -d ' ' -f 1"
common_verbose "Fetching jumphost users via ssh"\
               "${COMMON_OPT_USER_VALUE}@${JUMPHOST_PUBLIC_IP}"
# shellcheck disable=SC2029
JUMPHOST_USERS="$(ssh \
  "${SSH_OPTS[@]}" \
  "${COMMON_OPT_USER_VALUE}@${JUMPHOST_PUBLIC_IP}" \
  "${CMD}")"

# Purge users?
if [[ "${COMMON_OPT_PURGE_VALUE}" == "true" ]]; then
  remove_ssh_users
  exit 0
fi

# Iterate over the public key directory
FOUND_USERS=()
for USER in "${PUBLIC_KEY_DIR}/"*; do

  # Extract the username
  USER=$(basename "${USER}")

  # Not a user directory?
  if [[ "${USER}" == "*" ]] || [[ ! -d "${PUBLIC_KEY_DIR}/${USER}" ]]; then
    continue
  fi

  # If a user name is given, process only the specified user
  if [[ "$(is_selected_user "${USER}")" == "false" ]]; then
    continue
  fi

  common_verbose "Retrieving public keys for ${USER}..."
  _USER_KEYS="$(get_user_public_keys "${PUBLIC_KEY_DIR}" "${USER}")"
  if [[ -z "${_USER_KEYS}" ]]; then
    common_verbose "User ${USER} doesn't have keys"
    continue
  fi

  common_verbose "Injecting public key for ${USER}..."
  USER_KEY_FILE="$(mktemp)"
  echo "${_USER_KEYS}" > "${USER_KEY_FILE}"
  add_jumphost_user "${USER}" "${USER_KEY_FILE}" "${SSH_OPTS[@]}"
  rm -f "${USER_KEY_FILE}"
  FOUND_USERS+=("${USER}")
done

# Remove users without public keys but still present on the jumphost
if [[ "${COMMON_OPT_KEEPUSERS_VALUE}" == "false" ]]; then
  remove_ssh_users "${FOUND_USERS[*]}"
fi
