#! /usr/bin/env bash

CI_DIR="$(dirname "$(readlink -f "${0}")")/../.."
COMMON_SCRIPTS_DIR="${CI_DIR}/scripts/common"

# shellcheck source=ci/scripts/common/utils.sh
. "${COMMON_SCRIPTS_DIR}/utils.sh"

# Artifactory configuration
RT_METAL3_DIR="metal3"
RT_USERS_DIR="${RT_METAL3_DIR}/users"

# ================ Generic Artifactory Helper Functions ===============

# Description:
# Adds a new artifact in artifactory at a given path.
#
# Anonymous flag is set to perform all operations anonymously.
# If anonymous flag is not set then credentials should be set
# in the following environment variables.
#   RT_USER: artifactory user name.
#   RT_TOKEN: artifactory password or api token
#   RT_URL: Artifactory URL
#
# Usage:
#   rt_upload_artifact <src_file_path> <dest_file_path> <anonymous:0/1>
#
rt_upload_artifact() {
  local SRC_PATH DST_PATH ANONYMOUS ARGS

  SRC_PATH="${1:?}"
  DST_PATH="${2:?}"
  ANONYMOUS="${3:-1}"

  ARGS=(
    -T "${SRC_PATH}"
  )
  [[ "${ANONYMOUS}" != 1 ]] && { ARGS+=("-u${RT_USER:?}:${RT_TOKEN:?}"); }

  common_verbose "Upload artifact: ${SRC_PATH},${DST_PATH},${ANONYMOUS}"
  common_run -- curl "${ARGS[@]}" "${RT_URL}/${DST_PATH}"
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

  common_verbose "Download artifact: ${SRC_PATH},${DST_PATH},${ANONYMOUS}"
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

  common_verbose "Cat artifact: ${SRC_PATH},${ANONYMOUS}"
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
#   rt_delete_artifact <dst_file_path> <anonymous:0/1>
#
rt_delete_artifact() {
  local DST_PATH ANONYMOUS

  DST_PATH="${1:?}"
  ANONYMOUS="${2:-1}"

  ARGS=(
    -s
    -XDELETE
  )
  [[ "${ANONYMOUS}" != 1 ]] && { ARGS+=("-u${RT_USER:?}:${RT_TOKEN:?}"); }

  common_verbose "Delete artifact: ${DST_PATH},${ANONYMOUS}"
  common_run -- curl "${ARGS[@]}" "${RT_URL}/${DST_PATH}"
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

  common_verbose "List artifact: ${DST_PATH},${ANONYMOUS}"
  _CMD="curl -s \
    $( ([[ "${ANONYMOUS}" != 1 ]] && echo " -u${RT_USER:?}:${RT_TOKEN:?}") || true) \
    -XGET \
    ${RT_URL}/api/storage/${DST_PATH}"

  eval "${_CMD}"
}

# Description:
# Deletes the artifacts in a directory. The function excludes the last x number of
# artifacts from deletion where x is specified by the 3rd argument. The artifacts
# specified in the file that's path is passed as the second argument will be also
# excluded from deletion.
#    DIR_TO_CLEAN: the directory where the artifact deletion will take place.
#    ANONYMOUS: enable/disable anonymous artifactory access
#    PINNED_ARTIFACTS: a file path that points to a text file that contains the
#        list artifact in "DIR_TO_CLEAN" that should not be deleted.
#    RETENTION_NUM: in addition to the artifacts specified in "PINNED_ARTIFACTS"
#        the newest x number of artifacts should be kept in the directory.
#    DRY_RUN: boolean that makes the function print out the name of the artifacts
#        instead of cleaning them.
#
#    Note: By default only the "DIR_TO_CLEAN" is requird. As the default behaviour
#        "DIR_TO_CLEAN" will be cleaned and the last 10 artifact will be excluded from deletion.
#
#    Note: The function expects artifacts to have unique timestamp in their names. Timestamp
#       format that is recommended could be created in bash with this command: "date --utc +"%Y%m%dT%H%MZ".
#
#    Usage:
#      delete_multiple_artifacts <dir_to_clean> <anonymous:0/1> <dry_run:false/true> <pinned_artifacts_path> <retention_num>
#
rt_delete_multiple_artifacts() {
  DIR_TO_CLEAN="${1:?}"
  ANONYMOUS="${2:-0}"
  DRY_RUN="${3:-false}"
  PINNED_ARTIFACTS="${4:-/dev/null}"
  RETENTION_NUM="${5:-10}"

  # Create an array of the artifacts that should be deleted
  mapfile -t < <(rt_list_directory "${DIR_TO_CLEAN}" "${ANONYMOUS}" |\
    jq '.children | .[] | .uri' | \
    sed -e 's/\"\/\([^"]*\)"/\1/g' | \
    diff --suppress-common-lines - "${PINNED_ARTIFACTS}" | \
    sed -ne 's/< //p' | \
    head -n "-${RETENTION_NUM}")

  # Delete the artifacts
  for item in "${MAPFILE[@]}"
  do
    if "${DRY_RUN}"; then
      echo "INFO:DRY_RUN:${DIR_TO_CLEAN}/${item} has been deleted!"
    else
      rt_delete_artifact "${DIR_TO_CLEAN}/${item}" "${ANONYMOUS}"
      echo "INFO:${DIR_TO_CLEAN}/${item} has been deleted!"
    fi
  done
}

# ================ Users Artifactory Helper Functions ===============

# Description:
# Gets all the keys for a user from metal3/users/<username>
# directory. If `keyname` is set 1, also the keyname will
# be included in the output.
#
# Usage:
#   rt_get_user_public_keys <username> <keyname:0/1>
#
rt_get_user_public_keys() {

  USER="${1:?}"
  KEYNAME="${2:-0}"
  USER_KEY_FILES="$(rt_list_directory "${RT_USERS_DIR}/${USER}" \
    | jq -r '.children[]? |select(.folder==false) |.uri')" > /dev/null 2>&1

  USER_KEYS=""
  for PUB_KEY_FILE in ${USER_KEY_FILES}
  do
    _KEY="$(rt_cat_artifact "${RT_USERS_DIR}/${USER}${PUB_KEY_FILE}")"
    NAME=
    [[ ${KEYNAME} -eq 1 ]] && { NAME="${PUB_KEY_FILE//\//}: "; }
    USER_KEYS="$(printf '%s\n%s' "${USER_KEYS}" "${NAME}${_KEY}")"
  done

  echo "${USER_KEYS}"
}

# Description:
# Adds a user public key in metal3/users/<username>/<key_name>
#
# Credentials should be set in the following environment variables.
#   RT_USER: artifactory user name.
#   RT_TOKEN: artifactory password or api token
#
# Usage:
#   rt_add_user_public_key <user> <public_key_name> <public_key_file>
#
rt_add_user_public_key() {

  USER="${1:?}"
  USER_PUB_KEY_NAME="${2:?}"
  USER_PUB_KEY="${3:?}"

  USER_PUB_KEY_FILE="$(mktemp)"
  cat "${USER_PUB_KEY}" > "${USER_PUB_KEY_FILE}"

  rt_upload_artifact "${USER_PUB_KEY_FILE}" "${RT_USERS_DIR}/${USER}/${USER_PUB_KEY_NAME}" 0
  rm -f "${USER_PUB_KEY_FILE}"
}

# Description:
# Deletes a user public key in metal3/users/<username>/<key_name>
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
    | jq -r '.uri')" > /dev/null 2>&1

  if [ "${USER_KEY_STAT}" != "null" ]
  then
    rt_delete_artifact "${RT_USERS_DIR}/${USER}/${USER_PUB_KEY_NAME}" 0
  else
    common_verbose "No such key: ${RT_USERS_DIR}/${USER}/${USER_PUB_KEY_NAME}"
    return
  fi

  # Delete the user directory if there are no more keys
  KEYS="$(rt_get_user_public_keys "${USER}")"

  # Dry-mode will not detect an empty directory because the key is
  # still in the artifactory
  if [ -z "${KEYS}" ]
  then
    rt_delete_artifact "${RT_USERS_DIR}/${USER}" 0
  else
    common_verbose "Retaining artifact ${RT_USERS_DIR}/${USER}"
  fi
}
