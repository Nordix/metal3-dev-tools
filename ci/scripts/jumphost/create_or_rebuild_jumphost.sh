#!/usr/bin/env bash

set -euo pipefail

# Description:
#   Creates or rebuilds a jumphost in openstack environment.
#   Requires:
#     - source stackrc file
#     - openstack CLI installed
#     - openstack infra should already be deployed.
#     - jq installed
# Usage:
#  create_or_rebuild_jumphost.sh
#

CI_DIR="$(dirname "$(readlink -f "${0}")")/../.."
COMMON_SCRIPTS_DIR="${CI_DIR}/scripts/common"
OS_SCRIPTS_DIR="${CI_DIR}/scripts/openstack"

# shellcheck source=ci/scripts/common/opts.sh
. "${COMMON_SCRIPTS_DIR}/opts.sh"
# shellcheck source=ci/scripts/common/utils.sh
. "${COMMON_SCRIPTS_DIR}/utils.sh"
# shellcheck source=ci/scripts/openstack/utils.sh
. "${OS_SCRIPTS_DIR}/utils.sh"
# shellcheck source=ci/scripts/openstack/infra_defines.sh
. "${OS_SCRIPTS_DIR}/infra_defines.sh"

USAGE=$(common_make_usage_string \
        --one-liner "Create or rebuild a jumphost in openstack environment." \
        ${COMMON_OPT_DRYRUN} \
        ${COMMON_OPT_HELP} \
        ${COMMON_OPT_KEYFILE} \
        ${COMMON_OPT_TARGET} \
        ${COMMON_OPT_USER} \
        ${COMMON_OPT_VERBOSE})
common_parse_options "${USAGE}" "$@"

# Sanity checks
# =============
common_validate_target
common_validate_keyfile
common_validate_user

KEYPAIR_NAME="${COMMON_OPT_TARGET_VALUE}_KEYPAIR_NAME"
EXT_NETWORK="${COMMON_OPT_TARGET_VALUE}_EXT_NETWORK"
NETWORK="${COMMON_OPT_TARGET_VALUE}_NETWORK"
JUMPHOST_NAME="${COMMON_OPT_TARGET_VALUE}_JUMPHOST_NAME"
JUMPHOST_IMAGE="${COMMON_OPT_TARGET_VALUE}_JUMPHOST_IMAGE"
JUMPHOST_EXT_SG="${COMMON_OPT_TARGET_VALUE}_JUMPHOST_EXT_SG"
JUMPOST_EXT_PORT_NAME="${!JUMPHOST_NAME}-ext-port"
JUMPHOST_FLAVOR="${COMMON_OPT_TARGET_VALUE}_JUMPHOST_FLAVOR"
JUMPHOST_FLOATING_IP_TAG="${COMMON_OPT_TARGET_VALUE}_JUMPHOST_FLOATING_IP_TAG"

# Create or rebuild jumphost image
ARGS=(
  server list
  --name "${!JUMPHOST_NAME}"
  -f json
)

JUMPHOST_SERVER_ID="$(openstack "${ARGS[@]}" \
  | jq -r 'map(.ID) | @csv' \
  | tr ',' '\n' \
  | tr -d '"')"

if [[ -n "${JUMPHOST_SERVER_ID}" ]]; then
  ARGS=(
    openstack server rebuild
    --image "${!JUMPHOST_IMAGE}"
    "${JUMPHOST_SERVER_ID}"
  )
  common_verbose "Rebuilding the jumphost ${!JUMPHOST_NAME}"\
                 "image=${!JUMPHOST_IMAGE},"\
                 "id=${JUMPHOST_SERVER_ID}..."
  common_run -- "${ARGS[@]}" > /dev/null
else
  # Cleanup any stale ports
  delete_port "${JUMPOST_EXT_PORT_NAME}"

  # Cleanup any existing security group
  delete_sg "${!JUMPHOST_EXT_SG}"

  # Create a new security group
  common_verbose "Creating a new security group name=${!JUMPHOST_EXT_SG}..."

  ARGS=(
    openstack security group create -f json "${!JUMPHOST_EXT_SG}"
  )
  OPTS=(
    -o "{ \"id\": \"<SG-ID>\" }"
  )
  SG_ID="$(common_run "${OPTS[@]}" -- "${ARGS[@]}" | jq -r '.id')"

  ARGS=(
    openstack security group rule create
    --ingress
    --description ssh
    --ethertype IPv4
    --protocol tcp
    --dst-port 22
    "${SG_ID}"
  )
  common_run -- "${ARGS[@]}" > /dev/null
  common_verbose "ID: ${SG_ID}"

  # Create a new port
  common_verbose "Creating new jumphost port"\
                 "subnet=$(get_subnet_name "${!NETWORK}"),"\
                 "security-group=${SG_ID},"\
                 "name=${JUMPOST_EXT_PORT_NAME}..."

  ARGS=(
    openstack port create
    -f json
    --network "${!NETWORK}"
    --fixed-ip subnet="$(get_subnet_name "${!NETWORK}")"
    --enable-port-security
    --security-group "${SG_ID}"
    "${JUMPOST_EXT_PORT_NAME}"
  )
  OPTS=(
    -o "{ \"id\": \"<PORT-ID>\" }"
  )
  EXT_PORT_ID="$(common_run "${OPTS[@]}" -- "${ARGS[@]}" | jq -r '.id')"
  common_verbose "ID: ${EXT_PORT_ID}"

  CLOUD_INIT="$(mktemp)"
  cat << EOF >> "${CLOUD_INIT}"
