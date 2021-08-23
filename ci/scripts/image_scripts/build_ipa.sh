#!/bin/bash
# Set execution parameters to:
# Fail whenever any command fails
set -eu

# Configurable options
DISABLE_UPLOAD="${DISABLE_UPLOAD:-false}"
IPA_BUILD_WORKSPACE="${IPA_BUILD_WORKSPACE:-/tmp/dib}"
RT_UTILS="${RT_UTILS:-/tmp/utils.sh}"
RT_URL="${RT_URL:-https://artifactory.nordix.org/artifactory}"
IPA_BUILDER_PATH="ironic-python-agent-builder"
IPA_IMAGE_NAME="${IPA_IMAGE_NAME:-ironic-python-agent}"
IPA_IMAGE_TAR="${IPA_IMAGE_NAME}.tar"
IPA_BUILDER_REPO="${IPA_BUILDER_REPO:-https://github.com/Nordix/ironic-python-agent-builder.git}"
IPA_BUILDER_BRANCH="${IPA_BUILDER_BRANCH:-master}"
IPA_REPO="${IPA_REPO:-https://github.com/Nordix/ironic-python-agent}"
IPA_REF="${IPA_REPO_REF:-master}"
IPA_BRANCH="${IPA_BRANCH:-master}"
IPA_BASE_OS="${IPA_BASE_OS:-centos}"
IPA_BASE_OS_RELEASE="${IPA_BASE_OS_RELEASE:-8-stream}"
OPENSTACK_REQUIREMENTS_REF="${OPENSTACK_REQUIREMENTS_REF:-master}"
IRONIC_SIZE_LIMIT_MB=500
# Install required packages
sudo apt install --yes python3-pip python3-virtualenv qemu-utils

# Create the work directory
mkdir --parents "${IPA_BUILD_WORKSPACE}"
cd "${IPA_BUILD_WORKSPACE}"

# Pull IPA builder repository
git clone --single-branch --branch "${IPA_BUILDER_BRANCH}" "${IPA_BUILDER_REPO}"

# Pull IPA repository to create IPA_IDENTIFIER
git clone --single-branch --branch "${IPA_REF}" "${IPA_REPO}"

# Generate the IPA image identifier string
cd "ironic-python-agent"
# IDENTIFIER is the git commit of the HEAD and the ISO 8061 UTC timestamp
IPA_IDENTIFIER="$(date --utc +"%Y%m%dT%H%MZ")-$(git rev-parse HEAD)"
echo "IPA_IDENTIFIER is the following:${IPA_IDENTIFIER}"
cd ..

# Install the cloned IPA builder tool
virtualenv venv
# shellcheck source=/dev/null
source "./venv/bin/activate"
python3 -m pip install --upgrade pip
python3 -m pip install "./${IPA_BUILDER_PATH}"

# Configure the IPA builder to pull the IPA source from Nordix fork
export DIB_REPOLOCATION_ironic_python_agent="${IPA_REPO}"
export DIB_REPOREF_requirements="${OPENSTACK_REQUIREMENTS_REF}"
export DIB_REPOREF_ironic_python_agent="${IPA_REF}"

# Build the IPA initramfs and kernel images
ironic-python-agent-builder --output "${IPA_IMAGE_NAME}" \
    --release "${IPA_BASE_OS_RELEASE}" "${IPA_BASE_OS}" \
    --element='dynamic-login' --element='journal-to-console' \
    --element='devuser' --element='openssh-server' \
    --element='extra-hardware' --verbose

# Package the initramfs and kernel images to a tar archive
tar --create --verbose --file="${IPA_IMAGE_TAR}" \
    "./${IPA_IMAGE_NAME}.kernel" \
    "./${IPA_IMAGE_NAME}.initramfs"

# Check the size of the archive
filesize=$(stat --printf="%s" /tmp/dib/ironic-python-agent.tar)
size_domain_offset=1024
filesize_MB=$((filesize / size_domain_offset / size_domain_offset))
echo "Size of the archive: ${filesize_MB}MB"
if [ ${filesize_MB} -ge ${IRONIC_SIZE_LIMIT_MB} ]; then
    exit 1
fi

# Upload the newly built image
if ! $DISABLE_UPLOAD ; then
    # shellcheck source=/dev/null
    source "${RT_UTILS}"
    DST_PATH="airship/images/ipa/centos/${IPA_IDENTIFIER}/${IPA_IMAGE_NAME}"
    rt_upload_artifact  "${IPA_IMAGE_TAR}" "${DST_PATH}" "0"
fi
