set -e

#install kvm 
dnf -y install qemu-kvm libvirt virt-install 
systemctl enable --now libvirtd
# create a pool
mkdir /opt/mypool
cat <<EOF > /opt/mypool/mypool.xml
<pool type='dir'>
  <name>mypool</name>
  <target>
    <path>/opt/mypool</path>
  </target>
</pool>
EOF
virsh pool-define /opt/mypool/mypool.xml
virsh pool-start mypool
virsh pool-autostart mypool
virsh vol-create-as mypool node-1.qcow2 30G --format qcow2
virsh vol-create-as mypool node-2.qcow2 30G --format qcow2
# create provisioning network
cat <<EOF > provisioning-1.xml
<network
	xmlns:dnsmasq='http://libvirt.org/schemas/network/dnsmasq/1.0'>
	<dnsmasq:options>
		<!-- Risk reduction for CVE-2020-25684, CVE-2020-25685, and CVE-2020-25686. See: https://access.redhat.com/security/vulnerabilities/RHSB-2021-001 -->
		<dnsmasq:option value="cache-size=0"/>
	</dnsmasq:options>
	<name>provisioning-1</name>
	<bridge name='provisioning-1'/>
	<forward mode='bridge'></forward>
</network>
EOF
cat <<EOF > provisioning-2.xml
<network
	xmlns:dnsmasq='http://libvirt.org/schemas/network/dnsmasq/1.0'>
	<dnsmasq:options>
		<!-- Risk reduction for CVE-2020-25684, CVE-2020-25685, and CVE-2020-25686. See: https://access.redhat.com/security/vulnerabilities/RHSB-2021-001 -->
		<dnsmasq:option value="cache-size=0"/>
	</dnsmasq:options>
	<name>provisioning-2</name>
	<bridge name='provisioning-2'/>
	<forward mode='bridge'></forward>
</network>
EOF
cat <<EOF > baremetal.xml
<network xmlns:dnsmasq='http://libvirt.org/schemas/network/dnsmasq/1.0'>
  <name>baremetal</name>
  <forward mode='nat'>
    <nat>
      <port start='1024' end='65535'/>
    </nat>
  </forward>
  <bridge name='baremetal' stp='on' delay='0'/>
  <domain name='ostest.test.metalkube.org' localOnly='yes'/>
  <dns>
    <forwarder domain='apps.ostest.test.metalkube.org' addr='127.0.0.1'/>
  </dns>
  <ip address='192.168.111.1' netmask='255.255.255.0'>
    <dhcp>
      <range start='192.168.111.20' end='192.168.111.60'/>
      <host mac='00:5c:52:31:3b:9c' name='node-0' ip='192.168.111.20'>
        <lease expiry='60' unit='minutes'/>
      </host>
      <host mac='00:5c:52:31:3b:ad' name='node-1' ip='192.168.111.21'>
        <lease expiry='60' unit='minutes'/>
      </host>
    </dhcp>
  </ip>
  <dnsmasq:options>
    <dnsmasq:option value='cache-size=0'/>
  </dnsmasq:options>
</network>
EOF
# define networks
virsh net-define baremetal.xml 
virsh net-start baremetal
virsh net-autostart baremetal

virsh net-define provisioning-1.xml 
virsh net-start provisioning-1
virsh net-autostart provisioning-1

virsh net-define provisioning-2.xml 
virsh net-start provisioning-2
virsh net-autostart provisioning-2

