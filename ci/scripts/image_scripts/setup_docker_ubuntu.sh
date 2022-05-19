#! /usr/bin/env bash

sudo apt-get update
sudo apt-get install \
    apt-transport-https \
    ca-certificates \
    curl \
    gnupg-agent \
    software-properties-common
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -
sudo apt-key fingerprint 0EBFCD88
sudo add-apt-repository -y \
   "deb [arch=amd64] https://download.docker.com/linux/ubuntu \
   $(lsb_release -cs) \
   stable"
sudo apt-get update
sudo apt-get install -y docker-ce docker-ce-cli containerd.io jq
sudo groupadd docker
sudo usermod -aG docker "${USER}"
sudo usermod -aG docker ubuntu
# FIXME: remove this line once USER is always metal3ci
sudo usermod -aG docker metal3ci
sudo systemctl enable docker
sudo systemctl restart docker
