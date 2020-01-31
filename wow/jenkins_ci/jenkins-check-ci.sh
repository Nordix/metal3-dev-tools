#!/usr/bin/env bash

set -u
# List of jobs based on
# https://github.com/Nordix/airship-dev-tools/blob/master/wow/jenkins_ci/README.md
out1=$(curl -s https://jenkins.nordix.org/view/Airship/api/json?pretty=true | grep -B 3 red | egrep name | egrep image_building)
out2=$(curl -s https://jenkins.nordix.org/view/Airship/api/json?pretty=true | grep -B 3 red | egrep name | egrep tools_repos)
out3=$(curl -s https://jenkins.nordix.org/view/Airship/api/json?pretty=true | grep -B 3 red | egrep name | egrep _master_)

echo "--------------------------------------"

if [[ ! -z "$out1" ]] || [[ ! -z "$out2" ]] || [[ ! -z "$out3" ]]; then
  echo "---------- FAILED CI JOBS ------------"
  echo "--------------------------------------"
fi

if [ ! -z "$out1" ]; then
  echo "$out1"
fi
if [ ! -z "$out2" ]; then
  echo "$out2"
fi
if [ ! -z "$out3" ]; then
  echo "$out3"
fi

if [[ -z "$out1" ]] && [[ -z "$out2" ]] && [[ -z "$out3" ]]; then
  echo "----- ALL REQUIRED CI JOBS PASS ------"
  echo "--------------------------------------"
fi
