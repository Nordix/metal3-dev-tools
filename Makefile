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
