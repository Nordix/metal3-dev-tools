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
  - sed -i '/ClientAliveInterval\|ClientAliveCountMax\|TCPKeepAlive/d' /etc/ssh/sshd_config
  - echo "ClientAliveInterval 60" >> /etc/ssh/sshd_config
  - echo "ClientAliveCountMax 60" >> /etc/ssh/sshd_config
  - echo "TCPKeepAlive no" >> /etc/ssh/sshd_config
  - systemctl restart sshd.service
