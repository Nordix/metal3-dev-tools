#!/bin/bash

set -ue

cd /data/go/src/github.com/metal3-io/cluster-api-provider-baremetal
dep ensure
make test
