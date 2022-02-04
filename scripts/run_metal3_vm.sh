#!/bin/bash
set -uex


SCRIPTPATH="$(dirname "$(readlink -f "${0}")")"

WORK_DIR=/opt/metal3
sudo mkdir -p "$WORK_DIR"
sudo chown -R "${USER}:${USER}" "$WORK_DIR"

echo "Setting up SSH keys"
mkdir -p ~/.ssh
if [[ ! -f ~/.ssh/metal3 ]]; then
  ssh-keygen -q -N "" -f ~/.ssh/metal3
fi
cp "${SCRIPTPATH}/files/ubuntu-metal3-config.yaml.tpl" "$WORK_DIR/ubuntu-metal3-config.yaml"
sed -i '/    ssh-authorized-keys:/!b;n;c\      - '"$(cat ~/.ssh/metal3.pub)" "$WORK_DIR/ubuntu-metal3-config.yaml"

echo "Downloading Metal3 if needed"
if [[ ! -f "$WORK_DIR/ubuntu_metal3.qcow2" ]]; then
  openstack image save --file "$WORK_DIR/ubuntu_metal3.qcow2" metal3-ci-ubuntu-metal3-img
fi

vm_defined=$(virsh list --all | grep ubuntu-metal3 || true )
echo VM_DEFINED "$vm_defined"

if [[ ! -f "$WORK_DIR/ubuntu_metal3_vm.qcow2" ]] || [[ $vm_defined != *"ubuntu-metal3"* ]] ; then
  rm "$WORK_DIR/ubuntu_metal3_vm.qcow2" || true
  cp "$WORK_DIR/ubuntu_metal3.qcow2" "$WORK_DIR/ubuntu_metal3_vm.qcow2"
  # Resize this image
  qemu-img resize "$WORK_DIR/ubuntu_metal3_vm.qcow2" 50G


  echo "Creating config ISO"
  # Install this package to generate iso from qcow2 file
  sudo apt install  -y cloud-utils
  # Create file iso
  sudo rm "$WORK_DIR/config.iso" || true
  cloud-localds "$WORK_DIR/ubuntu-metal3-config.iso" "$WORK_DIR/ubuntu-metal3-config.yaml"

  echo "Creating virtual machine"
  # Create virtual machine
  virt-install \
    --memory 16384 \
    --vcpus 4 \
    --cpu host \
    --name ubuntu-metal3 \
    --disk "$WORK_DIR/ubuntu_metal3_vm.qcow2,device=disk" \
    --disk "$WORK_DIR/ubuntu-metal3-config.iso,device=cdrom" \
    --os-type Linux \
    --os-variant ubuntu18.04 \
    --virt-type kvm \
    --network network=default \
    --import \
    --graphics none \
    --console pty,target_type=serial \
    --noautoconsole

else

  vm_running=$(virsh list | grep ubuntu-metal3 || true)
  echo "Starting virtual machine"
  if  [[ $vm_running != *"ubuntu-metal3"* ]] ; then
    virsh start centos-metal3
  fi
fi

echo "Machine IP : $(sudo virsh net-dhcp-leases default | \
  grep "metal3-ci-ubuntu-metal3-img" | awk '{print $5}' \
  | cut -d '/' -f1)"
