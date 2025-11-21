#!/usr/bin/env bash

CI_DIR="$(dirname "$(readlink -f "${0}")")/../.."
COMMON_SCRIPTS_DIR="${CI_DIR}/scripts/common"

# shellcheck source=ci/scripts/common/opts.sh
. "${COMMON_SCRIPTS_DIR}/opts.sh"

# Description:
# Print a message if verbose mode is enabled
#
# Usage:
# common_verbose "message"
#
common_verbose() {
  if [[ "${COMMON_OPT_VERBOSE_VALUE}" == "true" ]]; then
    echo >&2 "$@"
  fi
  return 0
}

# Description:
# Execute command unless the dry-run mode is turned on
# in which case only a message is printed. It is
# also possible to give the expected output as an
# argument for command output parsing. This output
# is sent to stdout when the dry-run mode is turned on.
#
# Usage:
# common_run [-o "expected output"] cmd...
#
common_run() {
  local OPTS

  OPTS=$(getopt -o "o:" --long "output:" -n "${0}" -- "$@")
  eval set -- "${OPTS}"
  while true; do
    case "$1" in
      -o|--output)
        if [[ "${COMMON_OPT_DRYRUN_VALUE}" == "true" ]]; then
          echo "${2}"
        fi
        shift 2
        ;;
      --)
        shift
        break
        ;;
      *)
        break
        ;;
    esac
  done

  if [[ "${COMMON_OPT_DRYRUN_VALUE}" == "true" ]]; then
    echo >&2 "$*"
    return 0
  fi

  "$@"
}
