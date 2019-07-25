#!/bin/bash

set -ue

SCRIPTPATH="$(dirname "$(readlink -f "${0}")")"

docker build "${SCRIPTPATH}/lint" -t lint
docker run -v "${SCRIPTPATH}"/../:/data --rm -it --name lint lint
