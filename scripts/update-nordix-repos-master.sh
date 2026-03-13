#!/usr/bin/env bash

set -euo pipefail

#------------------------------------------
# Sync Nordix fork repos from their upstream sources using the GitHub CLI.
# Uses `gh repo sync` which calls the GitHub merge-upstream API,
# eliminating the need to clone repos locally.
#------------------------------------------

NORDIX_ORG="Nordix"

# Upstream source → Nordix fork repo name (please keep sorted by source)
declare -A REPOS=(
    [containers/nri-plugins]="nri-plugins"
    [falcosecurity/falco]="falco"
    [falcosecurity/falco-website]="falco-website"
    [falcosecurity/falcoctl]="falcoctl"
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

# Extra branches to sync beyond the default branch (please keep sorted by source)
declare -A EXTRA_BRANCHES=(
    [kubernetes-sigs/cluster-api]="release-1.10 release-1.11 release-1.12"
    [kubernetes-sigs/cluster-api-provider-openstack]="release-0.11 release-0.12 release-0.13"
    [metal3-io/baremetal-operator]="release-0.10 release-0.11 release-0.12"
    [metal3-io/cluster-api-provider-metal3]="release-1.10 release-1.11 release-1.12"
    [metal3-io/ip-address-manager]="release-1.10 release-1.11 release-1.12"
    [metal3-io/ironic-image]="release-30.0 release-31.0 release-32.0 release-33.0"
    [metal3-io/ironic-standalone-operator]="release-0.6 release-0.7 release-0.8"
)

FAILED=0

sync_branch() {
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
    if ! gh repo sync "${fork}" --force "${branch_flag[@]}"; then
        echo "  FAILED: ${fork} (${label})"
        FAILED=$((FAILED + 1))
    fi
}

# Sync default branch for all repos
for source in $(printf '%s\n' "${!REPOS[@]}" | sort); do
    sync_branch "${source}"
done

# Sync extra branches
for source in $(printf '%s\n' "${!EXTRA_BRANCHES[@]}" | sort); do
    for branch in ${EXTRA_BRANCHES[${source}]}; do
        sync_branch "${source}" "${branch}"
    done
done

if [[ "${FAILED}" -gt 0 ]]; then
    echo "${FAILED} sync(s) failed"
    exit 1
fi
