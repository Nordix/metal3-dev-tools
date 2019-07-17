#!/bin/bash

#Call with
#./update.sh <repo> <branch>
#for example
#./update.sh cluster-api update-branch

set -ue

UPDATE_REPO=${1:-cluster-api metal3-dev-env cluster-api-provider-baremetal baremetal-operator}
UPDATE_BRANCH=${2:-master}

for repo in $UPDATE_REPO
do
  echo "Updating $repo"
  cd $repo
  # Update "master" on Nordix
  BRANCH=$(git rev-parse --abbrev-ref HEAD)
  git checkout $UPDATE_BRANCH
  git fetch upstream
  git rebase upstream/master
  git push
  git checkout $BRANCH
  cd ..
  echo -e "\n"
done
