#cloud-config
users:
  - name: ${DEFAULT_SSH_USER}
    ssh-authorized-keys:
      - ${SSH_AUTHORIZED_KEY}
      - "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIIpxfHuI2qfTYPrL4+thyHSS78Qj9ehp2/GYxuNXthgS estjorvas@est.tech"
    sudo: ['ALL=(ALL) NOPASSWD:ALL']
    groups: ${DEFAULT_SSH_USER_GROUP}
    shell: /bin/bash

runcmd:
  - sed -i "/^127.0.0.1/ s/$/ ${HOSTNAME}/" /etc/hosts
  - update-crypto-policies --set LEGACY
  - systemctl restart sshd.service
  - echo "options kvm tdp_mmu=0" >> /etc/modprobe.d/kvm.conf

