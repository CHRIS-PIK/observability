# Observability Lab

Stack de observabilidade executada com Docker Compose, baseada no ecossistema Grafana, para coleta e visualização de **métricas, logs, traces e profiles**.

O projeto mantém o comportamento atual do laboratório:

- coleta métricas do host Docker;
- coleta logs dos containers pelo Docker socket;
- recebe telemetria OTLP por gRPC e HTTP;
- recebe profiles pelo Grafana Alloy;
- coleta métricas do `datalake-producer` em `host.docker.internal:9101`;
- coleta métricas do `datalake-worker` em `host.docker.internal:9102`;
- envia métricas para o Mimir, logs para o Loki, traces para o Tempo e profiles para o Pyroscope;
- disponibiliza os dados no Grafana com datasources provisionados automaticamente.

## Arquitetura

```text
Docker containers ── logs ───────────────┐
Linux host ──────── metrics ─────────────┤
Producer :9101 ──── metrics ─────────────┤
Worker :9102 ────── metrics ─────────────┤
Applications ────── OTLP 4317/4318 ──────┤
Applications ────── profiles 4041 ───────┤
                                         ▼
                                    Grafana Alloy
                      ┌──────────────────┼──────────────────┐
                      ▼                  ▼                  ▼
                 Mimir             Loki / Tempo        Pyroscope
                 metrics          logs / traces         profiles
                      └──────────────────┼──────────────────┘
                                         ▼
                                      Grafana
```

## Componentes

| Componente | Imagem | Função | Porta no host |
|---|---|---|---:|
| Grafana | `grafana/grafana:12.3.1` | Visualização e exploração | `3000` |
| Grafana Alloy | `grafana/alloy:v1.8.1` | Coleta e roteamento de telemetria | `12345`, `4317`, `4318`, `4041` |
| Loki | `grafana/loki:3.5.5` | Armazenamento de logs | `3100` |
| Mimir | `grafana/mimir:3.1.2` | Armazenamento de métricas | `9009` |
| Tempo | `grafana/tempo:2.9.0` | Armazenamento de traces | `3200` |
| Pyroscope | `grafana/pyroscope:1.14.1` | Armazenamento de profiles | `4040` |

## O que é necessário para subir

### Requisitos

- Linux com arquitetura suportada pelas imagens utilizadas;
- Docker Engine;
- Docker Compose v2 (`docker compose`);
- Git;
- portas livres: `3000`, `3100`, `3200`, `4040`, `4041`, `4317`, `4318`, `9009` e `12345`;
- permissão para montar `/var/run/docker.sock` no container do Alloy;
- acesso local às portas `9101` e `9102`, caso as coletas do producer e worker devam retornar dados.

> O Compose usa `host.docker.internal:host-gateway`, recurso suportado pelo Docker Engine moderno em Linux. Em versões antigas, atualize o Docker antes de executar a stack.

### Dependências externas atuais

O projeto espera que estas redes Docker já existam:

```bash
docker network create frontend
docker network create monitoring
```

Os comandos são idempotentes apenas quando tratados pelo shell. Para não receber erro caso as redes já existam, use:

```bash
docker network inspect frontend >/dev/null 2>&1 || docker network create frontend
docker network inspect monitoring >/dev/null 2>&1 || docker network create monitoring
```

### Caminhos utilizados pelo Compose

A configuração atual utiliza os seguintes caminhos absolutos:

```text
/opt/docker/stacks/observability
/opt/docker/volumes/observability
```

Para executar exatamente como o projeto está configurado, clone o repositório no primeiro caminho:

```bash
sudo mkdir -p /opt/docker/stacks
sudo git clone https://github.com/CHRIS-PIK/observability-lab.git \
  /opt/docker/stacks/observability
```

Crie os diretórios persistentes:

```bash
sudo mkdir -p \
  /opt/docker/volumes/observability/grafana \
  /opt/docker/volumes/observability/loki \
  /opt/docker/volumes/observability/mimir \
  /opt/docker/volumes/observability/tempo \
  /opt/docker/volumes/observability/pyroscope
```

