#!/bin/bash

#Call with
#./update.sh <repo> <branch>
#for example
#./update.sh cluster-api update-branch

set -ue

SCRIPTPATH=$( cd $(dirname $(readlink -f $0)) >/dev/null 2>&1 ; pwd -P )

pushd ${SCRIPTPATH}
cd ..

UPDATE_REPO=${1:-go/src/sigs.k8s.io/cluster-api metal3-dev-env go/src/github.com/metal3-io/cluster-api-provider-baremetal go/src/github.com/metal3-io/baremetal-operator}
UPDATE_BRANCH=${2:-master}

for repo in $UPDATE_REPO
do
  echo "Updating $repo"
  pushd $repo
  # Update "master" on Nordix
  BRANCH=$(git rev-parse --abbrev-ref HEAD)
  git checkout $UPDATE_BRANCH
  git fetch upstream
  git rebase upstream/master
  git push
  git checkout $BRANCH
  popd
  echo -e "\n"
done

popd
