#!/bin/bash
set -u

#------------------------------------------
# Workflow:
# -clone repos to jenkins if not there
# -rebase jenkins local repos from upstream
# -push jenkins local repos to Nordix forks
#------------------------------------------

WORKSPACE="${WORKSPACE:=/tmp}"

SCRIPTPATH="$(dirname "$(readlink -f "${0}")")"

CAPM3_REPO="https://github.com/metal3-io/cluster-api-provider-metal3.git"
CAPO_REPO="https://github.com/kubernetes-sigs/cluster-api-provider-openstack.git"
CAPI_REPO="https://github.com/kubernetes-sigs/cluster-api.git"
BMO_REPO="https://github.com/metal3-io/baremetal-operator.git"
M3DOCS_REPO="https://github.com/metal3-io/metal3-docs.git"
M3DEVENV_REPO="https://github.com/metal3-io/metal3-dev-env.git"
PROJECTINFRA_REPO="https://github.com/metal3-io/project-infra.git"
IRONIC_IMAGE_REPO="https://github.com/metal3-io/ironic-image.git"
IPAM_REPO="https://github.com/metal3-io/ip-address-manager.git"
METAL3GITHUBIO_REPO="https://github.com/metal3-io/metal3-io.github.io.git"
IPA_REPO="https://github.com/openstack/ironic-python-agent.git"
IPA_BUILDER_REPO="https://github.com/openstack/ironic-python-agent-builder.git"
TOPOLVM_REPO="https://github.com/topolvm/topolvm.git"
SRIOV_CNI_REPO="https://github.com/k8snetworkplumbingwg/sriov-cni.git"
SRIOV_NDP_REPO="https://github.com/k8snetworkplumbingwg/sriov-network-device-plugin.git"
IPA_DOWNLOADER_REPO="https://github.com/metal3-io/ironic-ipa-downloader.git"
DOT_GITHUB_REPO="https://github.com/metal3-io/.github"


NORDIX_CAPM3_REPO="git@github.com:Nordix/cluster-api-provider-metal3.git"
NORDIX_CAPO_REPO="git@github.com:Nordix/cluster-api-provider-openstack.git"
NORDIX_CAPI_REPO="git@github.com:Nordix/cluster-api.git"
NORDIX_BMO_REPO="git@github.com:Nordix/baremetal-operator.git"
NORDIX_M3DOCS_REPO="git@github.com:Nordix/metal3-docs.git"
NORDIX_M3DEVENV_REPO="git@github.com:Nordix/metal3-dev-env.git"
NORDIX_PROJECTINFRA_REPO="git@github.com:Nordix/metal3-project-infra.git"
NORDIX_IRONIC_IMAGE_REPO="git@github.com:Nordix/ironic-image.git"
NORDIX_IPAM_REPO="git@github.com:Nordix/metal3-ipam.git"
NORDIX_METAL3GITHUBIO_REPO="git@github.com:Nordix/metal3-io.github.io.git"
NORDIX_IPA_REPO="git@github.com:Nordix/ironic-python-agent.git"
NORDIX_IPA_BUILDER_REPO="git@github.com:Nordix/ironic-python-agent-builder.git"
NORDIX_TOPOLVM="git@github.com:Nordix/topolvm.git"
NORDIX_SRIOV_CNI_REPO="git@github.com:Nordix/sriov-cni.git"
NORDIX_SRIOV_NDP_REPO="git@github.com:Nordix/sriov-network-device-plugin.git"
NORDIX_IPA_DOWNLOADER_REPO="git@github.com:Nordix/ironic-ipa-downloader.git"
NORDIX_DOT_GITHUB_REPO="git@github.com:Nordix/metal3-dot-github.git"


LOCAL_CAPM3_REPO="${WORKSPACE}/cluster-api-provider-metal3"
LOCAL_CAPO_REPO="${WORKSPACE}/cluster-api-provider-openstack"
LOCAL_CAPI_REPO="${WORKSPACE}/cluster-api"
LOCAL_BMO_REPO="${WORKSPACE}/baremetal-operator"
LOCAL_M3DOCS_REPO="${WORKSPACE}/metal3-docs"
LOCAL_M3DEVENV_REPO="${WORKSPACE}/metal3-dev-env"
LOCAL_PROJECTINFRA_REPO="${WORKSPACE}/project-infra"
LOCAL_IRONIC_IMAGE_REPO="${WORKSPACE}/ironic-image"
LOCAL_IPAM_REPO="${WORKSPACE}/metal3-ipam"
LOCAL_METAL3GITHUBIO_REPO="${WORKSPACE}/metal3-io.github.io"
LOCAL_IPA_REPO="${WORKSPACE}/ironic-python-agent.git"
LOCAL_IPA_BUILDER_REPO="${WORKSPACE}/ironic-python-agent-builder.git"
LOCAL_TOPOLVM="${WORKSPACE}/topolvm.git"
LOCAL_SRIOV_CNI_REPO="${WORKSPACE}/sriov-cni.git"
LOCAL_SRIOV_NDP_REPO="${WORKSPACE}/sriov-network-device-plugin.git"
LOCAL_IPA_DOWNLOADER_REPO="${WORKSPACE}/ironic-ipa-downloader.git"
LOCAL_DOT_GITHUB_REPO="${WORKSPACE}/metal3-dot-github.git"

pushd "${SCRIPTPATH}" || exit
cd ..

