export PROJECT_NAMESPACE=observability
export CLUSTER_NAME=observability-platform

# HELP
# This will output the help for each task
# thanks to https://marmelab.com/blog/2016/02/29/auto-documented-makefile.html
.PHONY: help

help: ## This help
	@awk 'BEGIN {FS = ":.*?## "} /^[a-zA-Z_-]+:.*?## / {printf "\033[36m%-30s\033[0m %s\n", $$1, $$2}' $(MAKEFILE_LIST)

.DEFAULT_GOAL := help

run-local:
	make -f Makefile.kind setup-kind
	make -f Makefile build credentials install-local

delete-local:
	make -f Makefile uninstall-local
	make -f Makefile.kind delete-kind-cluster

install-kind: ## Install kind
	@echo "Installing kind"
	curl -Lo ./kind https://kind.sigs.k8s.io/dl/v0.20.0/kind-linux-amd64
	chmod +x ./kind
	sudo mv ./kind /usr/local/bin/kind
	@echo "Kind installed"
	@echo "Installing kubectl"
	curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
	sudo mv kubectl /usr/local/bin/kubectl
	sudo chmod +x /usr/local/bin/kubectl
	@echo "Kubectl installed"

create-cluster: ## Create kind cluster
	@echo "Creating kind cluster"
	kind create cluster --name ${CLUSTER_NAME} --config=./config/kind-config.yaml

delete-cluster: ## Delete kind cluster
	kind delete cluster --name ${CLUSTER_NAME}
	docker system prune

display-cluster: ## Display kind cluster
	kubectl cluster-info --context kind-${CLUSTER_NAME}
