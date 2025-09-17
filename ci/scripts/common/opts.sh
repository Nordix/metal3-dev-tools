#! /usr/bin/env bash

# Source only once
[[ "${_OPT_HELP:-false}" != "false" ]] && { return; }

# Default option values
COMMON_OPT_TARGET_VALUE="$(whoami | tr '[:lower:]' '[:upper:]')"
COMMON_OPT_KEYNAME_VALUE="$(whoami)"
COMMON_OPT_RTUSER_VALUE="$(whoami)"

export COMMON_OPT_VERBOSE_VALUE=false
export COMMON_OPT_TARGET_VALUE
export COMMON_OPT_HA_VALUE=false
export COMMON_OPT_KEYFILE_VALUE="${HOME}/.ssh/id_ed25519.pub"
export COMMON_OPT_USER_VALUE="metal3admin"
export COMMON_OPT_RTURL_VALUE="https://artifactory.nordix.org/artifactory"
export COMMON_OPT_KEYNAME_VALUE
export COMMON_OPT_RTUSER_VALUE
export COMMON_OPT_DRYRUN_VALUE=false
export COMMON_OPT_KEEPUSERS_VALUE=false
export COMMON_OPT_PURGE_VALUE=false

# All available options including parameter and description information
#
# Syntax:     "SHORT OPT" "LONG OPT" "PARAM" "DESC" "DEFAULT"
# Index:      :0:1        :1:1       :2:1    :3:1   :4:1
#
export _OPT_HELP=("h" "help"       ""        "display this help and exit" "")
     _OPT_TARGET=("t" "target"     "=TARGET" "specify the target infrastructure" "COMMON_OPT_TARGET_VALUE")
    _OPT_VERBOSE=("v" "verbose"    ""        "explain what is being done" "")
         _OPT_HA=("e" "enable-ha"  ""        "set router as high available" "")
    _OPT_KEYFILE=("k" "key-file"   "=FILE"   "file containing the public key" "COMMON_OPT_KEYFILE_VALUE")
       _OPT_USER=("u" "user"       "=USER"   "username for SSH" "COMMON_OPT_USER_VALUE")
      _OPT_RTURL=("r" "rt-url"     "=URL"    "artifactory URL" "COMMON_OPT_RTURL_VALUE")
    _OPT_KEYNAME=("n" "key-name"   "=TXT"    "name for the public key" "COMMON_OPT_KEYNAME_VALUE")
     _OPT_RTUSER=("s" "rt-user"    "=USER"   "artifactory user" "COMMON_OPT_RTUSER_VALUE")
     _OPT_DRYRUN=("d" "dry-run"    ""        "do nothing; only show what would happen" "")
  _OPT_KEEPUSERS=("x" "keep-users" ""        "keep users not found in the artifactory" "")
      _OPT_PURGE=("p" "purge"      ""        "don't update user; simply purge user" "")
    _OPT_INVALID=(""  ""           ""        "invalid index" "")

# Option array
_OPT_ARRAY=(
  _OPT_INVALID[@]
  _OPT_HELP[@]
  _OPT_VERBOSE[@]
  _OPT_TARGET[@]
  _OPT_HA[@]
  _OPT_KEYFILE[@]
  _OPT_USER[@]
  _OPT_RTURL[@]
  _OPT_KEYNAME[@]
  _OPT_RTUSER[@]
  _OPT_DRYRUN[@]
  _OPT_KEEPUSERS[@]
  _OPT_PURGE[@]
)

# Option constants: 0 = invalid
_OPT_IDX=1
declare -r COMMON_OPT_HELP=$((_OPT_IDX++))
declare -r COMMON_OPT_VERBOSE=$((_OPT_IDX++))
declare -r COMMON_OPT_TARGET=$((_OPT_IDX++))
declare -r COMMON_OPT_HA=$((_OPT_IDX++))
declare -r COMMON_OPT_KEYFILE=$((_OPT_IDX++))
declare -r COMMON_OPT_USER=$((_OPT_IDX++))
declare -r COMMON_OPT_RTURL=$((_OPT_IDX++))
declare -r COMMON_OPT_KEYNAME=$((_OPT_IDX++))
declare -r COMMON_OPT_RTUSER=$((_OPT_IDX++))
declare -r COMMON_OPT_DRYRUN=$((_OPT_IDX++))
declare -r COMMON_OPT_KEEPUSERS=$((_OPT_IDX++))
declare -r COMMON_OPT_PURGE=$((_OPT_IDX++))

