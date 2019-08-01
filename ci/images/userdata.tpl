#cloud-config
users:
  - name: ${DEFAULT_SSH_USER}
    ssh-authorized-keys:
      - ${SSH_AUTHORIZED_KEY}
    sudo: ['ALL=(ALL) NOPASSWD:ALL']
    groups: sudo
    shell: /bin/bash
