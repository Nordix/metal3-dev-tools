#!/bin/bash

set -ue

SCRIPTPATH=$( cd $(dirname $(readlink -f $0)) >/dev/null 2>&1 ; pwd -P )

pushd ${SCRIPTPATH}
cd ..

setup_repo () {
  git clone git@github.com:Nordix/${1}.git
  cd ${1}
  git remote add upstream git@github.com:${2}/${1}.git
  git remote set-url --push upstream no_push
  git remote -v
  # Update "master" on Nordix
  git fetch upstream
  git rebase upstream/master
  git push
  cd ..
}

setup_go_repo () {
  mkdir -p ${3}
  pushd ${3}
  setup_repo ${1} ${2}
  popd
}

setup_go_repo cluster-api kubernetes-sigs go/src/sigs.k8s.io
setup_repo metal3-dev-env metal3-io
setup_go_repo cluster-api-provider-baremetal metal3-io go/src/github.com/metal3-io
setup_go_repo baremetal-operator metal3-io go/src/github.com/metal3-io

popd