# Export constants
export COMMON_OPT_HELP
export COMMON_OPT_VERBOSE
export COMMON_OPT_TARGET
export COMMON_OPT_HA
export COMMON_OPT_KEYFILE
export COMMON_OPT_USER
export COMMON_OPT_RTURL
export COMMON_OPT_KEYNAME
export COMMON_OPT_RTUSER
export COMMON_OPT_DRYRUN
export COMMON_OPT_KEEPUSERS
export COMMON_OPT_PURGE

# Command line arguments i.e. the remaining part after options
COMMON_OPT_ARGUMENTS=

# Description:
# Construct usage information with specified options.
#
# If no one-liner is given, the default value "<NO ONE-LINER?>"
# is used instead.
# If no arguments are given, empty value is used instead.
#
# Usage:
# common_make_usage_string -o "ONE-LINER" -a "ARGUMENTS" <option contants>...
#
common_make_usage_string() {
  local ONELINER ARGS I OPT SOPT LOPT PARAM DESC DEFAULT

  # Parse options
  ONELINER="<NO ONE-LINER?>"
  ARGS=""
  OPTS=$(getopt -o "o:a:" --long "one-liner:,arguments:" -n "${0}" -- "$@")
  eval set -- "${OPTS}"
  while true; do
    case "$1" in
      -o|--one-liner)
        ONELINER=${2}
        shift 2
        ;;
      -a|--arguments)
        ARGS=${2}
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

  echo ""
  echo "Usage:"
  echo ""
  echo "  $(basename "${0}") [opts] ${ARGS}"
  echo ""
  echo "${ONELINER}"
  echo ""
  echo "Options are as follows:"
  echo ""

  # Print out the content of the option array and print only
  # selected options
  for ((I=1; I<$#+1; I++)); do
    OPT=${_OPT_ARRAY[${!I}]}
    SOPT=${!OPT:0:1}
    # _OPT_INVALID?
    [[ -z "${SOPT}" ]] && continue
    LOPT=${!OPT:1:1}
    PARAM=${!OPT:2:1}
    DESC=${!OPT:3:1}
    DEFAULT=${!OPT:4:1}
    [[ -n "${DEFAULT}" ]] && [[ -n "${!DEFAULT}" ]] && {
      DEFAULT=". Default value: '${!DEFAULT}'."
    } || DEFAULT=""
    echo -e "  -${SOPT}, --${LOPT}${PARAM}\n      ${DESC}${DEFAULT}\n"
  done
}

# Description:
# Print usage to stderr and exit with a specified value.
# If no value is given, exit with status 1.
#
# Usage:
# common_print_usage <usage_information> <exit_value>
#
common_print_usage() {
  echo >&2 -e "${1:-"NO USAGE INFORMATION"}\n"
  exit "${2:-1}"
}

# Description:
# Parse options
#
# Usage:
# common_parse_options <usage_information>
#
common_parse_options() {
  local USAGE OPTS OPT PARAM S_OPTS L_OPTS VAR VALUE

  USAGE=${1:-"NO USAGE INFORMATION"}
  S_OPTS=""
  L_OPTS=()
  shift

  # Populate short options (S_OPTS) and long
  # options (L_OPTS) from the entries in
  # the option array
  for OPT in "${_OPT_ARRAY[@]}"; do

    # _OPT_INVALID?
    [[ -z "${!OPT:0:1}" ]] && continue

    # Is there a parameter for this option?
    PARAM=
    if [ -n "${!OPT:2:1}" ]; then
      PARAM=":"
    fi
    S_OPTS+="${!OPT:0:1}${PARAM}"
    L_OPTS+=("${!OPT:1:1}${PARAM}")
  done

  # Parse options
  OPTS=$(getopt -o "${S_OPTS}" \
                --long "$(printf "%s," "${L_OPTS[@]}")" \
                -n "${0}" -- "$@")
  # shellcheck disable=SC2181
  if [ $? != 0 ]; then common_print_usage "${USAGE}"; fi
  eval set -- "${OPTS}"
  while true; do
    case "$1" in
      -h|--help)
        common_print_usage "${USAGE}" 0
        ;;
      -d|--dry-run)
        export COMMON_OPT_DRYRUN_VALUE=true
        shift
        ;;
      -e|--enable-ha)
        export COMMON_OPT_HA_VALUE=true
        shift
        ;;
      -k|--key-file)
        export COMMON_OPT_KEYFILE_VALUE=${2}
        shift 2
        ;;
      -n|--key-name)
        export COMMON_OPT_KEYNAME_VALUE=${2}
        shift 2
        ;;
      -p|--purge)
        export COMMON_OPT_PURGE_VALUE=true
        shift
        ;;
      -r|--rt-url)
        export COMMON_OPT_RTURL_VALUE=${2}
        shift 2
        ;;
      -s|--rt-user)
        export COMMON_OPT_RTUSER_VALUE=${2}
        shift 2
        ;;
      -t|--target)
        COMMON_OPT_TARGET_VALUE=$(echo "${2}" | tr '[:lower:]' '[:upper:]')
        export COMMON_OPT_TARGET_VALUE
        shift 2
        ;;
      -u|--user)
        export COMMON_OPT_USER_VALUE=${2}
        shift 2
        ;;
      -v|--verbose)
        export COMMON_OPT_VERBOSE_VALUE=true
        shift
        ;;
      -x|--keep-users)
        export COMMON_OPT_KEEPUSERS_VALUE=true
        shift
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

  export COMMON_OPT_ARGUMENTS=("$@")
}

