# Observability Platform

Plataforma de observabilidade (no formato de um MVP) que seja capaz de implementar instrumentação automática e gerenciamento de telemetria para sistemas em ambientes Kubernetes, reduzindo a complexidade e maximizando a eficiência operacional dos times. 

```mermaid
graph TD
    %% Subgráfico para Infra/Host/Pod/container
    subgraph Infra["Infra/Host/Pod/container"]
        %% Subgráfico para Cluster
        subgraph cluster["Cluster"]
            %% Subgráfico para Application
            subgraph application["Application"]
                Logging
                Tracing
                Metric
            end
        end
    end

    %% Conexões entre elementos
    Logging ---> |App logs| log["strucrec log"]
    Tracing ---> |Traces| trace["lib or agent"]
    Metric ---> |App metrics| metrics["lib or agent"]

    %% Subgráfico para OpenTelemetry (com Processamento e Exportação)
    subgraph opentelemetry["OpenTelemetry"]
        Logs
        Traces
        Metrics
        processor
        exporter
    end

    subgraph backend["Stack Grafana"]
        b-Logs["Logs"]
        b-Traces["Logs"]
        b-Metrics["Metrics"]
    end

    %% Aplicação e opentelemtry
    log ---> Logs ---> processor
    trace ---> Traces ---> processor
    metrics ---> Metrics ---> processor

    %% Conexões entre elementos
    cluster ---> |Infra Metrics| Metrics
    cluster ---> |System Logs| Logs
    cluster ---> |Infra Attributes| opentelemetry

    %% Conexões para Processamento e Exportação dentro de OpenTelemetry
    
    processor ---> exporter
    exporter ---> backend
```