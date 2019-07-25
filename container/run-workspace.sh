#!/bin/bash

set -ue

SCRIPTPATH="$(dirname "$(readlink -f "${0}")")"

docker build "${SCRIPTPATH}/workspace" -t workspace
docker run --network host -v "${SCRIPTPATH}"/../:/data -v /var/run/docker.sock:/var/run/docker.sock -v "${HOME}"/.kube/:/root/.kube -v "${HOME}"/.minikube:"${HOME}"/.minikube --rm -it --name workspace workspace
