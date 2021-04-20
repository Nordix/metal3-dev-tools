#!/bin/bash
set -e

#------------------------------------------
# Workflow:
# -download required artifacts from upstream
# -push the artifact to Artifactory
# -clean up the downloaded files
#------------------------------------------

if [[ -z "$RT_URL" || -z "$RT_USER" || -z "$RT_TOKEN" ]]; then
    echo "The following variables must be set to update Nordix artifacts with this script:"
    echo "RT_URL   - path to Artifactory"
    echo "RT_USER  - Artifactory user"
    echo "RT_TOKEN - Artifactory token"
    exit 1
fi

set -ux

GIT_ROOT=$(git rev-parse --show-toplevel)
ARTIFACTORY_UTILS="${GIT_ROOT}/ci/scripts/artifactory/utils.sh"
# shellcheck disable=SC1091
# shellcheck disable=SC1090
. "$ARTIFACTORY_UTILS"

WORKSPACE=${WORKSPACE:=/tmp}

IPA_UPSTREAM="https://images.rdoproject.org/centos8/master/rdo_trunk/current-tripleo/ironic-python-agent.tar"
IPA_MD5_UPSTREAM="${IPA_UPSTREAM}.md5"
IPA_ARTIFACTORY_PATH="airship/ironic-python-agent/"

# Update an artifact in Artifactory given:
# $1 - the source of the artifact as a URI
# $2 - the path of the artifact in Artifactory of the form <repository>/<path>/<path>
function update_artifact() {
    local src="${1:?}"
    local dst="${2:?}"

    local filename
    filename=$(basename "$src")
    wget -P "$WORKSPACE" "$src"

    local filepath
    filepath="$WORKSPACE/$filename"
    rt_upload_artifact "$filepath" "$dst" 0
    rm -f "$filepath"
}

update_artifact "$IPA_UPSTREAM" "$IPA_ARTIFACTORY_PATH"
update_artifact "$IPA_MD5_UPSTREAM" "$IPA_ARTIFACTORY_PATH"
