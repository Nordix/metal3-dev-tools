#!/bin/bash
# Collect monitoring data with atop and sar
# https://aws.amazon.com/premiumsupport/knowledge-center/ec2-linux-configure-monitoring-tools/

## Install atop and sar
sudo dnf -y install https://dl.fedoraproject.org/pub/epel/epel-release-latest-8.noarch.rpm -y
sudo dnf -y install sysstat atop --enablerepo=epel

## Collect all metrics every minute
sudo sed -i 's/^LOGINTERVAL=600.*/LOGINTERVAL=60/' /etc/sysconfig/atop
sudo mkdir -v /etc/systemd/system/sysstat-collect.timer.d/
sudo bash -c "sed -e 's|every 10 minutes|every 1 minute|g' -e '/^OnCalendar=/ s|/10$|/1|' /usr/lib/systemd/system/sysstat-collect.timer > /etc/systemd/system/sysstat-collect.timer.d/override.conf"
sudo sed -i 's|^SADC_OPTIONS=.*|SADC_OPTIONS=" -S XALL"|' /etc/sysconfig/sysstat

## Reduce metrics retention to 3 days
sudo sed -i 's/^LOGGENERATIONS=.*/LOGGENERATIONS=3/' /etc/sysconfig/atop
sudo sed -i 's|^HISTORY=.*|HISTORY=3"|' /etc/sysconfig/sysstat

## Standardize sysstat log directory
sudo mkdir -p /var/log/sysstat
sudo sed -i 's|^SA_DIR=.*|SA_DIR="/var/log/sysstat"|' /etc/sysconfig/sysstat

## Enable services
systemctl enable atop.service crond.service sysstat.service
