#! /usr/bin/env bash

# ================ Generic Artifactory Helper Functions ===============

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

rt_cat_artifact() {
  SRC_PATH="${1:?}"
  ANONYMOUS="${2:-1}"

  _CMD="curl -s \
    $( ([[ "${ANONYMOUS}" != 1 ]] && echo " -u${RT_USER:?}:${RT_TOKEN:?}") || true) \
    -XGET \
    ${RT_URL}/${SRC_PATH}"

  eval "${_CMD}"
}

rt_delete_artifact() {
  DST_PATH="${1:?}"
  ANONYMOUS="${2:-1}"

  _CMD="curl -s \
    $( ([[ "${ANONYMOUS}" != 1 ]] && echo " -u${RT_USER:?}:${RT_TOKEN:?}") || true) \
    -XDELETE \
    ${RT_URL}/${DST_PATH}"

  eval "${_CMD}"
}

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

rt_get_user_public_keys() {

  USER="${1:?}"
  USER_KEY_FILES="$(rt_list_directory "${RT_USERS_DIR}/${USER}" \
    | jq -r '.children[] |select(.folder==false) |.uri')"

  USER_KEYS=""
  for PUB_KEY_FILE in ${USER_KEY_FILES}
  do
    _KEY="$(rt_cat_artifact "${RT_USERS_DIR}/${USER}${PUB_KEY_FILE}")"
    USER_KEYS="$(printf '%s\n%s' "${USER_KEYS}" "${_KEY}")"
  done

  echo "${USER_KEYS}"
}

rt_add_user_public_key() {

  USER="${1:?}"
  USER_PUB_KEY_NAME="${2:?}"
  USER_PUB_KEY="${3:?}"

  USER_PUB_KEY_FILE="$(mktemp)"
  echo "${USER_PUB_KEY}" > "${USER_PUB_KEY_FILE}"

  rt_upload_artifact "${USER_PUB_KEY_FILE}" "${RT_USERS_DIR}/${USER}/${USER_PUB_KEY_NAME}" 0
}

rt_del_user_public_key() {

  USER="${1:?}"
  USER_PUB_KEY_NAME="${2:?}"

  rt_delete_artifact "${RT_USERS_DIR}/${USER}/${USER_PUB_KEY_NAME}" 0
}