Ajuste a propriedade dos diretórios caso algum container apresente erro de permissão. Evite aplicar `chmod 777`; verifique primeiro o UID usado pela imagem e conceda somente o acesso necessário.

## Instalação

```bash
cd /opt/docker/stacks/observability

docker network inspect frontend >/dev/null 2>&1 || docker network create frontend
docker network inspect monitoring >/dev/null 2>&1 || docker network create monitoring

docker compose config
docker compose pull
docker compose up -d
```

Confira o estado dos serviços:

```bash
docker compose ps
```

Acompanhe a inicialização:

```bash
docker compose logs -f --tail=100
```

## Acessos

| Serviço | Endereço |
|---|---|
| Grafana | `http://localhost:3000` |
| Alloy UI | `http://localhost:12345` |
| Loki | `http://localhost:3100/ready` |
| Mimir | `http://localhost:9009/ready` |
| Tempo | `http://localhost:3200/ready` |
| Pyroscope | `http://localhost:4040` |

Credenciais iniciais do Grafana:

```text
Usuário: admin
Senha: admin
```

> Troque a senha imediatamente quando o ambiente não estiver isolado. As credenciais estão declaradas diretamente no `docker-compose.yml` e são adequadas apenas para laboratório.

## Datasources provisionados

O Grafana carrega automaticamente:

| Nome | Tipo | Destino |
|---|---|---|
| `Mimir-homelab` | Prometheus | `http://mimir:9009/prometheus` |
| `Loki-homelab` | Loki | `http://loki:3100` |
| `Tempo-homelab` | Tempo | `http://tempo:3200` |

O Mimir é configurado como datasource padrão.

O Pyroscope está em execução e recebe profiles, mas ainda não existe datasource do Pyroscope no arquivo de provisioning atual. Ele pode ser acessado diretamente pela porta `4040` ou adicionado posteriormente ao Grafana.

## Alvos observados atualmente

### Host e containers Docker

O Alloy:

- coleta métricas do host por meio do exporter Unix integrado;
- descobre containers pelo Docker socket;
- envia os logs para o Loki;
- adiciona labels de container, serviço e projeto Compose;
- define o label estático de host como `olympus`.

### Argos

Containers com estes nomes recebem os labels `application="argos"` e `environment="homelab"`:

```text
aruba-producer
aruba-worker
aruba-mariadb
```

### Datalake

O Alloy coleta:

```text
host.docker.internal:9101  job=datalake-producer
host.docker.internal:9102  job=datalake-worker
```

Esses serviços precisam publicar suas métricas no host nessas portas. A stack de observabilidade sobe mesmo sem eles, mas esses dois scrapes permanecerão indisponíveis.

### OTLP

Aplicações podem enviar telemetria para:

```text
gRPC: http://<IP_DO_HOST>:4317
HTTP: http://<IP_DO_HOST>:4318
```

O pipeline atual encaminha:

- métricas para o Mimir;
- logs para o Loki;
- traces para o Tempo.

### Profiles

Aplicações instrumentadas podem enviar profiles ao Alloy na porta `4041`. O Alloy encaminha os dados para o Pyroscope em `http://pyroscope:4040`.

## Estrutura do repositório

```text
.
├── config
│   ├── alloy
│   │   └── config.alloy
│   ├── grafana
│   │   └── provisioning
│   │       └── datasources
│   │           └── datasources.yml
│   ├── loki
│   │   └── loki-config.yml
│   ├── mimir
│   │   └── mimir-config.yml
│   ├── pyroscope
│   │   └── config.yaml
│   └── tempo
│       └── tempo-config.yml
├── docker-compose.yml
└── README.md
```

## Validação pós-instalação

### 1. Containers

```bash
docker compose ps
```

Todos devem aparecer como `Up`.

### 2. Configuração efetiva do Compose

```bash
docker compose config
```

Esse comando deve terminar sem erros antes do `up`.

### 3. Logs do Alloy

```bash
docker compose logs alloy --tail=200
```

Verifique erros de configuração, acesso ao Docker socket e conexão com os backends.

### 4. Métricas no Mimir

No Grafana, abra **Explore**, selecione `Mimir-homelab` e execute:

```promql
up
```

Para validar o host:

```promql
node_uname_info
```

