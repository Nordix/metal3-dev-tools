#!/usr/bin/env bash

set -eu

# shellcheck source=ci/scripts/squid/build.sh
. squid_ver.sh

USAGE="
Usage:
    $(basename "${0}") [opts]

Build Squid version ${SQUID_VER}.

Options are as follows:

  -s, --skip-download
    skip package download

  -h, --help
    display this help and exit

  -v, --version=VERSION
    Squid version to install; default '${SQUID_VER}'
"

print_usage() {
    echo >&2 -e "${USAGE}"
    exit "${1:-1}"
}

# Main execution
main() {
    local SKIP_DOWNLOAD OPTS

    SKIP_DOWNLOAD=0
    OPTS=$(getopt \
           -o "hsv:" \
           --long "skip-download,help,version:" \
           -n "${0}" -- "$@")
    # shellcheck disable=SC2181
    if [ $? != 0 ]; then print_usage; fi
    eval set -- "${OPTS}"
    while true; do
        case "$1" in
            -h|--help)
                print_usage 0
                ;;
            -s|--skip-download)
                SKIP_DOWNLOAD=1
                shift
                ;;
            -v|--version)
                SQUID_VER="${2}"
                SQUID_PKG="${SQUID_VER}-1"
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

    if [[ ${EUID} -eq 0 ]]; then
        echo "This script must NOT be run as root" 1>&2
        exit 1
    fi

    if [[ ${SKIP_DOWNLOAD} -eq 0 ]]; then
        # drop squid build folder
        rm -rf build/squid
    fi
    mkdir -p build/squid
    cd build/squid

    if [[ ${SKIP_DOWNLOAD} -eq 0 ]]; then
        # get squid from debian experimental
        wget "http://http.debian.net/debian/pool/main/s/squid/squid_${SQUID_PKG}.dsc"
        wget "http://http.debian.net/debian/pool/main/s/squid/squid_${SQUID_VER}.orig.tar.xz"
        wget "http://http.debian.net/debian/pool/main/s/squid/squid_${SQUID_VER}.orig.tar.xz.asc"
        wget "http://http.debian.net/debian/pool/main/s/squid/squid_${SQUID_PKG}.debian.tar.xz"

        dpkg-source -x "squid_${SQUID_PKG}.dsc"
    fi
    cd "squid-${SQUID_VER}" && \
         dpkg-buildpackage -rfakeroot -b -us -uc
}

main "$@"
