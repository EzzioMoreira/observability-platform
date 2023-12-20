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

help: ## Ajuda
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

create-cluster: configure-dns ## Cria cluster Kind com balanceador, ingress-nginx, cert-manager e metrics-server
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
	kubectl wait --namespace ingress-nginx --for=condition=ready pod  --selector=app.kubernetes.io/component=controller --timeout=120s
	@echo

	@echo "#### Make sure to change addresses range into to your Docker IPAM Subnet ${DOCKER_IPAM_SUBNET} ####"
	kubectl apply -f  https://raw.githubusercontent.com/metallb/metallb/v0.13.7/config/manifests/metallb-native.yaml
	kubectl wait -n metallb-system --for=condition=ready pod --selector=component=controller --timeout=120s
	@echo

	@echo "#### Configuração DNS ####"	
	@make configure-dns

configure-dns: ## Configuração DNS
	@echo "#### Configuring DNS $(DNS_LOCAL1) and $(DNS_LOCAL2) for observability.platform.local ####"
	@if grep -q 'observability.platform.local' /etc/hosts; then \
       	sudo sed -i '/observability.platform.local/d' /etc/hosts; \
    fi
	@echo "$(DNS_LOCAL1) observability.platform.local" | sudo tee -a /etc/hosts
	@echo "$(DNS_LOCAL2) observability.platform.local" | sudo tee -a /etc/hosts

delete-cluster: ## Exclui cluster Kind
	kind delete cluster --name ${CLUSTER_NAME}
	docker system prune

display-cluster: ## Exibe informações do cluster
	kubectl cluster-info --context kind-${CLUSTER_NAME}

deploy-platform-local: ## Implanta beackend da plataforma de observabilidade local
	@echo "#### Apply the addresses $(DOCKER_IPAM_SUBNET) range has been changed ####"
	@ eval "$$METALLB_CONFIG_FILE_CREATOR"
	@ eval "$$METALLB_CONFIG_FILE_CREATOR" | kubectl apply -f -
	@echo

	@echo "#### Installing Minio S3 ####"
	kubectl apply -f minio/minio.yaml
	@echo

	@echo "#### Installing Grafana Operator ####"
	helm upgrade --install --wait --create-namespace --namespace observability grafana-operator oci://ghcr.io/grafana-operator/helm-charts/grafana-operator --version v5.4.2
	kubectl wait -n observability --for=condition=ready pod --selector=app.kubernetes.io/instance=grafana-operator --timeout=120s
	@echo

	@echo "#### Deploying Grafana Web ####"
	kubectl -n observability apply -f grafana-web/grafana.yaml
	kubectl wait -n observability --for=condition=ready pod --selector=app=grafana --timeout=120s
	kubectl -n observability apply -f grafana-web/datasource.yaml
	kubectl -n observability apply -f grafana-web/dashboard/dashboard.yaml
	kubectl -n observability apply -f grafana-web/dashboard/opentelemetry-collector-dashboard.yaml
	@echo

	@echo "#### Installing Grafana Tempo Operator ####"
	kubectl apply -f https://github.com/grafana/tempo-operator/releases/latest/download/tempo-operator.yaml
	kubectl wait -n tempo-operator-system --for=condition=ready pod --selector=app.kubernetes.io/name=tempo-operator --timeout=120s
	@echo

	@echo "#### Installing Grafana Tempo ####"
	kubectl -n observability apply -f grafana-tempo/tempo.yaml
	@echo

	@echo "#### Installing Grafana Mimir ####"
	helm upgrade --install --wait --create-namespace --namespace observability -f grafana-mimir/values.yaml grafana-mimir grafana/mimir-distributed
	kubectl wait -n observability --for=condition=ready pod --selector=app.kubernetes.io/name=mimir --timeout=160s
	@echo

	@echo "#### Installing OpenTelemetry Operator ####"
	kubectl apply -f https://github.com/open-telemetry/opentelemetry-operator/releases/latest/download/opentelemetry-operator.yaml
	kubectl wait -n opentelemetry-operator-system --for=condition=ready pod --selector=app.kubernetes.io/name=opentelemetry-operator --timeout=120s
	@echo
	
	@echo "#### Installing OpenTelemetry Instrumentation ####"
	kubectl apply -f opentelemetry/instrumentation.yaml
	kubectl get instrumentation
	@echo
	
	@echo "#### Installing OpenTelemetry Sidecar Collector ####"
	kubectl apply -f opentelemetry/sidecar-collector.yaml
	kubectl get OpenTelemetryCollector sidecar-jaeger
	@echo

	@echo "#### Installing OpenTelemetry Agent Collector ####"
	kubectl apply -f opentelemetry/platform-agent-collector-rbac.yaml
	kubectl apply -f opentelemetry/platform-agent-collector.yaml
	@echo

	@echo "#### Aceess Grafana ####"
	@echo "Grafana Web: http://observability.platform.local" \
		"\nUsuário: admin" \
		"\nSenha: admin"

deploy-platform-grafana-cloud: ## Implanta plataforma de observabilidade envia dados na Grafana Cloud
	#@echo "#### Installing CertManager ####"
	#kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.13.1/cert-manager.yaml
	#@echo
	
	@echo "#### Installing OpenTelemetry Operator ####"
	kubectl apply -f https://github.com/open-telemetry/opentelemetry-operator/releases/latest/download/opentelemetry-operator.yaml
	kubectl wait -n opentelemetry-operator-system --for=condition=ready pod --selector=app.kubernetes.io/name=opentelemetry-operator --timeout=120s
	@echo
	
	@echo "#### Installing OpenTelemetry Instrumentation ####"
	kubectl apply -f opentelemetry/instrumentation.yaml
	kubectl get instrumentation
	@echo
	
	@echo "#### Installing OpenTelemetry Sidecar Collector ####"
	kubectl apply -f opentelemetry/sidecar-collector.yaml
	kubectl get OpenTelemetryCollector sidecar-jaeger
	@echo

	@echo "#### Installing OpenTelemetry Agent Collector ####"
	kubectl apply -f opentelemetry/secret-grafana-cloud.yaml
	kubectl apply -f opentelemetry/platform-agent-collector-rbac.yaml
	kubectl apply -f opentelemetry/platform-agent-collector-grafana-cloud.yaml
	@echo


deploy-applications: ## Implanta aplicações de exemplo
	@echo "#### Installing App Trace Generator ####"
	kubectl apply -f app/app-trace-generate/app-trace-generate.yaml
	@echo

	@echo "#### Installing Metric Generator ####"
	kubectl apply -f app/app-metric-generate/app-metric-generate.yaml
	@echo

	@echo "#### Installing App Pet Clinic ####"
	kubectl apply -f app/app-petclinic/deployment.yaml

	@echo "#### Access App Metric Generator  and Trace Generator ####"
	kubectl apply -f app/app-metric-generate/app-metric-generate.yaml
	kubectl apply -f app/app-trace-generate/app-trace-generate.yaml

delete-applications: ## Exclui aplicações de exemplo
	@echo "#### Deleting App Trace Generator ####"
	kubectl delete -f app/app-trace-generate/app-trace-generate.yaml
	@echo

	@echo "#### Deleting App Metric Generator ####"
	kubectl delete -f app/app-metric-generate/app-metric-generate.yaml
	@echo

	@echo "#### Deleting App Pet Clinic ####"
	kubectl delete -f app/app-petclinic/deployment.yaml
	@echo

	@echo "#### Deleting App Metric Generator  and Trace Generator ####"
	kubectl delete -f app/app-metric-generate/app-metric-generate.yaml
	kubectl delete -f app/app-trace-generate/app-trace-generate.yaml

