PROJECT := metal3
APP     := tools
NAME    := ${PROJECT}-${APP}

image_registry        := registry.nordix.org
gotest_unit_img_ver   := latest
image_builder_img_ver := latest


.DEFAULT_HELP := help
.PHONY: help
help:
	@echo "--------------------------------------------------------------------"
	@echo "metal3 Dev Tools"
	@echo "--------------------------------------------------------------------"
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-30s\033[0m %s\n", $$1, $$2}'

.PHONY: build-go-unittest
build-go-unittest: ## Build Docker Image for go unit test
	docker build \
		-t gotest-unit \
		-f resources/docker/gotest/Dockerfile resources/docker/gotest/
	docker tag gotest-unit:latest ${image_registry}/metal3/${NAME}-gotest-unit:${gotest_unit_img_ver}

.PHONY: build-container-image
build-container-image:
	$(CURDIR)/scripts/build-container-image.sh

.PHONY: build_fullstack
build_fullstack:
	$(CURDIR)/ci/scripts/image_scripts/start_centos_fullstack_build.sh

.PHONY: clean_fullstack_builder_vm
clean_fullstack_builder_vm:
	$(CURDIR)/ci/scripts/openstack/delete_openstack_vm.sh

.PHONY: integration_test
integration_test: ## Run integration test
	$(CURDIR)/ci/scripts/tests/integration_test.sh

.PHONY: integration_test_cleanup
integration_test_cleanup: ## Clean integration test setup
	$(CURDIR)/ci/scripts/tests/integration_delete.sh

.PHONY: lint-shell
lint-shell: 
	./scripts/shellcheck.sh

.PHONY: push-go-unittest
push-go-unittest: ## Push Docker Image for go unit test to nordix registry
	docker push ${image_registry}/metal3/${NAME}-gotest-unit:${gotest_unit_img_ver}

.PHONY: run-dev-env
run-dev-env: ## Create or start the metal3 dev env vm
	$(CURDIR)/scripts/run_metal3_vm.sh

.PHONY: setup-local-repos
setup-local-repos: ## Setup nordix repos
	$(CURDIR)/scripts/init-repo.sh

.PHONY: test
test: ## Run unit test for the code in repository
	docker run --rm \
                -v "${CURRENT_DIR}/${REPO_NAME}:/go/src/${REPO_PATH}" \
		-w "/go/src/${REPO_PATH}" -e MAKE_CMD=${MAKE_CMD} -e REPO_NAME=${REPO_NAME} \
		${image_registry}/metal3/${NAME}-gotest-unit:${gotest_unit_img_ver}

.PHONY: update-remote-repos
update-remote-repos: ## Update nordix repos
	$(CURDIR)/scripts/update-nordix-repos-master.sh

.PHONY: update-nordix-artifacts
update-nordix-artifacts: ## Update Nordix Artifactory
	$(CURDIR)/scripts/update-nordix-artifacts.sh

