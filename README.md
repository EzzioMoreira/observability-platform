# Observability Platform

Plataforma de observabilidade (no formato de um MVP) que seja capaz de implementar instrumentação automática e gerenciamento de telemetria para sistemas em ambientes Kubernetes, reduzindo a complexidade e maximizando a eficiência operacional dos times. 

```mermaid
---
title: Observability Platform
---

graph TD
    %% Subgráfico para Infra/Host/Pod/Container
    subgraph Infra["Infra/Host/Pod/container"]
    style Infra stroke:#3680db,stroke-width:4px;
        %% Subgráfico para Cluster
        subgraph cluster["Cluster"]
        style cluster stroke:#38345b,stroke-width:4px;
            %% Subgráfico para Application
            subgraph application["Application"]
            style application stroke:#27ae60,stroke-width:4px;
                Logging
                Tracing
                Metric
            end
        end
    end

    %% Conexões entre elementos
    Logging ---> |fas:fa-stream App logs| log(["strucrec log"])
    Tracing ---> |fas:fa-sort-amount-up Traces| trace(["lib or agent"])
    Metric ---> |fas:fa-sliders-h App metrics| metrics(["lib or agent"])

    %% Subgráfico para OpenTelemetry (com Processamento e Exportação)
    subgraph opentelemetry["OpenTelemetry Collector"]
    style opentelemetry stroke:#f39c12,stroke-width:4px;
        Logs
        Traces
        Metrics
        Processor
        Exporter
    end

    subgraph backend["Stack Grafana"]
    style backend stroke:#e74c3c,stroke-width:4px;
        b-Logs[(Logs)]
        b-Traces[(Logs)]
        b-Metrics[(Metrics)]
    end

    %% Aplicação e opentelemtry
    log ---> Logs ---> Processor
    trace ---> Traces ---> Processor
    metrics ---> Metrics ---> Processor

    %% Conexões entre elementos
    cluster ---> |fas:fa-sliders-h Infra Metrics| Metrics
    cluster ---> |fas:fa-stream System Logs| Logs
    cluster ---> |fas:fa-fingerprint Infra Attributes| opentelemetry

    %% Conexões para Processamento e Exportação dentro de OpenTelemetry
    
    Processor ---> Exporter
    Exporter ---> |Correlated Telemetry| backend
```