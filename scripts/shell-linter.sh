#!/bin/bash

set -u

SHELL_FILES="$(find /data -type f -iname '*.sh')"
if [ -n "${SHELL_FILES}" ]; then
    # shellcheck disable=SC2086
    shellcheck ${SHELL_FILES}
fi
