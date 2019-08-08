#! /usr/bin/env bash

# This script will remove any cloud init's previous run
# data and force cloud-init to again on next boot.

sudo rm -rf /var/lib/cloud/*
