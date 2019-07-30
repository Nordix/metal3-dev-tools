PROJECT := airship
APP     := tools
NAME    := ${PROJECT}-${APP}

lint_folder ?= $(CURDIR)

.DEFAULT_HELP := help
.PHONY: help
help:
	@echo "--------------------------------------------------------------------"
	@echo "Airship Dev Tools"
	@echo "--------------------------------------------------------------------"
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-30s\033[0m %s\n", $$1, $$2}'

.PHONY: setup-repos
setup-repos: ## Setup nordix repos
	$(CURDIR)/scripts/init-repo.sh

.PHONY: update-repos
update-repos: ## Update nordix repos
	$(CURDIR)/scripts/update-nordix-repos-master.sh

.PHONY: workspace
workspace: ## Create and execute dev workspace for nordix repos
	$(CURDIR)/container/run-workspace.sh

.PHONY: lint-md
lint-md: ## Lint markdown (ex: make lint-md or make lint-md lint_folder=abspath)
	docker run --rm \
		-v "${CURDIR}:/data" \
		-v "${lint_folder}:/lintdata" \
		${NAME}-md-lint \
		mdl -s configs/linter/.mdstylerc.rb "/lintdata";

.PHONY: build-lint-md
build-lint-md: ## Build Docker Image for markdown lint
	docker build -t ${NAME}-md-lint -f resources/docker/linter/Dockerfile resources/docker/linter

.PHONY: build-image-builder
build-image-builder: ## Build Docker Image for qcow2 image building
	docker build -t image-builder -f resources/docker/builder/Dockerfile resources/docker/builder

.PHONY: push-image-builder
push-image-builder: ## Build Docker Image for qcow2 image building
	docker tag image-builder registry.nordix.org/airship/image-builder
	docker push registry.nordix.org/airship/image-builder
	docker build \
		-t ${NAME}-md-lint \
		-f resources/docker/linter/Dockerfile .

SHELLCHECK_VERSION := "v0.7.0"
SHELLCHECK_IMAGE := "koalaman/shellcheck-alpine:${SHELLCHECK_VERSION}"
.PHONY: lint-shell
lint-shell: ## Lint shell scripts (ex: make lint-shell or make lint-shell lint_folder=abspath)
	docker run --rm \
		-v "${CURDIR}:/mnt" \
		-v "${lint_folder}:/data" \
		${SHELLCHECK_IMAGE} \
		sh /mnt/scripts/shell-linter.sh
