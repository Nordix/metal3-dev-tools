#cloud-config
users:
  - name: ${DEFAULT_SSH_USER}
    ssh-authorized-keys:
      - ${SSH_AUTHORIZED_KEY}
    sudo: ['ALL=(ALL) NOPASSWD:ALL']
    groups: ${DEFAULT_SSH_USER_GROUP}
    shell: /bin/bash
  - name: metal3ci
    ssh-authorized-keys:
      - ${SSH_AUTHORIZED_KEY}
    sudo: ['ALL=(ALL) NOPASSWD:ALL']
    groups: wheel
    shell: /bin/bash

runcmd:
  - sed -i "/^127.0.0.1/ s/$/ ${HOSTNAME}/" /etc/hosts
  # Make /etcd/resolv.conf immutable in order to prevent NetworkManager
  # from overriding DNS entries with values from DHCP servers
  # This removes network settings of the image building environment from the image.
  - echo $'nameserver 8.8.8.8\nnameserver 8.8.4.4' > /etc/resolv.conf
  - chattr +i /etc/resolv.conf
