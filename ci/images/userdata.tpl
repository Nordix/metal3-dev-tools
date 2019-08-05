## template: jinja
#cloud-config
users:
  - name: ${DEFAULT_SSH_USER}
    ssh-authorized-keys:
      - ${SSH_AUTHORIZED_KEY}
    sudo: ['ALL=(ALL) NOPASSWD:ALL']
    groups: sudo
    shell: /bin/bash

runcmd:
  - sed -i "/^127.0.0.1/ s/$/ {{ ds.meta_data.name }}/" /etc/hosts
