#! /usr/bin/env bash

# ================ Generic Artifactory Helper Functions ===============

# Description:
# Adds a new artifact in artifactory at a given path.
#
# Anonymous flag is set to perform all operations anonymously.
# If anonymous flag is not set then credentials should be set
# in the following environment variables.
#   RT_USER: artifactory user name.
#   RT_TOKEN: artifactory password or api token
#
# Usage:
#   rt_upload_artifact <src_file_path> <dest_file_path> <anonymous:0/1>
#
rt_upload_artifact() {
  SRC_PATH="${1:?}"
  DST_PATH="${2:?}"
  ANONYMOUS="${3:-1}"

  _CMD="curl \
    $( ([[ "${ANONYMOUS}" != 1 ]] && echo " -u${RT_USER:?}:${RT_TOKEN:?}") || true) \
    ${RT_URL}/${DST_PATH} \
    -T ${SRC_PATH}"

  eval "${_CMD}"
}

# Description:
# Download artifact from artifactory.
#
# Anonymous flag is set to perform all operations anonymously.
# If anonymous flag is not set then credentials should be set
# in the following environment variables.
#   RT_USER: artifactory user name.
#   RT_TOKEN: artifactory password or api token
#
# Usage:
#   rt_download_artifact <src_file_path> <dest_file_path> <anonymous:0/1>
#
rt_download_artifact() {
  SRC_PATH="${1:?}"
  DST_PATH="${2:?}"
  ANONYMOUS="${3:-1}"

  _CMD="curl -s \
    $( ([[ "${ANONYMOUS}" != 1 ]] && echo " -u${RT_USER:?}:${RT_TOKEN:?}") || true) \
    -XGET \
    ${RT_URL}/${SRC_PATH} \
    -o ${DST_PATH}"

  eval "${_CMD}"
}

# Description:
# Download artifact from artifactory and dumps it on stdout.
#
# Anonymous flag is set to perform all operations anonymously.
# If anonymous flag is not set then credentials should be set
# in the following environment variables.
#   RT_USER: artifactory user name.
#   RT_TOKEN: artifactory password or api token
#
# Usage:
#   rt_cat_artifact <src_file_path> <anonymous:0/1>
#
rt_cat_artifact() {
  SRC_PATH="${1:?}"
  ANONYMOUS="${2:-1}"

  _CMD="curl -s \
    $( ([[ "${ANONYMOUS}" != 1 ]] && echo " -u${RT_USER:?}:${RT_TOKEN:?}") || true) \
    -XGET \
    ${RT_URL}/${SRC_PATH}"

  eval "${_CMD}"
}

# Description:
# Delete artifact from artifactory.
#
# Anonymous flag is set to perform all operations anonymously.
# If anonymous flag is not set then credentials should be set
# in the following environment variables.
#   RT_USER: artifactory user name.
#   RT_TOKEN: artifactory password or api token
#
# Usage:
#   rt_cat_artifact <dst_file_path> <anonymous:0/1>
#
rt_delete_artifact() {
  DST_PATH="${1:?}"
  ANONYMOUS="${2:-1}"

  _CMD="curl -s \
    $( ([[ "${ANONYMOUS}" != 1 ]] && echo " -u${RT_USER:?}:${RT_TOKEN:?}") || true) \
    -XDELETE \
    ${RT_URL}/${DST_PATH}"

  eval "${_CMD}" > /dev/null 2>&1
}

# Description:
# Lists a directory in artifactory. The result is the json
# dump of artifactory response.
#
# Anonymous flag is set to perform all operations anonymously.
# If anonymous flag is not set then credentials should be set
# in the following environment variables.
#   RT_USER: artifactory user name.
#   RT_TOKEN: artifactory password or api token
#
# Usage:
#   rt_list_directory <dst_dir_path> <anonymous:0/1>
#
rt_list_directory() {
  DST_PATH="${1:?}"
  ANONYMOUS="${2:-1}"

  _CMD="curl -s \
    $( ([[ "${ANONYMOUS}" != 1 ]] && echo " -u${RT_USER:?}:${RT_TOKEN:?}") || true) \
    -XGET \
    ${RT_URL}/api/storage/${DST_PATH}"

  eval "${_CMD}"
}

# ================ Users Artifactory Helper Functions ===============

RT_AIRSHIP_DIR="airship"
RT_USERS_DIR="${RT_AIRSHIP_DIR}/users"

# Description:
# Gets all the keys for a user from airship/users/<username>
# directory.
#
# Usage:
#   rt_get_user_public_keys <username>
#
rt_get_user_public_keys() {

  USER="${1:?}"
  USER_KEY_FILES="$(rt_list_directory "${RT_USERS_DIR}/${USER}" \
    | jq -r '.children[]? |select(.folder==false) |.uri')" > /dev/null 2>&1

  USER_KEYS=""
  for PUB_KEY_FILE in ${USER_KEY_FILES}
  do
    _KEY="$(rt_cat_artifact "${RT_USERS_DIR}/${USER}${PUB_KEY_FILE}")"
    USER_KEYS="$(printf '%s\n%s' "${USER_KEYS}" "${_KEY}")"
  done

  echo "${USER_KEYS}"
}

# Description:
# Adds a user public key in airship/users/<username>/<key_name>
#
# Credentials should be set in the following environment variables.
#   RT_USER: artifactory user name.
#   RT_TOKEN: artifactory password or api token
#
# Usage:
#   rt_add_user_public_key <user> <public_key_name> <public_key>
#
rt_add_user_public_key() {

  USER="${1:?}"
  USER_PUB_KEY_NAME="${2:?}"
  USER_PUB_KEY="${3:?}"

  USER_PUB_KEY_FILE="$(mktemp)"
  echo "${USER_PUB_KEY}" > "${USER_PUB_KEY_FILE}"

  rt_upload_artifact "${USER_PUB_KEY_FILE}" "${RT_USERS_DIR}/${USER}/${USER_PUB_KEY_NAME}" 0
}

# Description:
# Deletes a user public key in airship/users/<username>/<key_name>
#
# Credentials should be set in the following environment variables.
#   RT_USER: artifactory user name.
#   RT_TOKEN: artifactory password or api token
#
# Usage:
#   rt_del_user_public_key <user> <public_key_name>
#
rt_del_user_public_key() {

  USER="${1:?}"
  USER_PUB_KEY_NAME="${2:?}"

  USER_KEY_STAT="$(rt_list_directory "${RT_USERS_DIR}/${USER}/${USER_PUB_KEY_NAME}" \
    | jq -r '.children[]? |select(.folder==false) |.uri')" > /dev/null 2>&1

  if [ -n "${USER_KEY_STAT}" ]
  then
    rt_delete_artifact "${RT_USERS_DIR}/${USER}/${USER_PUB_KEY_NAME}" 0
  fi

  # Delete the user directory if there are no more keys
  KEYS="$(rt_get_user_public_keys "test")"

  if [ -z "${KEYS}" ]
  then
    rt_delete_artifact "${RT_USERS_DIR}/${USER}" 0
  fi
}
