#!/bin/bash

set -u

GO_FILES="$(find /data -type f -iname '*.go')"

if [ -n "${GO_FILES}" ]; then
    golint ./...;
    gosec -quiet ./...;
fi
