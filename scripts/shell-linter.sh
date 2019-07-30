#!/bin/bash

set -u

SHELL_FILES="$(find /data -type f -iname '*.sh')"
# shellcheck disable=SC2086
shellcheck ${SHELL_FILES}
