#!/bin/bash

set -x

M3_DIR="$(dirname "$(readlink -f "${0}")")/../../.."

# shellcheck disable=SC1091
# shellcheck disable=SC1090
source "${M3_DIR}/lib/common.sh"

# shellcheck disable=SC1091
# shellcheck disable=SC1090
source "${M3_DIR}/lib/network.sh"

# shellcheck disable=SC1091
# shellcheck disable=SC1090
source "${M3_DIR}/lib/images.sh"

# Fetch the upgrade tests from airship-dev-tools
pushd ${M3_DIR}/scripts/feature_tests/upgrade
cd /tmp
git clone https://github.com/Nordix/airship-dev-tools.git
popd

cp -r /tmp/airship-dev-tools/upgrade_tests ${M3_DIR}/scripts/feature_tests/upgrade

# Run controlplane upgrade tests
pushd "${M3_DIR}/scripts/feature_tests/upgrade/upgrade_tests/controlplane_upgrade"
#./1cp_0w_bootDiskImage_extraNode_upgrade.sh
#./1cp_0w_k8sBin_extraNode_upgrade.sh
#./1cp_0w_k8sVer_bootDiskImage_extraNode_upgrade.sh
#./1cp_0w_k8sVer_extraNode_upgrade.sh
#./1cp_1w_kubeadm_update.sh
#./3cp_0w_bootDiskImage_extraNode_upgrade.sh
#./3cp_0w_k8sVer_extraNode_upgrade.sh
source 3cp_1w_k8sVer_bootDiskImage_scaleInWorker_upgrade.sh
popd

# Run cluster level ugprade tests
pushd "${M3_DIR}/scripts/feature_tests/upgrade/upgrade_tests"
source 1cp_1w_bootDiskImage_cluster_upgrade.sh
popd

# Run worker upgrade cases
pushd "${M3_DIR}/scripts/feature_tests/upgrade/upgrade_tests/workers_upgrade"
#./1cp_1w_bootDiskImage_extraNode_upgrade.sh
#./1cp_1w_bootDiskImage_scaleOutWorkers_upgrade.sh
source 1cp_3w_bootDiskImage_scaleInWorkers_upgrade_both.sh
#./1cp_3w_bootDiskImage_scaleInWorkers_upgrade.sh
popd

# clean up the copied directories
rm -rf /tmp/airship-dev-tools
pushd "${M3_DIR}/scripts/feature_tests/upgrade"
rm -rf upgrade_tests
popd

set +x
