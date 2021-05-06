
SHELL := /bin/bash
CLUSTER_NAME := "basic-1"
all: yq configure # change_me
yq:
	docker build -t golang:yq -f Dockerfile.yq .
configure: #ok
	./configure.sh cacert.pem
	sed -i -e 's/^/export /' /tmp/capo_openstackrc
capo-cluster: #ok
	./createcapo-cluster.sh
openstack: #ok
	docker run -it --rm \
		-v /tmp/openstackrc:/tmp/openstackrc \
		openstacktools/openstack-client \
		/usr/bin/env BASH_ENV=/tmp/openstackrc /bin/bash -c openstack

deploy-workload:
	clusterctl config cluster $(CLUSTER_NAME) --kubernetes-version v1.19.1 > /tmp/$(CLUSTER_NAME).yaml 
update-workload: # todo [replace ext network, ssh key]
	docker run --rm \
		-v /tmp/openstackrc:/tmp/openstackrc \
		openstacktools/openstack-client \
		/usr/bin/env BASH_ENV=/tmp/openstackrc /bin/bash -c "openstack network show airship-ci-ext-net -f value -c id"
clean: # to do
	kubectl delete cluster $(CLUSTER_NAME) # do not remove using /tmp/$(CLUSTER_NAME).yaml  as order of deletion matters
	echo "remove resource in openstack if not removed with cluster" # to do
