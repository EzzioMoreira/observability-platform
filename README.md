# Observability Platform

Plataforma de observabilidade (no formato de um MVP) que seja capaz de implementar instrumentação automática e gerenciamento de telemetria para sistemas em ambientes Kubernetes, reduzindo a complexidade e maximizando a eficiência operacional dos times. 

```mermaid
---
title: Observability Platform
---

graph LR
    %% Subgráfico para Infra/Host/Pod/Container
    subgraph Infra["Infra/Host/Pod/container"]
    style Infra stroke:#3680db,stroke-width:4px;
        %% Subgráfico para Cluster
        subgraph cluster["Cluster"]
        style cluster stroke:#38345b,stroke-width:4px;
            %% Subgráfico para Application
            subgraph application["Application"]
            style application stroke:#38345b,stroke-width:4px;
                a-Logging
                a-Tracing
                a-Metric
            end
        end
    end

    %% Conexões cluster
    cluster ---> |fas:fa-sliders-h Infra Metrics| Metrics
    cluster ---> |fas:fa-stream System Logs| Logs
    cluster ---> |fas:fa-fingerprint Infra Attributes| opentelemetry
    Metrics ---> o-Metrics
    Logs ---> o-Logs

    %% Aplicação opetnelemetry
    application --- |Implement autoinstrumentation| autoinstrumentations
    application --- |Agent Collector| sidecar

    %% Subgráfico opentelemetry processamento e exporter
    subgraph opentelemetry["OpenTelemetry"]
    style opentelemetry stroke:#f39000,stroke-width:4px;
        o-Logs
        o-Traces
        o-Metrics
        Processor
        Exporter
        subgraph operator["Operator"]
            autoinstrumentations["Instrument CRD"]
            sidecar["Collector CRD"]
        end 
    end

    %% Conexões opentelemetry processoe e exporter
    a-Logging[Logging] ---> |fas:fa-stream App logs| o-Logs
    a-Tracing[Tracing] ---> |fas:fa-sort-amount-up Traces| o-Traces
    a-Metric[Metric] ---> |fas:fa-sliders-h App metrics| o-Metrics
    o-Logs[Logs] ---> Processor
    o-Traces[Traces] ---> Processor
    o-Metrics[Metrics] ---> Processor

    %% Conexões para Processamento e Exportação dentro de OpenTelemetry
    Processor ---> Exporter
    Exporter ---> |Correlated Telemetry| b-Logs
    Exporter ---> |Correlated Telemetry| b-Metrics
    Exporter ---> |Correlated Telemetry| b-Traces
    
    %% Subgráfico backend stack grafana
    subgraph Grafana["Observability Stack"]
    style backend stroke:#e85c3c,stroke-width:4px;
        subgraph backend["Backend"]
            g-Grafana["Grafana"]
            b-Logs[(Logs Grafana Loki)]
            b-Traces[(Traces Grafana Tempo)]
            b-Metrics[(Metrics Grafana Mirmir)]
        end
    end
    %% Conexões backend stack grafana
    b-Logs --- g-Grafana
    b-Traces --- g-Grafana
    b-Metrics --- g-Grafana
```

## Requisitos

- [Docker](https://docs.docker.com/engine/install/)
- [Kubectl](https://kubernetes.io/pt-br/docs/tasks/tools/#kubectl)
- [Helm](https://helm.sh/docs/intro/install/)

## Ajuda

Para ajuda, digite o comando a seguir no dirátorio raiz do projeto. 

```shell
make help
```
Saída:

```shell
help                 This help
install-kind         Instala kind
create-cluster       Cria cluster Kind com balanceador, ingress-nginx, cert-manager e metrics-server
delete-cluster       Exclui cluster Kind
display-cluster      Exibe informações do cluster
deploy-platform      Implata plataforma de observabilidade
deploy-applications  Implata aplicações de exemplo
```
