#!/bin/bash
# Collect monitoring data with atop and sar
# https://aws.amazon.com/premiumsupport/knowledge-center/ec2-linux-configure-monitoring-tools/

## Install monitoring tools
sudo apt-get -y install atop sysstat

## Collect all metrics every minute
sudo sed -i 's/^LOGINTERVAL=600.*/LOGINTERVAL=60/' /usr/share/atop/atop.daily
sudo sed -i -e 's|5-55/10|*/1|' -e 's|every 10 minutes|every 1 minute|' -e 's|debian-sa1|debian-sa1 -S XALL|g' /etc/cron.d/sysstat
sudo bash -c "echo 'SA1_OPTIONS=\"-S XALL\"' >> /etc/default/sysstat"

## Reduce metrics retention to 3 days
sudo sed -i 's/^LOGGENERATIONS=.*/LOGGENERATIONS=3/' /usr/share/atop/atop.daily
sudo sed -i 's/^HISTORY=.*/HISTORY=3/' /etc/default/sysstat

## Enable services
sudo sed -i 's|ENABLED="false"|ENABLED="true"|' /etc/default/sysstat
sudo systemctl enable atop.service cron.service sysstat.service
