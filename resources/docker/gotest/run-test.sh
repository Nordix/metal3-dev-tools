#!/bin/sh
set -euo

echo "Starting unit test"

if [[ $REPO_NAME == "baremetal-operator" ]]
then
    dep ensure
else
    make
fi

make "${MAKE_CMD}"