#cloud-config
system_info:
  default_user:
    name: ${COMMON_OPT_USER_VALUE}
EOF

  # Create new jumphost
  common_verbose "Creating a new jumphost server"\
                 "image=${!JUMPHOST_IMAGE},"\
                 "flavor=${!JUMPHOST_FLAVOR},"\
                 "key-name=${!KEYPAIR_NAME},"\
                 "user-data=${CLOUD_INIT},"\
                 "port=${EXT_PORT_ID},"\
                 "name=${!JUMPHOST_NAME}..."

  ARGS=(
    openstack server create
    -f json
    --image "${!JUMPHOST_IMAGE}"
    --flavor "${!JUMPHOST_FLAVOR}"
    --key-name "${!KEYPAIR_NAME}"
    --user-data "${CLOUD_INIT}"
    --port "${EXT_PORT_ID}"
    "${!JUMPHOST_NAME}"
  )
  OPTS=(
    -o "{ \"id\": \"<SERVER-ID>\" }"
  )
  JUMPHOST_SERVER_ID="$(common_run "${OPTS[@]}" -- "${ARGS[@]}" | jq -r '.id')"
  common_verbose "ID: ${JUMPHOST_SERVER_ID}"

  rm -f "${CLOUD_INIT}"
fi

# Recycle or create floating IP and assign it to jumphost port
FLOATING_IP_ID="$(openstack \
    floating ip list --tags "${!JUMPHOST_FLOATING_IP_TAG}" -f json \
    | jq -r 'map(.ID) | @csv' \
    | tr ',' '\n' \
    | tr -d '"')"

CMD=()
if [[ -n "${FLOATING_IP_ID}" ]]; then
  ARGS=(
    openstack floating ip unset --port "${FLOATING_IP_ID}"
  )
  common_verbose "Disassociate floating IP (${FLOATING_IP_ID})..."
  common_run -- "${ARGS[@]}" > /dev/null

  common_verbose "Associate floating IP to new jumphost port"\
                 "port=${JUMPOST_EXT_PORT_NAME},"\
                 "id=${FLOATING_IP_ID}..."

  ARGS=(
    openstack floating ip set
    --port "${JUMPOST_EXT_PORT_NAME}"
    "${FLOATING_IP_ID}"
  )
  common_run -- "${ARGS[@]}" > /dev/null
else
  common_verbose "Creating a new jumphost floating IP"\
                 "port=${JUMPOST_EXT_PORT_NAME},"\
                 "tag=${!JUMPHOST_FLOATING_IP_TAG},"\
                 "net=${!EXT_NETWORK}..."

  ARGS=(
    openstack floating ip create
    -f json
    --port "${JUMPOST_EXT_PORT_NAME}"
    --description "\"Reserved for ${!JUMPHOST_NAME}\""
    --tag "${!JUMPHOST_FLOATING_IP_TAG}"
    "${!EXT_NETWORK}"
  )
  OPTS=(
    -o "{ \"id\": \"<FLOATING-IP-ID>\" }"
  )
  FLOATING_IP_ID="$(common_run "${OPTS[@]}" -- "${ARGS[@]}" | jq -r '.id')"
  common_verbose "ID: ${FLOATING_IP_ID}"
  CMD=("common_run" "-o" "[ { \"Floating IP Address\": \"<IP>\" } ]" --)
fi

FLOATING_IP_ADDRESS="$("${CMD[@]}" \
  openstack floating ip list --tags "${!JUMPHOST_FLOATING_IP_TAG}" -f json \
  | jq -r 'map(."Floating IP Address") | @csv' \
  | tr ',' '\n' \
  | tr -d '"')"

echo "Jumphost public IP: ${FLOATING_IP_ADDRESS}"
ARGS=(
  wait_for_ssh
  "${COMMON_OPT_USER_VALUE}"
  "${COMMON_OPT_KEYFILE_VALUE}"
  "${FLOATING_IP_ADDRESS}"
)
common_run -- "${ARGS[@]}"
