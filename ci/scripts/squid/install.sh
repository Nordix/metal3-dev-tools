#!/usr/bin/env bash

set -eu

CERT_CACHE_SIZE="4MB"
SQUID_PORT="3128"
MAX_OBJECT_SIZE="2 GB"
CACHE_SIZE="10000"
ALLOWED_NET="10.0.0.0/8"
R_MIN="0"
R_PCT="0"
R_MAX="0"

# shellcheck source=ci/scripts/squid/build.sh
. squid_ver.sh

# Install Squid
install_squid() {

    # install squid packages
    sudo apt-get install squid-langpack
    dpkg --install "build/squid/squid-common_${SQUID_PKG}_all.deb"
    dpkg --install "build/squid/squid_${SQUID_PKG}_amd64.deb"
    dpkg --install "build/squid/squid-openssl_${SQUID_PKG}_amd64.deb"

    # switch to openssl based squid
    update-alternatives --set squid /usr/sbin/squid-openssl
}

# Generate certificate
generate_certificate() {
    openssl req \
      -new \
      -newkey rsa:2048 \
      -days 3650 \
      -nodes -x509 \
      -keyout /tmp/squid-ca-key.pem \
      -out ./squid-ca-cert.pem \
      -subj "/C=FI/ST=Uusimaa/L=Jorvas/O=EST/OU=ESJ/CN=squid/emailAddress=estjorvas@est.tech"
    cat ./squid-ca-cert.pem /tmp/squid-ca-key.pem > /etc/squid/squid-ca.pem

    echo "=================================================="
    echo "Transfer './squid-ca-cert.pem' as \
'/usr/local/share/ca-certificates/squid-self-signed.crt' \
to all nodes using the proxy and run 'update-ca-certificates'."
    echo "=================================================="
}

