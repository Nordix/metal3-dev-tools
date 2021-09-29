#!/bin/bash
# Set execution parameters to:
# Fail whenever any command fails
set -eu

# Repository configuration options
METAL3_DEV_ENV_REPO="https://github.com/metal3-io/metal3-dev-env"
METAL3_DEV_ENV_BRANCH="${METAL3_DEV_ENV_BRANCH:-master}"
METAL3_DEV_ENV_COMMIT="${METAL3_DEV_ENV_COMMIT:-HEAD}"
IPA_REPO="${IPA_REPO:-https://github.com/Nordix/ironic-python-agent}"
IPA_BRANCH="${IPA_BRANCH:-master}"
IPA_COMMIT="${IPA_COMMIT:-HEAD}"
IPA_BUILDER_REPO="${IPA_BUILDER_REPO:-https://github.com/Nordix/ironic-python-agent-builder.git}"
IPA_BUILDER_BRANCH="${IPA_BUILDER_BRANCH:-master}"
IPA_BUILDER_COMMIT="${IPA_BUILDER_COMMIT:-HEAD}"
IPA_BUILD_WORKSPACE="${IPA_BUILD_WORKSPACE:-/tmp/dib}"
OPENSTACK_REQUIREMENTS_REF="${OPENSTACK_REQUIREMENTS_REF:-master}"
BMO_BRANCH="${BMO_BRANCH:-master}"
BMO_COMMIT="${BMO_COMMIT:-HEAD}"

# General environment variables
DISABLE_UPLOAD="${DISABLE_UPLOAD:-false}"
RT_UTILS="${RT_UTILS:-/tmp/utils.sh}"
RT_URL="${RT_URL:-https://artifactory.nordix.org/artifactory}"
IPA_BUILDER_PATH="ironic-python-agent-builder"
IPA_IMAGE_NAME="${IPA_IMAGE_NAME:-ironic-python-agent}"
IPA_IMAGE_TAR="${IPA_IMAGE_NAME}.tar"
IPA_BASE_OS="${IPA_BASE_OS:-centos}"
IPA_BASE_OS_RELEASE="${IPA_BASE_OS_RELEASE:-8-stream}"
IRONIC_SIZE_LIMIT_MB=500
ENABLE_BOOTSTRAP_TEST="${ENABLE_BOOTSTRAP_TEST:-true}"
DEV_ENV_REPO_LOCATION="${DEV_ENV_REPO_LOCATION:-/tmp/dib/metal3-dev-env}"
IMAGE_REGISTRY="registry.nordix.org"
CONTAINER_IMAGE_REPO="airship"
STAGING="${STAGING:-false}"
METADATA_PATH="/tmp/metadata.txt"

# Install required packages
sudo apt install --yes python3-pip python3-virtualenv qemu-utils

# Create the work directory
mkdir --parents "${IPA_BUILD_WORKSPACE}"
cd "${IPA_BUILD_WORKSPACE}"

# Pull IPA builder repository
git clone --single-branch --branch "${IPA_BUILDER_BRANCH}" "${IPA_BUILDER_REPO}"
pushd "./ironic-python-agent-builder"
git checkout "${IPA_BUILDER_COMMIT}"
IPA_BUILDER_COMMIT="$(git rev-parse  HEAD)"
popd

# Pull IPA repository to create IPA_IDENTIFIER
git clone --single-branch --branch "${IPA_BRANCH}" "${IPA_REPO}"

# Generate the IPA image identifier string
pushd "./ironic-python-agent"
# IDENTIFIER is the git commit of the HEAD and the ISO 8061 UTC timestamp
git checkout "${IPA_COMMIT}"
IPA_COMMIT="$(git rev-parse HEAD)"
IPA_IDENTIFIER="$(date --utc +"%Y%m%dT%H%MZ")-${IPA_COMMIT}"
echo "IPA_IDENTIFIER is the following:${IPA_IDENTIFIER}"
popd

# Install the cloned IPA builder tool
virtualenv venv
# shellcheck source=/dev/null
source "./venv/bin/activate"
python3 -m pip install --upgrade pip
python3 -m pip install "./${IPA_BUILDER_PATH}"

# Configure the IPA builder to pull the IPA source from Nordix fork
export DIB_REPOLOCATION_ironic_python_agent="${IPA_REPO}"
export DIB_REPOREF_requirements="${OPENSTACK_REQUIREMENTS_REF}"
export DIB_REPOREF_ironic_python_agent="${IPA_COMMIT}"

