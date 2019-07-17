#!/bin/bash

set -ue

SCRIPTPATH=$( cd $(dirname $0) >/dev/null 2>&1 ; pwd -P )

docker build ${SCRIPTPATH} -t workspace
docker run --network host -v ${SCRIPTPATH}/../:/data -v /var/run/docker.sock:/var/run/docker.sock -v ${HOME}/.kube/:/root/.kube -v ${HOME}/.minikube:${HOME}/.minikube --rm -it --name workspace workspace