# Reconfigure
reconfigure_squid() {
    local INSTR PATTERN INSERT VALUE CONF RULES BLOCK DOMAIN

    echo "Stopping squid..."
    systemctl stop squid

    CONF="/etc/squid/squid.conf"

    INSTR=(
        "acl localnet src fe80::/10"
          "acl myacl src " "${ALLOWED_NET}\t\t# Metal3 nodes"
        "http_access allow localhost$"
          "http_access allow myacl" ""
        "# maximum_object_size 4 MB$"
          "maximum_object_size " "${MAX_OBJECT_SIZE}"
        "#cache_dir ufs /var/spool/squid 100 16 256$"
          "cache_dir ufs /var/spool/squid " "${CACHE_SIZE} 16 256"
        "http_port 3128"
          "http_port " "${SQUID_PORT} \
ssl-bump \
cert=/etc/squid/squid-ca.pem \
generate-host-certificates=on \
dynamic_cert_mem_cache_size=${CERT_CACHE_SIZE}"
        "# sslcrtd_program /usr/lib/squid/security_file_certgen"
          "sslcrtd_program \
/usr/lib/squid/security_file_certgen \
-s /var/spool/squid/ssl_db -M " "${CERT_CACHE_SIZE}"
        "# Become a TCP tunnel without "
          "acl step1 at_step SslBump1" ""
        "acl step1 at_step SslBump1$"
          "ssl_bump peek step1" ""
        "ssl_bump peek step1$"
          "ssl_bump bump all" ""
    )

    for ((i=0; i<${#INSTR[@]}-1; i+=3)); do
        PATTERN="${INSTR[i]}"
        INSERT="${INSTR[i+1]}"
        VALUE="${INSTR[i+2]}"

        # If INSERT is not found, add it and VALUE after
        # PATTERN. Otherwise replace the existing line.
        if ! grep -q "^${INSERT}" "${CONF}"; then
            sed -i "\|^${PATTERN}|a ${INSERT}${VALUE}" "${CONF}"
        else
            sed -i "s|^${INSERT}.*|${INSERT}${VALUE}|" "${CONF}"
        fi
    done

    # remove old refresh patterns
    if grep -q "^# Start of refresh patterns$" "${CONF}"; then
        sed -i '/^# Start of refresh patterns/,/^# End of refresh patterns/d' \
               "${CONF}"
    fi

    # construct the rules for refresh patterns
    RULES=(
        "# Start of refresh patterns\\n"
    )
    for DOMAIN in "$@"; do
        RULES+=( "refresh_pattern ^${DOMAIN//./\\.}\t${R_MIN}\t${R_PCT}%\t\
${R_MAX}\trefresh-ims\\n" )
    done
    RULES+=( "# End of refresh patterns" )

    # append refresh patterns
    BLOCK=$(printf "%s" "${RULES[@]}")
    sed -i "\|^refresh_pattern -i (/cgi-bin/|a ${BLOCK}" "${CONF}"

    # append header processing rules
    if ! grep -q "^# Always include validation headers in backend requests" \
                 "${CONF}"; then
        cat >> "${CONF}" << EOF

# Always include validation headers in backend requests
request_header_access If-Modified-Since allow all
request_header_access If-None-Match allow all
request_header_access Cache-Control allow all

# Preserve ETag headers
reply_header_access ETag allow all
reply_header_access Last-Modified allow all
reply_header_access X-Checksum-Sha1 allow all
reply_header_access X-Checksum-Sha256 allow all
reply_header_access X-Checksum-Md5 allow all
EOF
    fi

    # clear squid cache
    rm -rf /var/spool/squid/*
    squid -Nz

    # generate cert cache
    /usr/lib/squid/security_file_certgen -c -s \
        /var/spool/squid/ssl_db -M 4MB

    echo "Starting squid..."
    systemctl start squid
}

USAGE="
Usage:
    $(basename "${0}") [opts]

Install Squid ${SQUID_VER} from a custom build.

Options are as follows:

  -a, --allowed-net=SIZE
    access allowed from; default '${ALLOWED_NET}'

  -c, --cache-size=SIZE
    size of the cache in MB; default '${CACHE_SIZE}'

  -h, --help
    display this help and exit

  -i, --include-site=SITE
    include specified site in refresh patterns

  -p, --squid-port=PORT
    port Squid should listen to; default '${SQUID_PORT}'

  -m, --maximum-object-size=SIZE
    maximum object size to cache; default '${MAX_OBJECT_SIZE}'

  -r, --reconfigure-only
    only reconfigure Squid

  -s, --cert-cache-size=SIZE
    set the cert cache size for SSL bumping; default '${CERT_CACHE_SIZE}'

  --r-min=VALUE
    min is the time (in minutes) an object without an explicit expiry time
    should be considered fresh; default '${R_MIN}'

  --r-pct=VALUE
    percent is used to compute the max-age value for responses with a
    Last-Modified header and no Cache-Control:max-age nor Expires;
    default '${R_PCT}'

  -r-max=VALUE
    max is an upper limit on how long objects without an explicit expiry time
    will be considered fresh; default '${R_MAX}'

  -v, --version=VERSION
    Squid version to install; default '${SQUID_VER}'
"

print_usage() {
    echo >&2 -e "${USAGE}"
    exit "${1:-1}"
}

# Main execution
main() {
    local RECONFIGURE_ONLY OPTS SITE

    SITE=()
    RECONFIGURE_ONLY=0
    OPTS=$(getopt \
           -o "a:c:hi:p:m:rs:v:" \
           --long "allowed-net:,cache-size:,help,include-site:,squid-port:,\
                   maximum-object-size:,reconfigure-only,\
                   cert-cache-size:,r-min:,r-pct:,r-max:version:" \
           -n "${0}" -- "$@")
    # shellcheck disable=SC2181
    if [ $? != 0 ]; then print_usage; fi
    eval set -- "${OPTS}"
    while true; do
        case "$1" in
            -a|--allowed-net)
                ALLOWED_NET="${2}"
                shift 2
                ;;
            -c|--cache-size)
                CACHE_SIZE="${2}"
                shift 2
                ;;
            -h|--help)
                print_usage 0
                ;;
            -i|--include-site)
                SITE+=( "${2}" )
                shift 2
                ;;
            -p|--squid-port)
                SQUID_PORT="${2}"
                shift 2
                ;;
            -m|--maximum-object-size)
                MAX_OBJECT_SIZE="${2}"
                shift 2
                ;;
            -r|--reconfigure-only)
                RECONFIGURE_ONLY=1
                shift
                ;;
            -s|--cert-cache-size)
                CERT_CACHE_SIZE="${2}"
                shift 2
                ;;
            --r-min)
                R_MIN="${2}"
                shift 2
                ;;
            --r-pct)
                R_PCT="${2}"
                shift 2
                ;;
            --r-max)
                R_MAX="${2}"
                shift 2
                ;;
            -v|--version)
                export SQUID_VER="${2}"
                export SQUID_PKG="${SQUID_VER}-1"
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

    if [[ ${EUID} -ne 0 ]]; then
        echo "This script must be run as root" 1>&2
        exit 1
    fi

    if [[ ${RECONFIGURE_ONLY} -eq 0 ]]; then
        install_squid
        generate_certificate
    fi
    reconfigure_squid "${SITE[@]}"
}

main "$@"
