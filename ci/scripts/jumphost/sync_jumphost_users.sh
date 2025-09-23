#! /usr/bin/env bash

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
    USER_KEYS="$(printf '%s\n%s' "$(cat "${DIR}/${USER}/${_KEY}")" "${USER_KEYS}")"
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
  local USER USER_AUTHORIZED_KEYS_FILE

  USER=${1:?}
  USER_AUTHORIZED_KEYS_FILE=${2:?}
  shift 2
  OPTS=("${@:?}")

  # Send the user's SSH keys to jumphost
  common_verbose "Copy SSH key ${USER_AUTHORIZED_KEYS_FILE} to"\
                 "${JUMPHOST_PUBLIC_IP}:/tmp/${USER}_auth_keys..."

  common_run -- rsync -avz \
    -e "ssh ${OPTS[*]}" \
    "${USER_AUTHORIZED_KEYS_FILE}" \
    "${COMMON_OPT_USER_VALUE}@${JUMPHOST_PUBLIC_IP}:/tmp/${USER}_auth_keys" > /dev/null

  # Send the remote script to jumphost
  common_verbose "Copy ${JUMPHOST_SCRIPTS_DIR}/files/add_proxy_user.sh to"\
                 "${JUMPHOST_PUBLIC_IP}:/tmp/..."

  common_run -- rsync -avz \
    -e "ssh ${OPTS[*]}" \
    "${JUMPHOST_SCRIPTS_DIR}/files/add_proxy_user.sh" \
    "${COMMON_OPT_USER_VALUE}@${JUMPHOST_PUBLIC_IP}:/tmp/" > /dev/null

  # Execute the remote scrip
  common_verbose "Running the script with ${USER} /tmp/${USER}_auth_keys"

  common_run -- ssh \
    "${OPTS[@]}" \
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
SELECTED_USER=${COMMON_OPT_ARGUMENTS[0]:-"all"}

# Sanity checks
# =============
common_validate_target
common_validate_keyfile
common_validate_user

if [[ "${COMMON_OPT_PURGE_VALUE}" == "true" ]]; then
  if [[ "${SELECTED_USER}" == "all" ]]; then
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

# Iterate over the public key directory
FOUND_USERS=()

for USER in "${PUBLIC_KEY_DIR}/"*; do
  USER=$(basename "${USER}")
  # Not a user directory?
  if [[ "${USER}" == "*" ]] || [[ ! -d "${PUBLIC_KEY_DIR}/${USER}" ]]; then
    continue
  fi

  # If a user name is given, process only the specified user
  [[ -n "${SELECTED_USER}" ]] && \
     [[ "${SELECTED_USER}" != "all" ]] && \
     [[ "${USER}" != "${SELECTED_USER}" ]] && continue
  common_verbose "Retrieving public keys for ${USER}..."
  _USER_KEYS="$(get_user_public_keys "${PUBLIC_KEY_DIR}" "${USER}")"
  if [[ -z "${_USER_KEYS}" ]]; then
    common_verbose "User ${USER} doesn't have keys"
    continue
  fi
  USER_KEY_FILE="$(mktemp)"
  echo "${_USER_KEYS}" > "${USER_KEY_FILE}"
  common_verbose "Injecting public key for ${USER}..."
  add_jumphost_user "${USER}" "${USER_KEY_FILE}" "${SSH_OPTS[@]}"
  rm -f "${USER_KEY_FILE}"
  FOUND_USERS+=("${USER}")
done

# Remove users without public keys but still present on the jumphost
if [[ "${COMMON_OPT_KEEPUSERS_VALUE}" == "false" ]]; then
  for SSH_USER in ${JUMPHOST_USERS}; do

    # Paranoid: don't remove the admin user
    if [[ "${COMMON_OPT_USER_VALUE}" == "${SSH_USER}" ]]; then
      continue
    fi

    # If a user name is given, process only the specified user
    [[ -n "${SELECTED_USER}" ]] && \
    [[ "${SELECTED_USER}" != "all" ]] && \
    [[ "${SSH_USER}" != "${SELECTED_USER}" ]] && continue

    # If the user has no keys, remove the user
    if [[ ! " ${FOUND_USERS[*]} " =~ [[:space:]]${SSH_USER}[[:space:]] ]]; then
      common_verbose "Removing user ${SSH_USER}..."
      common_run -- ssh \
        "${SSH_OPTS[@]}" \
        "${COMMON_OPT_USER_VALUE}"@"${JUMPHOST_PUBLIC_IP}" \
        "sudo deluser --remove-all-files ${SSH_USER}"
    fi
  done
fi
