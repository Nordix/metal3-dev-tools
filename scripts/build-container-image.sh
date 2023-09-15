#!/usr/bin/env bash

# This script is meant to be used by CI, to build and push container images to the container hub.
# However, it can be used by human on a linux environment, with the following requirements:
#  - An existing credentials towards the hub, with push and delete permissions.
#  - Needed tools (git, docker, curl, etc. are installed)

set -eu

set -o pipefail

HUB="quay.io"
REPO="metal3-io"
IMAGE_NAME=$1
BRANCH_NAME=${2:-main}
KEEP_TAGS=${3:-3}
REPO_LOCATION="/tmp/metal3-io"
NEEDED_TOOLS=("git" "curl" "docker" "jq")
__dir__=$(realpath "$(dirname "$0")")
IMAGES_JSON="${__dir__}/files/container_image_names.json"

check_tools() {
  for tool in "${NEEDED_TOOLS[@]}"; do
    type "${tool}" > /dev/null
  done
}

list_tags() {
  curl -s "https://${HUB}/v2/${REPO}/${IMAGE_NAME}/tags/list" | jq -r '.tags[]'
}

get_tag_sha256() {
  tag=${1:?}
  SHA_REQ=$(curl -s -H "Accept: application/vnd.docker.distribution.manifest.v2+json" "https://${HUB}/v2/${REPO}/${IMAGE_NAME}/manifests/${tag}" | jq -r '.config.digest')
  SHA=$(echo "${SHA_REQ}" | cut -f 2- -d ":" | tr -d '[:space:]')
  echo "${SHA}"
}

delete_tag() {
  # Untested
  tag=${1:?}
  sha256=$(get_tag_sha256 "${tag}")
  curl -X DELETE -s "https://${HUB}/v2/${REPO}/${IMAGE_NAME}/manifests/${sha256}"
}

git_get_current_commit_short_hash() {
  git rev-parse --short HEAD
}

git_get_current_branch() {
  git rev-parse --abbrev-ref HEAD
}

get_date() {
  # Should this be current date, or latest commit date?
  date +%Y%m%d
}

get_image_tag() {
  echo "$(git_get_current_branch)_$(get_date)_$(git_get_current_commit_short_hash)"
}

cleanup_old_tags() {
  all_tags=$(list_tags)
  branch=$(git_get_current_branch)

  declare -a branch_tags=()

  for tag in "${all_tags[@]}"; do
    if [[ "${tag}" == "${branch}_20"* ]]; then
      branch_tags+=("${tag}")
    fi
  done
  IFS=$'\n' sorted_existing_tags=("$(sort <<<"${branch_tags[*]}")")
  number_of_tags=${#sorted_existing_tags[@]}
  if [[ ${number_of_tags} -gt ${KEEP_TAGS} ]]; then
    for i in $(seq 0 $(( number_of_tags - KEEP_TAGS - 1 ))); do
      echo "Deleting tag: ${sorted_existing_tags[$i]}"
      delete_tag "${sorted_existing_tags[$i]}"
    done
  fi
}

get_image_latest_tag() {
  echo "$(git_get_current_branch)_latest"
}

get_image_path() {
  image_tag=${1:?}
  echo "${HUB}/${REPO}/${IMAGE_NAME}:${image_tag}"
}

build_container_image() {
  image_tag=$(get_image_tag)
  image_latest_tag=$(get_image_latest_tag)
  image_path=$(get_image_path "${image_tag}")
  image_latest_path=$(get_image_path "${image_latest_tag}")
  docker build -t "${image_path}" .
  docker push "${image_path}"
  docker tag "${image_path}" "${image_latest_path}"
  docker push "${image_latest_path}"
}

build_image() {
  if [[ $(jq < "${IMAGES_JSON}" .\""${IMAGE_NAME}"\") == "null" ]]; then
    echo "Error: No such image ${IMAGE_NAME}"
    exit 1
  fi
  repo_link=$(jq < "${IMAGES_JSON}" -r .\""${IMAGE_NAME}"\".repo)
  repo_name=$(jq < "${IMAGES_JSON}"  -r .\""${IMAGE_NAME}"\".repo_name)
  mkdir -p "${REPO_LOCATION}"
  cd "${REPO_LOCATION}"
  rm -rf "${repo_name}"
  git clone "${repo_link}" "${repo_name}"
  dockerfile_directory=$(jq < "${IMAGES_JSON}" -r .\""${IMAGE_NAME}"\".dockerfile_location)
  cd "${repo_name}"
  git checkout "${BRANCH_NAME}"
  cd "${REPO_LOCATION}/${repo_name}${dockerfile_directory}"
  build_container_image
}

check_tools
build_image
cleanup_old_tags
