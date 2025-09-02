#! /usr/bin/env bash

set -eu

# Description:
# Adds or updates user on jumphost. This script is executed on
# the same machine where user needs to be added and it is invoked by
# add_jumphost_user.sh script. It performs following actions for the user.
# - Adds a group for proxy users if not present
# - Add SSH configuration for proxy user's group.
# - Adds the user if not already present.
# - Overwrites any existing authorized keys for user.
#
# Usage:
#   add_proxy_user.sh <user_name> <file_path_containing_all_user_keys>
#

PROXY_USER="${1:?}"
PROXY_USER_AUTHORIZED_KEYS_PATH="${2:?}"
PROXY_USERS_GROUP="proxy_users"

# Create proxy_user group if not present already
sudo groupadd -f "${PROXY_USERS_GROUP}" > /dev/null

# Add proxy users group SSH config if not already present
if ! grep "#__START_PROXY_GROUP__" /etc/ssh/sshd_config > /dev/null
then

  sudo cat <<EOT | sudo tee -a /etc/ssh/sshd_config

#__START_PROXY_GROUP__
Match GROUP ${PROXY_USERS_GROUP}
    AllowTcpForwarding yes
    ForceCommand /usr/sbin/nologin
    KbdInteractiveAuthentication no
    PasswordAuthentication no
    PubkeyAuthentication yes
    PermitRootLogin no
    PermitTTY no
    MaxSessions 0
#__END_PROXY_GROUP__
EOT

  # TODO: revise the logic to restart the SSH daemon
  if [[ -r "/usr/lib/systemd/system/ssh.service" ]]
  then
    sudo systemctl restart ssh
  else
    sudo systemctl restart sshd
  fi
fi

# Add user if not present
sudo adduser --disabled-password --shell /usr/sbin/nologin --gecos "" "${PROXY_USER}" > /dev/null || true

# Add user to proxy users group if not present
sudo usermod -a -G "${PROXY_USERS_GROUP}" "${PROXY_USER}" > /dev/null || true

# Add users authorized SSH keys (overwrite if already exists)
sudo mkdir -p "/home/${PROXY_USER}/.ssh"
sudo mv -f "${PROXY_USER_AUTHORIZED_KEYS_PATH}" "/home/${PROXY_USER}/.ssh/authorized_keys"
sudo chown -R "${PROXY_USER}":"${PROXY_USER}" "/home/${PROXY_USER}/.ssh"
sudo chmod 700 "/home/${PROXY_USER}/.ssh"
sudo chmod 644 "/home/${PROXY_USER}/.ssh/authorized_keys"
