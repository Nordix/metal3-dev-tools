#!/bin/bash

# Fetch the upgrade tests from airship-dev-tools
git clone https://github.com/Nordix/airship-dev-tools.git /tmp/airship-dev-tools-clone
cp -r /tmp/airship-dev-tools-clone/airship-dev-tools/upgrade_tests "${M3PATH}"/scripts/feature_tests/upgrade

# Run controlplane upgrade tests
pushd "${M3PATH}/scripts/feature_tests/upgrade/upgrade_tests"
./controlplane_upgrade/1cp_0w_bootDiskImage_extraNode_upgrade.sh
./controlplane_upgrade/1cp_0w_k8sBin_extraNode_upgrade.sh
./controlplane_upgrade/1cp_0w_k8sVer_bootDiskImage_extraNode_upgrade.sh
./controlplane_upgrade/1cp_0w_k8sVer_extraNode_upgrade.sh
./controlplane_upgrade/3cp_0w_bootDiskImage_extraNode_upgrade.sh
./controlplane_upgrade/3cp_0w_k8sVer_extraNode_upgrade.sh
./controlplane_upgrade/3cp_1w_k8sVer_bootDiskImage_scaleInWorker_upgrade.sh
./controlplane_upgrade/1cp_1w_kubeadm_update.sh
popd

# Run cluster level ugprade tests
pushd "${M3PATH}/scripts/feature_tests/upgrade/upgrade_tests"
./1cp_1w_bootDiskImage_cluster_upgrade.sh
popd

# Run worker upgrade cases
pushd "${M3PATH}/scripts/feature_tests/upgrade/upgrade_tests"
./workers_upgrade/1cp_1w_bootDiskImage_extraNode_upgrade.sh
./workers_upgrade/1cp_1w_bootDiskImage_scaleOutWorkers_upgrade.sh
./workers_upgrade/1cp_3w_bootDiskImage_scaleInWorkers_upgrade_both.sh
./workers_upgrade/1cp_3w_bootDiskImage_scaleInWorkers_upgrade.sh
popd

# clean up the copied directories
rm -rf /tmp/airship-dev-tools-clone
pushd "${M3PATH}/scripts/feature_tests/upgrade"
rm -rf upgrade_tests
popd