#cloud-config
users:
  - name: ${DEFAULT_SSH_USER}
    ssh-authorized-keys:
      - ${SSH_AUTHORIZED_KEY}
    sudo: ['ALL=(ALL) NOPASSWD:ALL']
    groups: ${DEFAULT_SSH_USER_GROUP}
    shell: /bin/bash

runcmd:
  - sed -i "/^127.0.0.1/ s/$/ ${HOSTNAME}/" /etc/hosts
  - systemctl stop NetworkManager.service
  - systemctl mask NetworkManager.service
