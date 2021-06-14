SHELL := /bin/bash
CLUSTER_NAME := basic-1
OS_CLOUD_NAME := "openstack-1"
all: configure kind-create tilt-up 
provision: capo-template capo-apply
configure:
	./configure.sh $(OS_CLOUD_NAME)
kind-create:
	kind get clusters | grep -q kind-capo || kind create cluster --name kind-capo
tilt-up:
	./tilt_up.sh
capo-template:
	./clusterctl_template.sh $(CLUSTER_NAME) $(OS_CLOUD_NAME)
capo-apply:
	kubectl apply -f /tmp/$(CLUSTER_NAME).yaml
capo-kubeconfig:
	kubectl get secrets $(CLUSTER_NAME)-kubeconfig -o json | jq -r '.data.value' | base64 -d > "/tmp/$(CLUSTER_NAME)-kubeconfig.yaml"
	@echo Use kubectl --kubeconfig /tmp/$(CLUSTER_NAME)-kubeconfig.yaml to use the target cluster
openstack:
	docker run -it --rm \
		-v /tmp/openstackrc:/tmp/openstackrc \
		openstacktools/openstack-client \
		/usr/bin/env BASH_ENV=/tmp/openstackrc /bin/bash -c openstack
deprovision:
	kubectl delete cluster $(CLUSTER_NAME) --timeout=5m --ignore-not-found=true || echo "No cluster found"
clean: deprovision
	kind get clusters | grep -q kind-capo && kind delete cluster --name kind-capo
	@echo Remove resources left over in OpenStack by running the os_cleanup script
capo-e2e: $(eval OS_CLOUD_NAME="capo-e2e") configure
	./run-e2e-test.sh
