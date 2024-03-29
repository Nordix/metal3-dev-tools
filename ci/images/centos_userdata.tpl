#cloud-config
users:
  - name: ${USERDATA_SSH_USER}
    ssh-authorized-keys:
      - ${USERDATA_SSH_AUTHORIZED_KEY}
    sudo: ["ALL=(ALL) NOPASSWD:ALL"]
    groups: ${USERDATA_SSH_USER_GROUP}
    shell: /bin/bash

runcmd:
  - sed -i "/^127.0.0.1/ s/$/ ${USERDATA_HOSTNAME}/" /etc/hosts
  - sed -i 's/#Storage.*/Storage=persistent/' /etc/systemd/journald.conf
