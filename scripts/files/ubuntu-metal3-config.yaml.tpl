#cloud-config
package_update: true
package_upgrade: true
users:
  - name: airshipci
    groups: sudo
    lock_passwd: false
    shell: /bin/bash
    sudo: ['ALL=(ALL) NOPASSWD:ALL']
    ssh-authorized-keys:
      - <key>