Para conferir os alvos do datalake:

```promql
up{job=~"datalake-producer|datalake-worker"}
```

### 5. Logs no Loki

No Explore, selecione `Loki-homelab` e execute:

```logql
{job="docker"}
```

Para o Argos:

```logql
{application="argos"}
```

### 6. Traces no Tempo

Envie um trace OTLP para a porta `4317` ou `4318` e pesquise pelo serviço no datasource `Tempo-homelab`.

### 7. Profiles no Pyroscope

Envie um profile para `<IP_DO_HOST>:4041` e consulte a interface em `http://localhost:4040`.

## Operação

Subir ou atualizar:

```bash
docker compose pull
docker compose up -d
```

Reiniciar um serviço:

```bash
docker compose restart alloy
```

Ver logs:

```bash
docker compose logs -f alloy
```

Parar sem apagar os dados:

```bash
docker compose down
```

Remover containers e redes internas do projeto, preservando os bind mounts:

```bash
docker compose down --remove-orphans
```

## Persistência e retenção

Os dados são persistidos em bind mounts sob:

```text
/opt/docker/volumes/observability
```

Configurações relevantes:

- Tempo: retenção de blocos de traces de `24h`;
- Loki: armazenamento local em filesystem, sem política explícita de retenção no arquivo atual;
- Mimir: armazenamento local em filesystem, sem política explícita de retenção no arquivo atual;
- Pyroscope: armazenamento local em filesystem;
- Grafana: banco e estado persistidos em `/var/lib/grafana`.

Monitore o uso de disco do host, principalmente nos diretórios do Loki, Mimir e Pyroscope.

## Pontos de portabilidade identificados

A stack é funcional, mas ainda não é totalmente plug-and-play em qualquer diretório. Para executá-la sem alterar o comportamento observado hoje, considere os seguintes pontos:

1. **Bind mounts absolutos:** o repositório precisa estar em `/opt/docker/stacks/observability`, ou o Compose precisa ser ajustado para caminhos relativos/variáveis.
2. **Redes externas:** `frontend` e `monitoring` precisam existir antes do `docker compose up`.
3. **Docker socket:** a coleta automática de logs depende de `/var/run/docker.sock`, portanto o projeto é orientado a Docker Engine em Linux.
4. **Alvos do datalake:** producer e worker precisam estar acessíveis no host nas portas `9101` e `9102`.
5. **Labels específicos:** os nomes `aruba-producer`, `aruba-worker` e `aruba-mariadb`, além dos labels `olympus`, `argos` e `homelab`, fazem parte da observação atual e foram mantidos.
6. **Portas publicadas:** não pode haver conflito com serviços já existentes no host.
7. **Permissões de armazenamento:** os containers precisam conseguir escrever nos diretórios persistentes.
8. **Credenciais de laboratório:** Grafana inicia com `admin/admin`; isso não deve ser usado em produção.
9. **Single-node:** Loki, Mimir, Tempo e Pyroscope estão configurados com armazenamento local e topologia de nó único; o projeto não oferece alta disponibilidade.
10. **Arquitetura do host:** todas as imagens fixadas devem possuir build compatível com a CPU da máquina de destino.

## Melhorias futuras sem mudar os alvos observados

Estas mudanças podem tornar a instalação portátil sem retirar ou substituir nenhuma coleta atual:

- substituir caminhos absolutos de configuração por caminhos relativos ao repositório;
- usar volumes nomeados ou uma variável `DATA_ROOT` para persistência;
- fornecer um `.env.example` com portas, credenciais e diretório de dados;
- incluir um script `bootstrap.sh` para criar redes e diretórios;
- adicionar healthchecks aos serviços e dependências condicionadas à saúde;
- provisionar o datasource do Pyroscope;
- mover a senha do Grafana para `.env` ou Docker Secret;
- adicionar políticas explícitas de retenção para Loki e Mimir;
- adicionar validação automatizada do Compose em CI.

## Escopo

Este repositório é um laboratório single-node. Ele não inclui TLS, autenticação entre os componentes, alta disponibilidade, object storage externo, backup automatizado ou hardening para exposição pública.

## Licença

Nenhuma licença foi definida até o momento.