# Build the IPA initramfs and kernel images
ironic-python-agent-builder --output "${IPA_IMAGE_NAME}" \
    --release "${IPA_BASE_OS_RELEASE}" "${IPA_BASE_OS}" \
    --element='dynamic-login' --element='journal-to-console' \
    --element='devuser' --element='openssh-server' \
    --element='extra-hardware' --verbose

# Deactivate the python virtual environment
deactivate

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

# Test whether the newly built IPA is compatible with the choosen Ironic version and with
# the Metal3 dev-env
if $ENABLE_BOOTSTRAP_TEST; then
    git clone --single-branch --branch "${METAL3_DEV_ENV_BRANCH}" "${METAL3_DEV_ENV_REPO}"
    # shellcheck source=/dev/null
    source "/tmp/vars.sh"
    export IRONIC_IMAGE="${IMAGE_REGISTRY}/${CONTAINER_IMAGE_REPO}/ironic-image:${IRONIC_TAG}"
    export USE_LOCAL_IPA=true
    export IPA_DOWNLOAD_ENABLED=false
    export BMOCOMMIT="${BMO_COMMIT}"
    export BMOBRANCH="${BMO_BRANCH}"
    pushd "${DEV_ENV_REPO_LOCATION}"
    git checkout "${METAL3_DEV_ENV_COMMIT}"
    METAL3_COMMIT="$(git rev-parse HEAD)"
    make
    make test
    source "./lib/common.sh"
    source "./lib/releases.sh"
    cat << EOF >> "${METADATA_PATH}"
METAL3_DEV_ENV_REPO="${METAL3_DEV_ENV_REPO}"
METAL3_DEV_ENV_BRANCH="${METAL3_DEV_ENV_BRANCH}"
METAL3_DEV_ENV_COMMIT="${METAL3_DEV_ENV_COMMIT}"
IPA_REPO="${IPA_REPO}"
IPA_BRANCH="${IPA_BRANCH}"
IPA_COMMIT="${IPA_COMMIT}"
IPA_BUILDER_REPO="${IPA_BUILDER_REPO}"
IPA_BUILDER_BRANCH="${IPA_BUILDER_BRANCH}"
IPA_BUILDER_COMMIT="${IPA_BUILDER_COMMIT}"
EOF
    pushd "${BMOPATH}"
    cat << EOF >> "${METADATA_PATH}"
BMO_REPO="${BMOREPO}"
BMO_BRANCH="${BMOBRANCH}"
BMO_COMMIT="$(git rev-parse HEAD)"
EOF
    popd
    pushd "${CAPM3PATH}"
    cat << EOF >> "${METADATA_PATH}"
CAPM3_REPO="${CAPM3REPO}"
CAPM3_BRANCH="${CAPM3BRANCH}"
CAPM3_COMMIT="$(git rev-parse HEAD)"
EOF
    popd
    pushd "${IPAMPATH}"
    cat << EOF >> "${METADATA_PATH}"
IPAM_REPO="${IPAMREPO}"
IPAM_BRANCH="${IPAMBRANCH}"
IPAM_PATH="$(git rev-parse HEAD)"
EOF
    popd
    cat << EOF >> "${METADATA_PATH}"
CAPI_RELEASE="${CAPIRELEASE}"
CAPI_VERSION="${CAPI_VERSION}"
EOF
    popd
fi

tar -rf "${IPA_IMAGE_TAR}" "${METADATA_PATH}"

REVIEW_ARTIFACTORY_PATH="airship/images/ipa/review/${IPA_BASE_OS}/${IPA_BASE_OS_RELEASE}/${IPA_IDENTIFIER}/${IPA_IMAGE_TAR}"
STAGING_ARTIFACTORY_PATH="airship/images/ipa/staging/${IPA_BASE_OS}/${IPA_BASE_OS_RELEASE}/${IPA_IDENTIFIER}/${IPA_IMAGE_TAR}"
# Upload the newly built image
if ! $DISABLE_UPLOAD ; then
    # shellcheck source=/dev/null
    source "${RT_UTILS}"
    if $STAGING; then
        rt_upload_artifact  "${IPA_IMAGE_TAR}" "${STAGING_ARTIFACTORY_PATH}" "0"
    else
        rt_upload_artifact  "${IPA_IMAGE_TAR}" "${REVIEW_ARTIFACTORY_PATH}" "0"
    fi
fi

