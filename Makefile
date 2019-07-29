PROJECT := airship
APP     := tools
NAME    := ${PROJECT}-${APP}

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
	@(CURDIR)/scripts/update-nordix-repos-master.sh

.PHONY: workspace
workspace: ## Create and execute dev workspace for nordix repos
	@(CURDIR)/container/run-workspace.sh

.PHONY: lint-md
lint-md: ## Lint markdown
	docker run --rm -v "${CURDIR}:/data" --name mkdlint ${NAME}-md-lint mdl -s configs/linter/.mdstylerc.rb .

.PHONY: build-lint-md
build-lint-md: ## Build Docker Image for markdown lint
	docker build -t ${NAME}-md-lint -f resources/docker/linter/Dockerfile .
