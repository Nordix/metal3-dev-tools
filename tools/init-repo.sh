#!/bin/bash

set -ue

SCRIPTPATH=$( cd $(dirname $0) >/dev/null 2>&1 ; pwd -P )

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

setup_repo cluster-api kubernetes-sigs
for repo in metal3-dev-env cluster-api-provider-baremetal baremetal-operator
do
    setup_repo ${repo} metal3-io
done

popd