# Description:
# Validate target
#
# Usage:
# common_validate_target
#
common_validate_target() {
  [[ -z "${COMMON_OPT_TARGET_VALUE}" ]] && {
    echo >&2 "Error: target not specified"
    exit 1
  }

  # Validate target: must have a router defined
  VAR="${COMMON_OPT_TARGET_VALUE}_ROUTER_NAME"
  VALUE=${!VAR:-"invalid"}
  [[ "${VALUE}" == "invalid" ]] && {
    echo >&2 "Error: invalid target - ${VAR} not defined"
    exit 1
  }

  true
}

# Description:
# Validate key file
#
# Usage:
# common_validate_keyfile
#
common_validate_keyfile() {
  [[ -z "${COMMON_OPT_KEYFILE_VALUE}" ]] && {
    echo >&2 "Error: no key file specified"
    exit 1
  }
  [[ ! -r "${COMMON_OPT_KEYFILE_VALUE}" ]] && {
    echo >&2 "Error: ${COMMON_OPT_KEYFILE_VALUE} not readable"
    exit 1
  }

  true
}

# Description:
# Validate key name
#
# Usage:
# common_validate_keyname
#
common_validate_keyname() {
  [[ -z "${COMMON_OPT_KEYNAME_VALUE}" ]] && {
    echo >&2 "Error: no key name specified"
    exit 1
  }

  true
}

# Description:
# Validate RT URL
#
# Usage:
# common_validate_rturl
#
common_validate_rturl() {
  [[ -z "${COMMON_OPT_RTURL_VALUE}" ]] && {
    echo >&2 "Error: no URL for artifactory"
    exit 1
  }

  true
}

# Description:
# Validate RT user
#
# Usage:
# common_validate_rtuser
#
common_validate_rtuser() {
  [[ -z "${COMMON_OPT_RTUSER_VALUE}" ]] && {
    echo >&2 "Error: no user for artifactory"
    exit 1
  }

  true
}

# Description:
# Validate user
#
# Usage:
# common_validate_user
#
common_validate_user() {
  [[ -z "${COMMON_OPT_USER_VALUE}" ]] && {
    echo >&2 "Error: no user specified"
    exit 1
  }

  true
}

# Description:
# Validate RT token
#
# Usage:
# common_validate_rttoken
#
common_validate_rttoken() {
  [[ -z "${RT_TOKEN:-""}" ]] && {
    echo >&2 "Error: environment variable RT_TOKEN not set"
    exit 1
  }

  true
}
