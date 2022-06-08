#!/bin/bash

export SSH_USER_NAME="metal3ci"
export SSH_USER_GROUP="sudo"
export SSH_KEYPAIR_NAME="metal3ci-key"
export SSH_PUBLIC_KEY_FILE="/home/kashif/.ssh/id_ed25519_metal3ci.pub"
export SSH_PRIVATE_KEY_FILE="/home/kashif/.ssh/id_ed25519_metal3ci"
export IMAGE_NAME="metal3ci-test-centos"
export SOURCE_IMAGE_NAME="CentOS-Stream-GenericCloud-8"
# Default project, Fra1 region.
# export NETWORK="766a7747-df11-4873-9e36-03369cff7499"
# Default project, Kna1 region
# export NETWORK="375af7fe-a2c1-4c26-a57d-6d33175a6650"
# dev2, Kna1
export NETWORK="375af7fe-a2c1-4c26-a57d-6d33175a6650"