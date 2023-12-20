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

### Componente Intrumentação Automática

O Resource Instrumentation do Operator OponTelemetry implementa as configurações necessárias no Pod, através do Init Container injentando agentes ou biblioteca do OpenTelemetry, permitindo a geração, colete e envio dos dados de telemetria.

```mermaid
---
title: Componentes OpenTelemetry Instrumentation
---

graph LR

subgraph openTelemetry["OpenTelemetry"]
  style openTelemetry stroke:#f39000,stroke-width:4px;
  subgraph components["Components"]
    style components stroke:#f39000,stroke-width:2px;
    autoinstrumentation["Autoinstrumentation"]
  end
end

subgraph application["Application Pod"]
  style application stroke:#38345b,stroke-width:4px;
  subgraph container["Containers"]
    init["Initi container Otel"]
    app["Application"]
  end
  
end

openTelemetry --->|Instrumentation Configuration| application
init --->|"Inject agent or lib"| app
```

### Componente Sidecar OpenTelemetry Collector

O Resource Sidecar do Operator OponTelemetry cria um segundo container no Pod da aplicação que será responsável pela coleta e transporte dos dados de telemetria dos serviços que não suportam o envio dos dados diretamente para o collector central.

```mermaid
---
title: Componentes OpenTelemetry Sidecar
---

graph LR

subgraph openTelemetry["OpenTelemetry"]
  style openTelemetry stroke:#f39000,stroke-width:4px;
  subgraph components["Components"]
    style components stroke:#f39000,stroke-width:2px;
    sidecar["sidecar"]
  end
end

subgraph application["Application Pod"]
  style application stroke:#38345b,stroke-width:4px;
  subgraph container["Containers"]
    app-sidecar["Sidecar Collector"]
    app["Application"]
  end
  
end

openTelemetry --->|Instrumentation Configuration| application
app-sidecar --->|"Telemetry collect"| app
```

### Componente OpenTelemetry Collector

O Resource Collector do Operator OponTelemetry é responsável por centralizar o recebimento e processamento de diversas fontes do cluster Kubernetes e encaminhar os dados para um ou mais provedores de observabilidade.

```mermaid
---
title: Componentes OpenTelemetry Collector
---

graph LR

subgraph openTelemetry["OpenTelemetry"]
  style openTelemetry stroke:#f39000,stroke-width:4px;
  subgraph components["Components"]
    style components stroke:#f39000,stroke-width:2px;
    collector["collector"]
  end
end

subgraph application["Application Pod with sidecar"]
  style application stroke:#4d7eb7,stroke-width:4px;
  subgraph container["Containers"]
    app-sidecar["Sidecar Collector"]
    app["Application"]
  end
end

subgraph application2["Application Pod"]
  style application2 stroke:#4d7eb7,stroke-width:4px;
  subgraph container2["Containers"]
    app2["Application"]
  end
end

subgraph cluster["Kubernetes"]
style cluster stroke:#4d7eb7,stroke-width:4px;
node["Nodes"]
control["Control Plane"]
runtime["Container Runtime"]
controllers["Contollers"]
schedule["Scheduler"]
end

subgraph backend["Observability Backend"]
style backend stroke:#4d7eb7,stroke-width:4px;
Trace
Metric
Log
end


application --->|Sending Telemetry data| openTelemetry
application2 --->|Sending Telemetry data| openTelemetry
app-sidecar --->|"Telemetry collect"| app
cluster --->|Sending Telemetry data| openTelemetry
openTelemetry ---> Trace
openTelemetry ---> Metric
openTelemetry ---> Log
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
help                 "Ajuda"
install-kind         "Instala kind"
create-cluster       "Cria cluster K8s com balanceador, ingress-nginx, cert-manager e metrics-server"
configure-dns        "Configuração DNS"
delete-cluster       "Exclui cluster Kubernetes"
display-cluster      "Exibe informações do cluster"
deploy-platform      "Implanta plataforma de observabilidade"
deploy-applications  "Implanta aplicações de exemplo"
delete-applications  "Exclui aplicações de exemplo"
```

### Criar Cluster Kubernetes

Execute o comando a seguir:

```shell
make create-cluster
```

> Em caso de erro, execute o comando novamente.

### Criar Plataforma de Observabilidade

Execute o comando a seguir:

```shell
make deploy-platform
```

> Em caso de erro, execute o comando novamente.

### Criar Aplicações de Exemplo

Execute o comando a seguir:

```shell
make deploy-applications 
```

> Em caso de erro, execute o comando novamente.


## Acessando Plataforma de Observabilidade Local

- Link Grafana Web: http://observability.platform.local
- Usuário: admin
- Senha: admin

## Plataforma Envia dados para Grafana Cloud

Antes de implantar o OpenTelemetry Collector com Exporter Grafana Cloud, é necessário criar as secrets com os tokens do provider.

```yaml
apiVersion: v1
data:
  token: <SET TOKEN IN BASE64>
kind: Secret
metadata:
  name: grafana-secret
  namespace: observability
```

> Para encriptar base64: `echo "SET O TOKEN HERE" | base64`

Copie e cole o valor no arquivo `./opentelemetry/secret-grafana-cloud.yaml`

Execute o comando a seguir: 

```shell
make deploy-platform-grafana-cloud
```

## Erros Conhecidos

Erro: `failed to create fsnotify watcher: too many open files`, ocorre quando o OpenTelemetry Collector não consegue criar um observador de sistema de arquivos (fsnotify) devido a um limite de arquivos abertos excedido. Para resolver esse problema, você precisa ajustar os recursos do sistema operacional para permitir um número maior de arquivos abertos.

