#! /usr/bin/env bash

set -eu

sudo apt-get install -y chrony
sudo chronyc -a 'burst 4/4' && sudo chronyc -a makestep
sudo systemctl enable chrony
sudo systemctl start chrony