yum install -y net-tools
echo -e "DEVICE=provisioning-1\nTYPE=Bridge\nONBOOT=yes\nBOOTPROTO=static\nIPADDR=172.22.0.1\nNETMASK=255.255.255.0" | sudo dd of=/etc/sysconfig/network-scripts/ifcfg-provisioning-1
echo -e "DEVICE=provisioning-2\nTYPE=Bridge\nONBOOT=yes\nBOOTPROTO=static\nIPADDR=172.23.0.1\nNETMASK=255.255.255.0" | sudo dd of=/etc/sysconfig/network-scripts/ifcfg-provisioning-2
echo -e "DEVICE=baremetal\nTYPE=Bridge\nONBOOT=yes\n" | sudo dd of=/etc/sysconfig/network-scripts/ifcfg-baremetal
systemctl restart NetworkManager.service
cat <<EOF > node-1.xml
<domain type='kvm'>
	<name>node-1</name>
	<memory unit='MiB'>8000</memory>
	<vcpu>2</vcpu>
	<os>
		<type arch='x86_64' machine='q35'>hvm</type>
		<nvram>/var/lib/libvirt/qemu/nvram/node-1.fd</nvram>
		<boot dev='network'/>
		<bootmenu enable='no'/>
	</os>
	<features>
		<acpi/>
		<apic/>
		<pae/>
	</features>
	<cpu mode='host-passthrough'/>
	<clock offset='utc'/>
	<on_poweroff>destroy</on_poweroff>
	<on_reboot>restart</on_reboot>
	<on_crash>restart</on_crash>
	<devices>
		<disk type='volume' device='disk'>
			<driver name='qemu' type='qcow2' cache='unsafe'/>
			<source pool='mypool' volume='node-1.qcow2'/>
			<target dev='sda' bus='scsi'/>
		</disk>
		<controller type='scsi' model='virtio-scsi' />
		<interface type='bridge'>
			<mac address='00:5c:52:31:3a:9c'/>
			<source bridge='provisioning-1'/>
			<model type='virtio'/>
		</interface>
		<interface type='bridge'>
			<mac address='00:5c:52:31:3b:9c'/>
			<source bridge='baremetal'/>
			<model type='virtio'/>
		</interface>
		<console type='pty'/>
		<input type='mouse' bus='ps2'/>
		<graphics type='vnc' port='-1' autoport='yes'/>
		<video>
			<model type='cirrus' vram='9216' heads='1'/>
		</video>
	</devices>
</domain>
EOF
cat <<EOF > node-2.xml
<domain type='kvm'>
	<name>node-2</name>
	<memory unit='MiB'>8000</memory>
	<vcpu>2</vcpu>
	<os>
		<type arch='x86_64' machine='q35'>hvm</type>
		<nvram>/var/lib/libvirt/qemu/nvram/node-2.fd</nvram>
		<boot dev='network'/>
		<bootmenu enable='no'/>
	</os>
	<features>
		<acpi/>
		<apic/>
		<pae/>
	</features>
	<cpu mode='host-passthrough'/>
	<clock offset='utc'/>
	<on_poweroff>destroy</on_poweroff>
	<on_reboot>restart</on_reboot>
	<on_crash>restart</on_crash>
	<devices>
		<disk type='volume' device='disk'>
			<driver name='qemu' type='qcow2' cache='unsafe'/>
			<source pool='mypool' volume='node-2.qcow2'/>
			<target dev='sda' bus='scsi'/>
		</disk>
		<controller type='scsi' model='virtio-scsi' />
		<interface type='bridge'>
			<mac address='00:5c:52:31:3a:ad'/>
			<source bridge='provisioning-2'/>
			<model type='virtio'/>
		</interface>
		<interface type='bridge'>
			<mac address='00:5c:52:31:3b:ad'/>
			<source bridge='baremetal'/>
			<model type='virtio'/>
		</interface>
		<console type='pty'/>
		<input type='mouse' bus='ps2'/>
		<graphics type='vnc' port='-1' autoport='yes'/>
		<video>
			<model type='cirrus' vram='9216' heads='1'/>
		</video>
	</devices>
</domain>
EOF
virsh define node-1.xml
virsh define node-2.xml
# install minikube
curl -LO https://storage.googleapis.com/minikube/releases/v1.25.2/minikube-linux-amd64
install minikube-linux-amd64 /usr/local/bin/minikube
# Install kubectl
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
