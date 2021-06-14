#!/bin/bash

command="$@"
# example: ./run-openstack-command.sh openstack keypair list 
docker run --rm -it -v /tmp/openstackrc:/tmp/openstackrc openstacktools/openstack-client bash -c "source /tmp/openstackrc && ${command}"
