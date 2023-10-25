PROJECT_NAMESPACE=observability
CLUSTER_NAME=observability-platform
CLUSTER_EXISTS = $(shell kind get clusters -q | grep $(CLUSTER_NAME))

# HELP
# This will output the help for each task
# thanks to https://marmelab.com/blog/2016/02/29/auto-documented-makefile.html
.PHONY: help

help: ## This help
	@awk 'BEGIN {FS = ":.*?## "} /^[a-zA-Z_-]+:.*?## / {printf "\033[36m%-30s\033[0m %s\n", $$1, $$2}' $(MAKEFILE_LIST)

.DEFAULT_GOAL := help

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
	kubectl create namespace $(PROJECT_NAMESPACE)

create-cluster: ## Create kind cluster
    ifneq ($(CLUSTER_EXISTS), $(CLUSTER_NAME))
		kind create cluster --name $(CLUSTER_NAME) --config=config/kind-config.yaml --wait 10s
    else
		kubectl cluster-info --context kind-$(CLUSTER_NAME)
    endif
    # Install metrics server
	helm repo add metrics-server https://kubernetes-sigs.github.io/metrics-server/
	helm repo update
	helm upgrade --install --set args={--kubelet-insecure-tls} metrics-server metrics-server/metrics-server --namespace kube-system
	kubectl rollout -n kube-system status deployment metrics-server

delete-cluster: ## Delete kind cluster
	kind delete cluster --name ${CLUSTER_NAME}
	docker system prune

display-cluster: ## Display kind cluster
	kubectl cluster-info --context kind-${CLUSTER_NAME}

deploy-platform: ## Deploy observability platform
	@echo "Deploying Grafana"
	helm repo add grafana https://grafana.github.io/helm-charts
	helm upgrade --install --wait --create-namespace --namespace $(PROJECT_NAMESPACE) -f charts/grafana/values.yaml grafana-web grafana/grafana