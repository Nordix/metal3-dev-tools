#! /usr/bin/env bash
​
COMMON_PASS_PATH=/etc/pam.d/common-password
SYSTEM_AUTH_PATH=/etc/pam.d/common-auth
​
# Declares ssh values to set in /etc/ssh/sshd_config
declare -A ssh_values=(
  [PermitRootLogin]=no
  [IgnoreRhosts]=yes
  [HostbasedAuthentication]=no
  [PermitEmptyPasswords]=no
  [X11Forwarding]=no
  [MaxAuthTries]=5
  [Ciphers]="aes128-ctr,aes192-ctr,aes256-ctr"
  [ClientAliveInterval]=900
  [ClientAliveCountMax]=0
  [UsePAM]=yes
  [Protocol]=2
)
​
# Parameters to secure networking /etc/sysctl.conf
declare -A network_parameters=(
  [net.ipv4.ip_forward]=0
  [net.ipv4.conf.all.send_redirects]=0
  [net.ipv4.conf.default.send_redirects]=0
  [net.ipv4.conf.all.accept_redirects]=0
  [net.ipv4.conf.default.accept_redirects]=0
  [net.ipv4.icmp_ignore_bogus_error_responses]=1
  [fs.suid_dumpable]=0
  [kernel.exec-shield]=1
  [kernel.randomize_va_space]=2
)
​
set_value() {
  PARAMETER_NAME="${1}"
  PARAMETER_VALUE="${2}"
  FILE="$3"
  SEPARATOR="$4"
  VALUE="${PARAMETER_NAME}${SEPARATOR}${PARAMETER_VALUE}"
​
  if sudo grep -q "${PARAMETER_NAME}" "${FILE}"; then
    sudo sed -i "0,/.*${PARAMETER_NAME}.*/s//${VALUE}/" "${FILE}"
  else
    echo "${VALUE}" | sudo tee -a "${FILE}" > /dev/null
  fi
}
​
# Loop through ssh_values
for i in "${!ssh_values[@]}"
do
    name="${i}"
    value="${ssh_values[$i]}"
    set_value "${name}" "${value}" /etc/ssh/sshd_config " "
done
​
# Set the permissions on the sshd_config file so that only root users can change its contents
sudo chown root:root /etc/ssh/sshd_config
sudo chmod 600 /etc/ssh/sshd_config
​
# Loop through networking table
for i in "${!network_parameters[@]}"; do
  name="${i}"
  value="${network_parameters[$i]}"
  set_value "${name}" "${value}" /etc/sysctl.conf "="
done
​
# Remove legacy services
sudo apt-get -y --purge remove telnet
sudo apt-get -y autoremove
​
​
# Add password policies
echo auth sufficient pam_unix.so likeauth nullok | sudo tee -a "${COMMON_PASS_PATH}" > /dev/null
echo password sufficient pam_unix.so remember=4 | sudo tee -a "${COMMON_PASS_PATH}" > /dev/null
echo /lib/security/$ISA/pam_cracklib.so retry=3 minlen=8 lcredit=-1 ucredit=-2 dcredit=-2 ocredit=-1 | sudo tee -a "${SYSTEM_AUTH_PATH}" > /dev/null
​
# Lock the account after five failed attempts
cat << EOL | sudo tee -a "${COMMON_PASS_PATH}" > /dev/null 
auth required pam_env.so
auth required pam_faillock.so preauth audit silent deny=5 unlock_time=900
auth [success=1 default=bad] pam_unix.so
auth [default=die] pam_faillock.so authfail audit deny=5 unlock_time=900
auth sufficient pam_faillock.so authsucc audit deny=5 unlock_time=900
auth required pam_deny.so
EOL
​
cat << EOL | sudo tee -a "${SYSTEM_AUTH_PATH}" > /dev/null
auth required pam_env.so
auth required pam_faillock.so preauth audit silent deny=5 unlock_time=900
auth [success=1 default=bad] pam_unix.so
auth [default=die] pam_faillock.so authfail audit deny=5 unlock_time=900
auth sufficient pam_faillock.so authsucc audit deny=5 unlock_time=900
auth required pam_deny.so
EOL
​
​
# Set the password to expire after 90 days
sudo sed -i '/^PASS_MAX_DAYS/ c\PASS_MAX_DAYS\t90' /etc/login.defs
​
​
# Disable the system accounts for non-root users
for user in $(awk -F: '($3 < 500) {print $1 }' /etc/passwd); do
  if [ "$user" != "root" ]; then
    sudo /usr/sbin/usermod -L "$user"
    if [ "$user" != "sync" ] && [ "$user" != "shutdown" ] && [ "$user" != "halt" ]; then
      sudo /usr/sbin/usermod -s /sbin/nologin "$user"
    fi
  fi
done
​
# Set User/Group Owner and Permission on “/etc/anacrontab”, “/etc/crontab” and “/etc/cron
sudo chown root:root /etc/crontab /etc/cron.hourly /etc/cron.daily /etc/cron.weekly /etc/cron.monthly /etc/cron.d
sudo chmod og-rwx /etc/crontab /etc/cron.hourly /etc/cron.daily /etc/cron.weekly /etc/cron.monthly /etc/cron.d
​
# Set the right and permissions on root crontab
sudo chown root:root /var/spool/cron/crontabs
sudo chmod og-rwx /var/spool/cron/crontabs
​
# Set User/Group Owner and Permission on “passwd” file
sudo chmod 644 /etc/passwd
sudo chown root:root /etc/passwd
​
# Set User/Group Owner and Permission on the “group” file
sudo chmod 644 /etc/group
sudo chown root:root /etc/group
​
#Set User/Group Owner and Permission on the “shadow” file
sudo chmod 600 /etc/shadow
sudo chown root:root /etc/shadow
​
# Set User/Group Owner and Permission on the “gshadow” file
sudo chmod 600 /etc/gshadow
sudo chown root:root /etc/gshadow
​
# Restrict Core Dumps
echo '* hard core 0' | sudo tee -a /etc/security/limits.conf > /dev/null