UPDATE_REPO="${1:-${LOCAL_CAPM3_REPO} ${LOCAL_CAPO_REPO} ${LOCAL_CAPI_REPO} ${LOCAL_BMO_REPO} ${LOCAL_M3DOCS_REPO} ${LOCAL_M3DEVENV_REPO} ${LOCAL_PROJECTINFRA_REPO} ${LOCAL_IRONIC_IMAGE_REPO} ${LOCAL_IPAM_REPO} ${LOCAL_METAL3GITHUBIO_REPO} ${LOCAL_IPA_REPO} ${LOCAL_IPA_BUILDER_REPO} ${LOCAL_TOPOLVM} ${LOCAL_SRIOV_CNI_REPO} ${LOCAL_SRIOV_NDP_REPO} ${LOCAL_IPA_DOWNLOADER_REPO} ${LOCAL_DOT_GITHUB_REPO}}"
UPSTREAM_REPO="${3:-${CAPM3_REPO} ${CAPO_REPO} ${CAPI_REPO} ${BMO_REPO} ${M3DOCS_REPO} ${M3DEVENV_REPO} ${PROJECTINFRA_REPO} ${IRONIC_IMAGE_REPO} ${IPAM_REPO} ${METAL3GITHUBIO_REPO} ${IPA_REPO} ${IPA_BUILDER_REPO} ${TOPOLVM_REPO} ${SRIOV_CNI_REPO} ${SRIOV_NDP_REPO} ${IPA_DOWNLOADER_REPO} ${DOT_GITHUB_REPO}}"
NORDIX_REPO="${4:-${NORDIX_CAPM3_REPO} ${NORDIX_CAPO_REPO} ${NORDIX_CAPI_REPO} ${NORDIX_BMO_REPO} ${NORDIX_M3DOCS_REPO} ${NORDIX_M3DEVENV_REPO} ${NORDIX_PROJECTINFRA_REPO} ${NORDIX_IRONIC_IMAGE_REPO} ${NORDIX_IPAM_REPO} ${NORDIX_METAL3GITHUBIO_REPO} ${NORDIX_IPA_REPO} ${NORDIX_IPA_BUILDER_REPO} ${NORDIX_TOPOLVM} ${NORDIX_SRIOV_CNI_REPO} ${NORDIX_SRIOV_NDP_REPO} ${NORDIX_IPA_DOWNLOADER_REPO} ${NORDIX_DOT_GITHUB_REPO}}"

# This function syncs a single branch between Nordix and upstream (usually Metal3) repository
function update_custom_branch {
    local BRANCHES="$1"
    local LOCAL_REPO="$2"
    local NORDIX_REPO="$3"

    pushd "${LOCAL_REPO}" || exit
    for branch in ${BRANCHES}
    do
        echo "Updating ${branch} branch in ${LOCAL_REPO}"
        git checkout "origin/${branch}"
        git fetch "origin" "${branch}"
        git rebase "origin/${branch}"
        git remote add "remote-${branch}" "${NORDIX_REPO}"
        git push -uf "remote-${branch}" "HEAD:refs/heads/${branch}"
        echo "Push done to ${branch} branch in ${NORDIX_REPO}"
    done
    popd || exit
}


# clone upstream repos to jenkins if not found
i=0
# shellcheck disable=SC2206
locarray=(${UPDATE_REPO})
# shellcheck disable=SC2206
upsarray=(${UPSTREAM_REPO})
# shellcheck disable=SC2206
ndxarray=(${NORDIX_REPO})

pushd "${WORKSPACE}" || exit

# shellcheck disable=SC2034
for index in ${UPDATE_REPO}
do
    if [ ! -d "${locarray[$i]}" ]; then
        echo "CLONE ${upsarray[$i]}"
        git clone "${upsarray[$i]}" "${locarray[$i]}"
    fi
    i=$((i+1))
done

cd - || exit

# Update the default branch (main/master)
i=0
for repo in ${UPDATE_REPO}
do
    pushd "${repo}" || exit
    BRANCH=$(git rev-parse --abbrev-ref HEAD)
    echo "Updating ${BRANCH} branch in ${repo}"
    git checkout "${BRANCH}"
    # origin points to upstream repos
    git fetch origin
    git rebase origin/"${BRANCH}"
    git remote add nordixrepo "${ndxarray[$i]}"
    git push -uf nordixrepo "${BRANCH}"
    echo "Push done to ${ndxarray[$i]}"
    git checkout "${BRANCH}"
    popd || exit
    echo -e "\n"
    i=$((i+1))
done

# Sync non default branches on selected repos

CAPM3_RELEASE_BRANCHES="release-0.5 release-1.1 release-1.2 release-1.3"
update_custom_branch "$CAPM3_RELEASE_BRANCHES" "$LOCAL_CAPM3_REPO" "$NORDIX_CAPM3_REPO"

IPAM_RELEASE_BRANCHES="release-0.1 release-1.1 release-1.2 release-1.3"
update_custom_branch "$IPAM_RELEASE_BRANCHES" "$LOCAL_IPAM_REPO" "$NORDIX_IPAM_REPO"

CAPI_RELEASE_BRANCHES="release-0.4 release-1.1 release-1.2 release-1.3"
update_custom_branch "$CAPI_RELEASE_BRANCHES" "$LOCAL_CAPI_REPO" "$NORDIX_CAPI_REPO"

CAPO_RELEASE_BRANCHES="release-0.3 release-0.4 release-0.5 release-0.6 release-0.7"
update_custom_branch "$CAPO_RELEASE_BRANCHES" "$LOCAL_CAPO_REPO" "$NORDIX_CAPO_REPO"

popd || exit