Execute o comando a seguir

```shell
sudo sysctl fs.inotify.max_user_watches=524288
sudo sysctl fs.inotify.max_user_instances=512
```

[Referência: Erros de pod devido a “muitos arquivos abertos”](https://kind.sigs.k8s.io/docs/user/known-issues/#pod-errors-due-to-too-many-open-files)

## Resultados

3.1 Resultados

Observar sistemas é um dos elementos mais importantes para solucionar problemas de desempenho, segurança, escalabilidade e disponibilidade. Nesse contexto, a plataforma de observabilidade desempenha um papel fundamental ao proporcionar instrumentação automática para sistemas executados no Kubernetes. Essa abordagem automatizada simplifica a coleta, processamento e envio de dados de telemetria, permitindo uma análise eficaz do comportamento do sistema em tempo real.
A proposta apresentada neste documento trará benefícios para os times de engenharia e operações. Uma vez que, facilitará a entrega de software com maior confiabilidade, reduzindo a carga operacional, assegura um mínimo de observabilidades para os sistemas, contribuindo para a resolução de problemas com maior rapidez e eficiência, além de difundir a cultura de observabilidade entre os times.
A instrumentação automática elimina a necessidade de adicionar mais linhas de código no desenvolvimento do software. É importante considerar a autoinstrumentação como um dos primeiros passos para uma compreensão adequada do comportamento do sistema. Posteriormente, podemos incorporar a instrumentação manual para obter informações de telemetria de alta qualidade.
Os dados coletados pela plataforma de observabilidade são acrescidos de dados abrangentes sobre o contexto de execução do sistema, incluindo metadados das tarefas executadas pelo software. Além disso, os dados de contexto de execução do sistema, incluem os metadados do provedor de nuvem, cluster, infraestrutura, recursos do kubernetes, contêiner entre outros. Os clientes têm a oportunidade de navegar entre diferentes camadas e tipos de dados de telemetria, métricas, trace e log, de modo a identificar a causa raiz do problema.
O núcleo da plataforma de observabilidade foi desenvolvido com as ferramentas do projeto OpenTelemetry. Essas ferramentas possibilitam a coleta, processamento e transporte dos dados de telemetria, agnóstico a ferramenta de monitoramento e analise. Essa flexibilidade proporciona aos usuários uma grande liberdade, eliminando de permanecer preso a uma ferramenta específica.

3.2 Contribuições

O progresso do projeto foi impulsionado pelas demandas específicas dos clientes, resultando em uma plataforma de observabilidade inovadora e flexível, inteiramente alinhadas às demandas do ecossistema de observabilidade. Uma das principais características é a implementação de autoinstrumentação simplificada, reduzindo o custo operacional dos times de engenharia e operações. 
Ao contrário de outras ferramentas, a plataforma de observabilidade se sobressai por sua integração nativa com ambiente Kubernetes, permitindo aos clientes a escolha da ferramenta de monitoramento e análise mais adequada para armazenar os dados de telemetria. Essa capacidade de escolha não apenas aumenta a eficiência operacional, como também facilita a adaptação a cenários de observabilidade mais complexos, consolidando a plataforma como uma solução focada no cliente e alinhada às demandas dinâmicas de sistemas distribuídos.
A introdução da coleta, processamento e envio automático de telemetria aprimora significativamente os padrões de observabilidade para sistemas executados no Kubernetes. Essa abordagem eficiente proporciona aos usuários uma melhor experiência para avaliar o comportamento do sistema em tempo real. A automação do gerenciamento de telemetria não apenas simplifica a implementação, mas também reduz o tempo necessário para identificar e solucionar problemas, contribuindo para uma resposta mais ágil a eventos críticos. 

3.3 Próximos passos

Enquanto progredimos no projeto, percebemos progressos significativos e a adição de recursos cruciais para aprimorar a eficiência da plataforma. Abaixo estão as propostas para as próximas etapas:
Customização da Coleta de Telemetria: 
Oferecer aos clientes a coleta de telemetria personalizada de acordo com as suas necessidades. Isso permitirá que os clientes especifiquem, por meio de labels ou annotations nos manifestos Kubernetes de suas aplicações, quais tipos de dados de telemetria desejam coletar. Por exemplo, os clientes poderão habilitar ou desabilitar a coleta de logs, traces e métricas através de valores booleanos (true ou false). Essa abordagem permitirá uma coleta mais precisa de dados essenciais, o que resultará em uma melhor utilização do monitoramento.
Escolha da Ferramenta de Monitoramento:
Os clientes podem escolher para qual ferramenta de monitoramento os dados de telemetria devem ser enviados. Ao inserir chaves-valor nos manifestos Kubernetes de suas aplicações, os clientes terão a opção de escolher entre diversas ferramentas de monitoramento e analise, como Datadog, Grafana, New Relic, entre outras. Essa flexibilidade assegura que a plataforma se integre perfeitamente ao ecossistema de monitoramento preferido de cada cliente, proporcionando uma experiência verdadeiramente personalizada.
Aprimoramento Contínuo:
Além disso, estamos sempre aperfeiçoando a plataforma de observabilidade. Isso inclui a expansão das integrações com uma variedade ainda maior de ferramentas de monitoramento e análise, garantindo a segurança e conformidade no manuseio dos dados sensíveis de telemetria. Paralelamente, estamos dedicados a fornecer treinamentos abrangentes e documentação de alta qualidade para capacitar nossos clientes a tirar o máximo proveito da plataforma. Essas melhorias mostram que queremos oferecer uma solução completa e evolutiva para atender às necessidades crescentes da observabilidade.
