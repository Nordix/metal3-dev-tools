#!/usr/bin/env bash

set -euo pipefail

#------------------------------------------
# Sync Nordix fork repos from their upstream sources using the GitHub CLI.
# Uses `gh repo sync` which calls the GitHub merge-upstream API,
# falling back to clone/push via SSH for missing branches.
#
# Requires: GH_TOKEN (PAT with repo+workflow scopes) and SSH key for
# git push.
#------------------------------------------

NORDIX_ORG="Nordix"

# Upstream source → Nordix fork repo name (please keep sorted by source)
declare -A REPOS=(
    [containers/nri-plugins]="nri-plugins"
    [falcosecurity/falco]="falco"
    [falcosecurity/libs]="libs"
    [k8s-operatorhub/community-operators]="community-operators"
    [k8snetworkplumbingwg/sriov-cni]="sriov-cni"
    [k8snetworkplumbingwg/sriov-network-device-plugin]="sriov-network-device-plugin"
    [kubernetes-sigs/cluster-api-provider-openstack]="cluster-api-provider-openstack"
    [kubernetes-sigs/cluster-api]="cluster-api"
    [kubernetes-sigs/node-feature-discovery]="node-feature-discovery"
    [kubernetes/kubernetes]="kubernetes"
    [metal3-io/.github]="metal3-dot-github"
    [metal3-io/baremetal-operator]="baremetal-operator"
    [metal3-io/cluster-api-provider-metal3]="cluster-api-provider-metal3"
    [metal3-io/community]="metal3-community"
    [metal3-io/ip-address-manager]="metal3-ipam"
    [metal3-io/ironic-image]="ironic-image"
    [metal3-io/ironic-ipa-downloader]="ironic-ipa-downloader"
    [metal3-io/ironic-standalone-operator]="ironic-standalone-operator"
    [metal3-io/mariadb-image]="mariadb-image"
    [metal3-io/metal3-dev-env]="metal3-dev-env"
    [metal3-io/metal3-docs]="metal3-docs"
    [metal3-io/metal3-io.github.io]="metal3-io.github.io"
    [metal3-io/project-infra]="metal3-project-infra"
    [metal3-io/utility-images]="metal3-utility-images"
    [nmstate/nmstate]="nmstate"
    [openstack/ironic-python-agent]="ironic-python-agent"
    [openstack/ironic-python-agent-builder]="ironic-python-agent-builder"
    [topolvm/topolvm]="topolvm"
)

# When a repo is listed here, ONLY these branches are synced (overrides
# the default-branch sync).  Include main/master when you still want
# the default branch synced.  (please keep sorted by source)
# NOTE: kubernetes/kubernetes is here as the default fork branch is "nordix-dev"
declare -A OVERRIDE_BRANCHES=(
    [kubernetes-sigs/cluster-api]="main release-1.10 release-1.11 release-1.12"
    [kubernetes-sigs/cluster-api-provider-openstack]="main release-0.12 release-0.13 release-0.14"
    [kubernetes/kubernetes]="main release-1.33 release-1.34 release-1.35"
    [metal3-io/baremetal-operator]="main release-0.10 release-0.11 release-0.12"
    [metal3-io/cluster-api-provider-metal3]="main release-1.10 release-1.11 release-1.12"
    [metal3-io/ip-address-manager]="main release-1.10 release-1.11 release-1.12"
    [metal3-io/ironic-image]="main release-29.0 release-31.0 release-32.0 release-33.0 release-34.0"
    [metal3-io/ironic-standalone-operator]="main release-0.6 release-0.7 release-0.8"
)

FAILED=0

sync_branch()
{
    local source="$1"
    local fork="${NORDIX_ORG}/${REPOS[${source}]}"
    local branch="${2:-}"

    local branch_flag=()
    local label="default branch"
    if [[ -n "${branch}" ]]; then
        branch_flag=(--branch "${branch}")
        label="${branch}"
    fi

    echo "Syncing ${source} -> ${fork} (${label})"
    # Try API sync first; fall back to clone/push via SSH for missing branches
    if ! gh repo sync "${fork}" --force "${branch_flag[@]}"; then
        if [[ -z "${branch}" ]]; then
            branch=$(gh repo view "${source}" --json defaultBranchRef --jq '.defaultBranchRef.name')
        fi
        echo "  API sync failed, falling back to clone/push"
        local tmpdir="/tmp/${REPOS[${source}]}-${branch}"
        if ! git clone --bare --single-branch --no-tags --branch "${branch}" "https://github.com/${source}.git" "${tmpdir}" \
            || ! git -C "${tmpdir}" push --force "git@github.com:${fork}.git" "refs/heads/${branch}:refs/heads/${branch}"; then
            echo "  FAILED: ${fork} (${label})"
            FAILED=$((FAILED + 1))
        fi
    fi
}

# Sync repos: use explicit BRANCHES list when present, otherwise sync the
# default branch only.
for source in $(printf '%s\n' "${!REPOS[@]}" | sort); do
    if [[ -n "${OVERRIDE_BRANCHES[${source}]+x}" ]]; then
        for branch in ${OVERRIDE_BRANCHES[${source}]}; do
            sync_branch "${source}" "${branch}"
        done
    else
        sync_branch "${source}"
    fi
done

if [[ "${FAILED}" -gt 0 ]]; then
    echo "${FAILED} sync(s) failed"
    exit 1
fi
