#!/bin/bash

set -ue

SCRIPTPATH=$( cd $(dirname $0) >/dev/null 2>&1 ; pwd -P )

cd ${SCRIPTPATH}
cd ..

mkdir /root/go/src
cp -r cluster-api-provider-baremetal /root/go/src
cd /root/go/src/cluster-api-provider-baremetal
dep ensure
make test
