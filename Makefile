PROJECT_NAMESPACE=observability
CLUSTER_NAME=observability-platform
CLUSTER_EXISTS = $(shell kind get clusters -q | grep $(CLUSTER_NAME))
DNS_LOCAL1 := $(shell docker container inspect $(CLUSTER_NAME)-worker --format '{{ .NetworkSettings.Networks.kind.IPAddress }}')
DNS_LOCAL2 := $(shell docker container inspect $(CLUSTER_NAME)-control-plane --format '{{ .NetworkSettings.Networks.kind.IPAddress }}')
export DOCKER_IPAM_SUBNET = $(shell docker network inspect -f '{{(index .IPAM.Config 0).Subnet}}' kind)
export KIND_CONFIG_FILE_NAME=kind.config.yaml

# HELP
# This will output the help for each task
# thanks to https://marmelab.com/blog/2016/02/29/auto-documented-makefile.html
.PHONY: help

help: ## This help
	@awk 'BEGIN {FS = ":.*?## "} /^[a-zA-Z_-]+:.*?## / {printf "\033[36m%-30s\033[0m %s\n", $$1, $$2}' $(MAKEFILE_LIST)

.DEFAULT_GOAL := help

## Create file definition for metallb
define get_metalb_config_file
# Define config file
cat << EOF ${METALLB_CONFIG_FILE_NAME}
apiVersion: v1
kind: List
items:
- apiVersion: metallb.io/v1beta1
  kind: IPAddressPool
  metadata:
    name: metallb-pool
    namespace: metallb-system
  spec:
    addresses:
    - "${DOCKER_IPAM_SUBNET}"
- apiVersion: metallb.io/v1beta1
  kind: L2Advertisement
  metadata:
    name: empty
    namespace: metallb-system
EOF
endef
export METALLB_CONFIG_FILE_CREATOR = $(value get_metalb_config_file)

install-kind: ## Instala kind
	@echo "Installing kind"
	curl -Lo ./kind https://kind.sigs.k8s.io/dl/v0.20.0/kind-linux-amd64
	chmod +x ./kind
	sudo mv ./kind /usr/local/bin/kind
	@echo "Kind installed"

create-cluster: ## Cria cluster Kind com balanceador, ingress-nginx, cert-manager e metrics-server
    ifneq ($(CLUSTER_EXISTS), $(CLUSTER_NAME))
		kind create cluster --name $(CLUSTER_NAME) --config=config/kind-config.yaml --wait 10s
    else
		kubectl cluster-info --context kind-$(CLUSTER_NAME)
    endif
    
	@echo "#### Installing metrics-server ####"
	helm repo add metrics-server https://kubernetes-sigs.github.io/metrics-server/
	helm upgrade --install -n kube-system metrics-server metrics-server/metrics-server
	@echo
	@echo "#### Installing CertManager ####"
	kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.13.1/cert-manager.yaml
	@echo
	@echo "#### Installing ingress-nginx ####"
	kubectl apply --filename https://raw.githubusercontent.com/kubernetes/ingress-nginx/master/deploy/static/provider/kind/deploy.yaml
	kubectl wait --namespace ingress-nginx --for=condition=ready pod  --selector=app.kubernetes.io/component=controller --timeout=90s
	@echo
	@echo "#### Configuring DNS $(DNS_LOCAL1) and $(DNS_LOCAL2) for observability.platform.local ####"
	@if grep -q 'observability.platform.local' /etc/hosts; then \
       	sudo sed -i '/observability.platform.local/d' /etc/hosts; \
    fi
	@echo "$(DNS_LOCAL1) observability.platform.local" | sudo tee -a /etc/hosts
	@echo "$(DNS_LOCAL2) observability.platform.local" | sudo tee -a /etc/hosts
	@echo
	@echo "#### Make sure to change addresses range into to your Docker IPAM Subnet ${DOCKER_IPAM_SUBNET} ####"
	kubectl apply -f  https://raw.githubusercontent.com/metallb/metallb/v0.13.7/config/manifests/metallb-native.yaml
	kubectl wait -n metallb-system --for=condition=ready pod --selector=component=controller --timeout=120s

delete-cluster: ## Exclui cluster Kind
	kind delete cluster --name ${CLUSTER_NAME}
	docker system prune

display-cluster: ## Exibe informações do cluster
	kubectl cluster-info --context kind-${CLUSTER_NAME}

deploy-platform: ## Implata plataforma de observabilidade
	@echo "Apply the addresses $(DOCKER_IPAM_SUBNET) range has been changed"
	@ eval "$$METALLB_CONFIG_FILE_CREATOR"
	@ eval "$$METALLB_CONFIG_FILE_CREATOR" | kubectl apply -f -
	@echo
	@echo "Deploying Grafana"
	helm repo add grafana https://grafana.github.io/helm-charts
	helm upgrade --install --wait --create-namespace --namespace $(PROJECT_NAMESPACE) -f charts/grafana/values.yaml grafana-web grafana/grafana
	@echo
	@echo "#### Installing OpenTelemetry Operator ####"
	kubectl apply -f https://github.com/open-telemetry/opentelemetry-operator/releases/latest/download/opentelemetry-operator.yaml
	kubectl wait -n opentelemetry-operator-system --for=condition=ready pod --selector=app.kubernetes.io/name=opentelemetry-operator --timeout=90s
	@echo
	@echo "#### Installing OpenTelemetry Collector ####"
	kubectl -n $(PROJECT_NAMESPACE) apply -f charts/opentelemetry/collector.yaml
	kubectl wait -n $(PROJECT_NAMESPACE) --for=condition=ready pod --selector=app.kubernetes.io/component=opentelemetry-collector --timeout=90s
	@echo
	@echo "#### Installing OpenTelemetry Instrumentation ####"
	kubectl apply -f charts/opentelemetry/instrumentation.yaml
	kubectl get instrumentation
	@echo
	@echo "#### Installing OpenTelemetry Sidecar Collector ####"
	kubectl apply -f charts/opentelemetry/sidecar-collector.yaml
	kubectl get OpenTelemetryCollector sidecar-jaeger
	@echo

deploy-applications: ## Implata aplicações de exemplo
	@echo "#### Installing App Python ####"
	kubectl apply -f app/python/deployment.yaml
	@echo
	@echo "#### Installing App NodeJS ####"
	kubectl apply -f app/nodes/deployment.yaml
	@echo
	@echo "#### Installing App Java ####"
	kubectl apply -f app/java/deployment.yaml
	@echo

delete-applications: ## Exclui aplicações de exemplo
	@echo "#### Deleting App Python ####"
	kubectl delete -f app/python/deployment.yaml
	@echo
	@echo "#### Deleting App NodeJS ####"
	kubectl delete -f app/nodes/deployment.yaml
	@echo
	@echo "#### Deleting App Java ####"
	kubectl delete -f app/java/deployment.yaml
	@echo
