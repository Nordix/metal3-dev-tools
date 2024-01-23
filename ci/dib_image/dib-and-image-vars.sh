#!/usr/bin/env bash

set -eux

current_dir="$(dirname "$(readlink -f "${0}")")"

export ELEMENTS_PATH="${current_dir}/dib_elements"
export DIB_DEV_USER_USERNAME="metal3ci"
export DIB_DEV_USER_PWDLESS_SUDO="yes"
export DIB_DEV_USER_AUTHORIZED_KEYS="${current_dir}/id_ed25519_metal3ci.pub"
export DIB_RELEASE=9

if [[ "${IMAGE_OS}" == "ubuntu" ]]; then
  export DIB_RELEASE=jammy
else
  export DIB_RELEASE=9
fi 

# Set image names
commit_short="$(git rev-parse --short HEAD)"
image_date="$(date --utc +"%Y%m%dT%H%MZ")"

export FINAL_IMAGE_NAME="metal3-dev-ubuntu"
export IMAGE_NAME="${FINAL_IMAGE_NAME}-${image_date}-${commit_short}"