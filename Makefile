PROJECT := metal3
APP     := tools
NAME    := ${PROJECT}-${APP}

lint_folder ?= $(CURDIR)

image_registry        := registry.nordix.org
workspace_img_ver     := v1.0
lint_md_img_ver       := v1.0
lint_go_img_ver       := v1.0
gotest_unit_img_ver   := v1.0
image_builder_img_ver := v1.0


.DEFAULT_HELP := help
.PHONY: help
help:
	@echo "--------------------------------------------------------------------"
	@echo "metal3 Dev Tools"
	@echo "--------------------------------------------------------------------"
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-30s\033[0m %s\n", $$1, $$2}'

.PHONY: setup-local-repos
setup-local-repos: ## Setup nordix repos
	$(CURDIR)/scripts/init-repo.sh

.PHONY: update-remote-repos
update-remote-repos: ## Update nordix repos
	$(CURDIR)/scripts/update-nordix-repos-master.sh

.PHONY: update-nordix-artifacts
update-nordix-artifacts: ## Update Nordix Artifactory
	$(CURDIR)/scripts/update-nordix-artifacts.sh

.PHONY: build-workspace
build-workspace: ## Build Docker Image for workspace
	docker build \
		-t ${NAME}-workspace \
		-f resources/docker/workspace/Dockerfile resources/docker/workspace/
	docker tag ${NAME}-workspace:latest ${image_registry}/airship/${NAME}-workspace:${workspace_img_ver}

.PHONY: push-workspace
push-workspace: ## Push Docker Image for Workspace to nordix registry
	docker push ${image_registry}/airship/${NAME}-workspace:${workspace_img_ver}

.PHONY: workspace
workspace: ## Create and execute dev workspace for nordix repos
	docker run \
		--rm -it \
		--name workspace \
		--network host \
		-v "${CURDIR}:/data" \
		-v /var/run/docker.sock:/var/run/docker.sock \
		-v "${HOME}"/.kube/:/root/.kube \
		-v "${HOME}"/.minikube:"${HOME}"/.minikube \
		${image_registry}/airship/${NAME}-workspace:${workspace_img_ver}

.PHONY: lint-md
lint-md: ## Lint markdown (ex: make lint-md or make lint-md lint_folder=abspath)
	docker run --rm \
		-v "${CURDIR}:/data" \
		-v "${lint_folder}:/lintdata" \
		${image_registry}/airship/${NAME}-md-lint:${lint_md_img_ver} \
		mdl -s configs/linter/.mdstylerc.rb "/lintdata"

.PHONY: build-lint-md
build-lint-md: ## Build Docker Image for markdown lint
	docker build \
		-t ${NAME}-md-lint \
		-f resources/docker/linter/Dockerfile resources/docker/linter/

.PHONY: push-lint-md
push-lint-md: ## Push Docker Image for Lint markdown to nordix registry
	docker tag ${NAME}-md-lint:latest ${image_registry}/airship/${NAME}-md-lint:${lint_md_img_ver}
	docker push ${image_registry}/airship/${NAME}-md-lint:${lint_md_img_ver}

.PHONY: build-image-builder
build-image-builder: ## Build Docker Image for qcow2 image building
	docker build \
		-t image-builder \
		-f resources/docker/builder/Dockerfile resources/docker/builder/

.PHONY: push-image-builder
push-image-builder: ## Push Docker Image for qcow2 image building to nordix registry
	docker tag image-builder:latest ${image_registry}/airship/image-builder:${image_builder_img_ver}
	docker push ${image_registry}/airship/image-builder:${image_builder_img_ver}

.PHONY: build-go-unittest
build-go-unittest: ## Build Docker Image for go unit test
	docker build \
		-t gotest-unit \
		-f resources/docker/gotest/Dockerfile resources/docker/gotest/
	docker tag gotest-unit:latest ${image_registry}/airship/${NAME}-gotest-unit:${gotest_unit_img_ver}

.PHONY: push-go-unittest
push-go-unittest: ## Push Docker Image for go unit test to nordix registry
	docker push ${image_registry}/airship/${NAME}-gotest-unit:${gotest_unit_img_ver}

SHELLCHECK_VERSION := "v0.7.0"
SHELLCHECK_IMAGE := "koalaman/shellcheck-alpine:${SHELLCHECK_VERSION}"
.PHONY: lint-shell
lint-shell: ## Lint shell scripts (ex: make lint-shell or make lint-shell lint_folder=abspath)
	docker run --rm \
		-v "${CURDIR}:/mnt" \
		-v "${lint_folder}:/data" \
		${SHELLCHECK_IMAGE} \
		sh /mnt/scripts/shell-linter.sh

.PHONY: build-lint-go
build-lint-go: ## Build Docker Image for go lint
	docker build \
		-t ${NAME}-go-lint \
		-f resources/docker/linter/golang/Dockerfile resources/docker/linter/golang

.PHONY: push-lint-go
push-lint-go: ## Push Docker Image for Lint go to nordix registry
	docker tag ${NAME}-go-lint:latest ${image_registry}/airship/${NAME}-go-lint:${lint_go_img_ver}
	docker push ${image_registry}/airship/${NAME}-go-lint:${lint_go_img_ver}

.PHONY: lint-go
lint-go: ## Lint go and execute gosec (ex: make lint-go or make lint-go lint_folder=abspath)
	docker run --rm \
		-v "${CURDIR}:/mnt" \
		-v "${lint_folder}:/data" \
		${image_registry}/airship/${NAME}-go-lint:${lint_go_img_ver} \
		sh /mnt/scripts/go-linter.sh

.PHONY: run-dev-env
run-dev-env: ## Create or start the metal3 dev env vm
	$(CURDIR)/scripts/run_metal3_vm.sh

.PHONY: test
test: ## Run unit test for the code in repository
	docker run --rm \
                -v "${CURRENT_DIR}/${REPO_NAME}:/go/src/${REPO_PATH}" \
		-w "/go/src/${REPO_PATH}" -e MAKE_CMD=${MAKE_CMD} -e REPO_NAME=${REPO_NAME} \
		${image_registry}/airship/${NAME}-gotest-unit:${gotest_unit_img_ver}

.PHONY: integration_test
integration_test: ## Run integration test
	$(CURDIR)/ci/scripts/tests/integration_test.sh

.PHONY: build_ipa
build_ipa:
	$(CURDIR)/ci/scripts/image_scripts/start_centos_ipa_ironic_build.sh

.PHONY: clean_ipa_builder_vm
clean_ipa_builder_vm:
	$(CURDIR)/ci/scripts/openstack/delete_openstack_vm.sh

.PHONY: integration_test_cleanup
integration_test_cleanup: ## Clean integration test setup
	$(CURDIR)/ci/scripts/tests/integration_delete.sh
