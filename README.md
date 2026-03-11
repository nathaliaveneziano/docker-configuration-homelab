# 🏠 docker-configuration — Homelab Stack

<div align="center">

![Status](https://img.shields.io/badge/status-em%20desenvolvimento-yellow?style=for-the-badge&logo=checkmarx)
![Docker](https://img.shields.io/badge/Docker-2496ED?style=for-the-badge&logo=docker&logoColor=white)
![WSL2](https://img.shields.io/badge/WSL2-Otimizado-orange?style=for-the-badge&logo=windows)
![Ubuntu](https://img.shields.io/badge/Ubuntu-24.04-E95420?style=for-the-badge&logo=ubuntu&logoColor=white)
![NVIDIA](https://img.shields.io/badge/GTX%201650-4GB-76B900?style=for-the-badge&logo=nvidia&logoColor=white)
![License](https://img.shields.io/badge/license-MIT-blue?style=for-the-badge)

**Stack completa de homelab para pequenas startups — IA local, automação de workflows, processamento de mídia e gestão de conteúdo, organizada em 17 camadas e otimizada para WSL2 com hardware limitado.**

[📖 Documentação](#-índice) · [🚀 Início Rápido](#-início-rápido) · [🏗️ Arquitetura](#️-arquitetura) · [📦 Containers](#-containers-por-camada)

</div>

---

## 📋 Índice

- [Visão Geral](#-visão-geral)
- [Hardware de Referência](#-hardware-de-referência)
- [Configuração do WSL2](#️-configuração-do-wsl2)
- [Arquitetura](#️-arquitetura)
- [Estrutura do Projeto](#-estrutura-do-projeto)
- [Containers por Camada](#-containers-por-camada)
- [Ordem de Inicialização](#-ordem-de-inicialização)
- [Início Rápido](#-início-rápido)
- [Scripts Globais](#-scripts-globais)
- [Estratégia de Backup](#-estratégia-de-backup)
- [Arquivo .env Global](#-arquivo-env-global)
- [Docker Networks](#-docker-networks)
- [Boas Práticas](#-boas-práticas)
- [Manutenção](#-manutenção)
- [FAQ](#-faq)
- [Referências](#-referências)

---

## 🎯 Visão Geral

Este repositório contém a configuração completa de uma stack homelab voltada para pequenas startups e desenvolvedores independentes. A proposta é centralizar, em um único repositório versionado, todos os serviços necessários para:

- **Proxy e segurança** — entrada única, SSL automático e proteção contra ameaças
- **IA local completa** — LLMs, visão computacional, geração de imagem, voz e música
- **Automação** — workflows com n8n integrando todos os serviços
- **Processamento de mídia** — vídeo, áudio, transcrição e geração assíncrona
- **Dados** — bancos relacionais, cache, fila de mensagens e storage de objetos
- **CMS** — WordPress com publicação automatizada por IA

Todos os serviços são organizados em **17 camadas** (layers), com configuração centralizada em um único `.env` global, networks Docker e scripts de setup reutilizáveis.

---

## 💻 Hardware de Referência

| Componente | Especificação |
|---|---|
| **Modelo** | Acer Nitro AN515-55 |
| **CPU** | Intel Core i5-10300H (4 cores / 8 threads) |
| **GPU** | NVIDIA GeForce GTX 1650 4GB VRAM |
| **RAM** | 8 GB SODIMM DDR4 |
| **SSD** | 256 GB — sistema, configs e dados operacionais |
| **HDD** | 1 TB — mídia, modelos de IA, backups e dados volumosos |
| **OS** | Windows + WSL2 (Ubuntu 24.04) |

### Estratégia de Recursos

Com 8 GB de RAM compartilhados entre Windows e WSL2, nunca inicie todos os containers simultaneamente. A recomendação por prioridade:

| Prioridade | Camadas | Observação |
|---|---|---|
| **Sempre ativos** | 1, 2, 3, 4, 5 | Proxy, segurança, gestão, dados |
| **Conforme uso** | 6, 7, 17 | CMS, automação, integrações |
| **Sob demanda** | 8–15 | IA e mídia — uma workload por vez |
| **Periódico** | 16 | Storage — verificar durante backups |

> ⚠️ **Regra de ouro:** Nunca iniciar dois workers de IA simultaneamente. Com 4 GB de VRAM e 5 GB de RAM disponíveis para WSL2, escolha **um** workload pesado por vez entre LLM, geração de imagem, vídeo e transcrição.

---

## 🖥️ Configuração do WSL2

### `.wslconfig` recomendado

O arquivo `.wslconfig` controla os limites de recursos do WSL2. Ele fica em `C:\Users\SEU_USUARIO\.wslconfig` e afeta diretamente a estabilidade dos containers Docker.

O arquivo já está disponível na raiz do projeto como `.wslconfig` — basta copiar para o diretório do usuário no Windows.

```ini
# ==========================================================
# Otimizado para:
#   Docker + IA + Automação + Media Stack
#   Notebook com 8 GB RAM / GTX 1650 4 GB VRAM / SSD 256 GB
# ==========================================================

[wsl2]

# 5 GB para o WSL → 3 GB restam para Windows + Chrome/VSCode
# Não ultrapasse 6 GB ou o Windows ficará instável
memory=5GB

# 3 de 8 threads — mantém o Windows responsivo durante
# workloads pesados de IA (Ollama, Whisper, SD)
processors=3

# Buffer de swap de 2 GB para picos pontuais
# Não aumente além disso: swap degrada o SSD 256 GB
swap=2GB

# Libera RAM ociosa do WSL2 de volta para o Windows
pageReporting=true

# Encaminha portas do WSL2 para localhost do Windows
localhostForwarding=true

[experimental]

# Recupera memória gradualmente quando containers param
autoMemoryReclaim=gradual

# Espelha interfaces de rede do Windows — resolve problemas
# com Docker + VPN + Cloudflare Tunnel
networkingMode=mirrored

# Melhora resolução DNS em redes com VPN ou corporativas
dnsTunneling=true
```

### Aplicando as configurações

**1. Copiar o arquivo** — no PowerShell:

```cmd
copy .wslconfig %USERPROFILE%\.wslconfig
```

**2. Aplicar** — reiniciar o WSL:

```cmd
wsl --shutdown
```

**3. Iniciar novamente:**

```cmd
wsl -d Ubuntu
```

**4. Verificar os limites aplicados** — dentro do WSL:

```bash
free -h      # Saída esperada: Mem: ~4.8Gi
nproc        # Saída esperada: 3
```

> 💡 **Por que `processors=3`?** Com 4 threads para o WSL, o Windows pode ficar sem núcleos livres durante workloads de IA, causando travamentos. Com 3, o Windows sempre tem ao menos 1 thread exclusivo.

> 💡 **Por que `swap=2GB`?** Swap excessivo grava continuamente no SSD. Com 256 GB e ciclos de escrita limitados, manter em 2 GB preserva a vida útil do disco.

---

## 🏗️ Arquitetura

### Diagrama de Camadas

```
┌──────────────────────────────────────────────────────────────┐
│                      INTERNET / LAN                          │
└───────────────────────────┬──────────────────────────────────┘
                            │
┌───────────────────────────▼──────────────────────────────────┐
│  CAMADA 1 — EDGE / PROXY                                     │
│  Nginx Proxy Manager  ·  Cloudflare Tunnel                   │
└───────────────────────────┬──────────────────────────────────┘
                            │
┌───────────────────────────▼──────────────────────────────────┐
│  CAMADA 2 — SEGURANÇA                                        │
│  Authelia (SSO/2FA)  ·  CrowdSec (IPS)                       │
└───────────────────────────┬──────────────────────────────────┘
                            │
┌───────────────────────────▼──────────────────────────────────┐
│  CAMADA 3 — ORQUESTRAÇÃO                                     │
│  Portainer CE                                                │
└───────────────────────────┬──────────────────────────────────┘
                            │
         ┌──────────────────┼──────────────────┐
         │                  │                  │
┌────────▼────────┐ ┌───────▼───────┐ ┌────────▼────────┐
│  CAMADA 4       │ │  CAMADA 5     │ │  CAMADA 6       │
│  BANCOS         │ │  ADMIN DB     │ │  CMS            │
│  MariaDB        │ │  Adminer      │ │  WordPress      │
│  PostgreSQL     │ └───────────────┘ └─────────────────┘
│  Redis          │
│  RabbitMQ       │
└────────┬────────┘
         │
┌────────▼────────────────────────────────────────────────────┐
│  CAMADA 7 — AUTOMAÇÃO                                       │
│  n8n                                                        │
└────────┬────────────────────────────────────────────────────┘
         │
         │  ◄── Workers de IA (um por vez) ──►
         │
┌────────▼──┐ ┌────────────┐ ┌───────────┐ ┌──────────────┐
│ CAMADA 8  │ │  CAMADA 9  │ │ CAMADA 10 │ │  CAMADA 11   │
│  LLM      │ │  VISÃO     │ │  VÍDEO    │ │  TRANSCRIÇÃO │
│  Ollama   │ │  LLaVA     │ │  FFmpeg   │ │  Whisper     │
│  Open     │ │            │ │  Worker   │ │  ASR WebSvc  │
│  WebUI    │ │            │ │           │ │              │
└───────────┘ └────────────┘ └───────────┘ └──────────────┘

┌───────────┐ ┌────────────┐ ┌───────────┐ ┌──────────────┐
│ CAMADA 12 │ │  CAMADA 13 │ │ CAMADA 14 │ │  CAMADA 15   │
│  IMAGEM   │ │  VOZ       │ │  MÚSICA   │ │  MEDIA PROC. │
│  Stable   │ │  Coqui TTS │ │ AudioCraft│ │  API + Queue │
│  Diffusion│ │  Piper TTS │ │           │ │  Workers     │
└───────────┘ └────────────┘ └───────────┘ └──────────────┘
         │
┌────────▼────────────────────────────────────────────────────┐
│  CAMADA 16 — STORAGE                                        │
│  MinIO (S3-compatible)                                      │
└────────┬────────────────────────────────────────────────────┘
         │
┌────────▼────────────────────────────────────────────────────┐
│  CAMADA 17 — INTEGRAÇÕES                                    │
│  Prometheus  ·  Grafana  ·  cAdvisor  ·  Uptime Kuma        │
│  Duplicati                                                  │
└─────────────────────────────────────────────────────────────┘
```

### Fluxo de Rede

Todos os serviços se comunicam pela mesma Docker network. O Nginx Proxy Manager é o único ponto de entrada externo — nenhum outro container expõe portas públicas diretamente.

```
Externo → NPM (80/443) → [container]:porta_interna
```

---

## 📁 Estrutura do Projeto

```
docker-configuration/
│
├── .env                          # 🔑 Variáveis globais (NÃO versionar)
├── .env.example                  # 📋 Template do .env (versionado)
├── .gitignore                    # 🚫 Ignora .env, data/, backups/, logs/
├── .wslconfig                    # 🖥️ Config WSL2 recomendada (copiar para ~/)
│
├── scripts/                      # 🔧 Scripts globais de setup e manutenção
│   ├── setup-networks.sh         # Cria Docker networks
│   ├── setup-env-links.sh        # Cria symlinks do .env global
│   ├── backup-all-v1.sh          # Backup global — log diário único
│   ├── backup-all-v2.sh          # Backup global — log por execução (multi-diário)
│   ├── install-backup-cron-v1.sh # Instala cron com horário fixo 02:00
│   └── install-backup-cron-v2.sh # Instala cron interativo via BACKUP_SCHEDULE
│
├── logs/                         # 📄 Logs dos backups globais (gerado em runtime)
│
├── edge/                         # Camada 1 — Proxy / Entrada
│   ├── nginx-proxy-manager/
│   └── cloudflare-tunnel/
│
├── security/                     # Camada 2 — Segurança
│   ├── authelia/
│   └── crowdsec/
│
├── orchestration/                # Camada 3 — Orquestração
│   └── portainer/
│
├── database/                     # Camada 4 — Bancos de Dados
│   ├── mariadb/
│   ├── postgresql/
│   ├── redis/
│   └── rabbitmq/
│
├── database-admin/               # Camada 5 — Admin de Banco
│   └── adminer/
│
├── cms/                          # Camada 6 — CMS
│   └── wordpress/
│
├── automation/                   # Camada 7 — Automação
│   └── n8n/
│
├── llm/                          # Camada 8 — LLM
│   ├── ollama/
│   └── open-webui/
│
├── vision/                       # Camada 9 — Visão Computacional
│   └── llava/
│
├── video/                        # Camada 10 — Processamento de Vídeo
│   └── video-worker/
│
├── transcription/                # Camada 11 — Transcrição
│   └── whisper/
│
├── image-gen/                    # Camada 12 — Geração de Imagem
│   └── stable-diffusion/
│
├── tts/                          # Camada 13 — Voz (TTS)
│   ├── coqui-tts/
│   └── piper-tts/
│
├── music/                        # Camada 14 — Música
│   └── audiocraft/
│
├── media/                        # Camada 15 — Media Processor
│   ├── media-processor-api/
│   └── media-worker/
│
├── storage/                      # Camada 16 — Storage
│   └── minio/
│
└── integrations/                 # Camada 17 — Integrações
    ├── prometheus/
    ├── grafana/
    ├── cadvisor/
    ├── uptime-kuma/
    └── duplicati/
```

> **Convenção:** Cada serviço possui seu próprio `docker-compose.yml`, `README.md`, pasta `scripts/` com os scripts de ciclo de vida (`start.sh`, `stop.sh`, `backup.sh`, `restore.sh`) e um `.env` que é um **symlink** apontando para o `.env` global na raiz.

---

## 📦 Containers por Camada

### 🌐 Camada 1 — Edge / Proxy

| Container | Imagem | Porta(s) | Descrição |
|---|---|---|---|
| **Nginx Proxy Manager** | `jc21/nginx-proxy-manager:latest` | 80, 443 (+ 81 temp.) | Reverse proxy com interface web e SSL automático via Let's Encrypt. Ponto único de entrada para todos os serviços. Gerencia domínios, certificados e redirecionamentos pela UI. |
| **Cloudflare Tunnel** | `cloudflare/cloudflared:latest` | — | Exposição segura sem abrir portas no roteador nem exigir IP fixo. Conecta ao edge da Cloudflare via outbound, ideal para conexões residenciais. |

---

### 🔒 Camada 2 — Segurança

| Container | Imagem | Porta(s) | Descrição |
|---|---|---|---|
| **Authelia** | `authelia/authelia:latest` | 9091 (interno) | SSO com TOTP e WebAuthn. Adiciona autenticação de dois fatores a qualquer serviço protegido pelo NPM sem modificar o serviço em si. |
| **CrowdSec** | `crowdsecurity/crowdsec:latest` | — | IPS colaborativo baseado em comportamento. Analisa logs do NPM e bloqueia IPs maliciosos automaticamente, beneficiando-se da inteligência coletiva da comunidade. |

---

### 🐳 Camada 3 — Orquestração

| Container | Imagem | Porta(s) | Descrição |
|---|---|---|---|
| **Portainer CE** | `portainer/portainer-ce:latest` | 9443 (interno) | Interface web para gerenciar toda a stack Docker. Permite iniciar, parar, inspecionar logs, atualizar imagens e gerenciar volumes sem usar o terminal. |

---

### 🗄️ Camada 4 — Bancos de Dados

| Container | Imagem | Porta(s) | Descrição |
|---|---|---|---|
| **MariaDB** | `mariadb:lts` | 3306 (interno) | Banco relacional principal. Usado pelo WordPress e n8n. A tag LTS garante suporte de longo prazo e patches de segurança contínuos. |
| **PostgreSQL** | `postgres:16-alpine` | 5432 (interno) | Banco relacional para serviços que preferem PostgreSQL. Alpine para menor footprint de RAM. Utilizado por Authelia e eventuais apps adicionais. |
| **Redis** | `redis:7-alpine` | 6379 (interno) | Cache em memória e broker de filas rápidas. Utilizado pelo n8n para filas internas, pelo WordPress para cache de objetos e pelos workers de mídia para estado de jobs. |
| **RabbitMQ** | `rabbitmq:3-management-alpine` | 5672, 15672 (internos) | Message broker para filas assíncronas entre a Media Processor API e os workers. A tag `management` inclui interface web de monitoramento. |

---

### 🛠️ Camada 5 — Admin de Banco

| Container | Imagem | Porta(s) | Descrição |
|---|---|---|---|
| **Adminer** | `adminer:latest` | 8080 (interno) | Interface web leve para administrar MariaDB e PostgreSQL. Suporta múltiplos tipos de banco em uma única interface, sem overhead do phpMyAdmin. |

---

### 📝 Camada 6 — CMS

| Container | Imagem | Porta(s) | Descrição |
|---|---|---|---|
| **WordPress** | `wordpress:php8.3-fpm-alpine` + `nginx:alpine` | 80 (interno) | CMS para publicação de conteúdo gerado por IA. Configurado com PHP-FPM para melhor performance. Integrado ao n8n para publicação automática de posts, imagens e vídeos. |

---

### ⚙️ Camada 7 — Automação

| Container | Imagem | Porta(s) | Descrição |
|---|---|---|---|
| **n8n** | `n8nio/n8n:latest` | 5678 (interno) | Plataforma de automação no-code/low-code com mais de 400 integrações nativas. Orquestra todos os pipelines da stack: geração de posts, vídeos, podcasts, transcrições e publicação automática. |

**Principais pipelines configurados no n8n:**

| Pipeline | Fluxo |
|---|---|
| **Post automático** | Ollama gera artigo → Stable Diffusion gera capa → WordPress publica |
| **Vídeo curto** | Roteiro LLM → Piper TTS narra → Imagens SD → FFmpeg monta |
| **Podcast** | LLM cria roteiro → Coqui TTS → FFmpeg + trilha AudioCraft |
| **Transcrição** | Upload vídeo → FFmpeg extrai áudio → Whisper → texto + legendas SRT |
| **Thumbnail** | LLM cria conceito → Stable Diffusion gera → upscale → MinIO → WordPress |

---

### 🤖 Camada 8 — LLM

| Container | Imagem | Porta(s) | Descrição |
|---|---|---|---|
| **Ollama** | `ollama/ollama:latest` | 11434 (interno) | Servidor de LLMs locais. Suporta Llama 3, Mistral, Gemma, Phi-3 e outros. Utiliza GPU via CUDA quando disponível; fallback automático para CPU. Principal backend de texto da stack. |
| **Open WebUI** | `ghcr.io/open-webui/open-webui:latest` | 8080 (interno) | Interface tipo ChatGPT para o Ollama. Histórico de conversas, RAG, upload de documentos e suporte a múltiplos modelos. Acessível via NPM com autenticação Authelia. |

> 💡 Modelos recomendados para 8 GB RAM: `llama3.2:3b` (leve, rápido), `mistral:7b-q4` (balanceado), `phi3:mini` (menor consumo).

---

### 👁️ Camada 9 — Visão Computacional

| Container | Imagem | Porta(s) | Descrição |
|---|---|---|---|
| **LLaVA** | `ollama/ollama:latest` (modelo llava) | 11434 (interno, via Ollama) | Modelo multimodal de visão + linguagem. Analisa imagens, descreve cenas, extrai texto de imagens e gera alt-text automático para o WordPress. Executado via Ollama como modelo adicional. |

> ⚠️ LLaVA é um modelo carregado no Ollama (`ollama pull llava`), não um container separado. Listado como camada distinta por ser uma capacidade especializada com uso e limites de VRAM próprios.

---

### 🎬 Camada 10 — Processamento de Vídeo

| Container | Imagem | Porta(s) | Descrição |
|---|---|---|---|
| **Video Worker** | `linuxserver/ffmpeg:latest` | — | Worker assíncrono para corte, montagem, transcodificação e legendagem de vídeos via FFmpeg. Consome tarefas da fila RabbitMQ. Processa arquivos diretamente no HDD de 1 TB. |

---

### 🎙️ Camada 11 — Transcrição

| Container | Imagem | Porta(s) | Descrição |
|---|---|---|---|
| **Whisper ASR** | `onerahmet/openai-whisper-asr-webservice:latest` | 9000 (interno) | Transcrição de áudio e vídeo para texto via OpenAI Whisper. Expõe API REST. Suporta português e mais de 50 idiomas. Gera transcrições brutas e legendas SRT/VTT. |

---

### 🖼️ Camada 12 — Geração de Imagem

| Container | Imagem | Porta(s) | Descrição |
|---|---|---|---|
| **Stable Diffusion** | `universonic/stable-diffusion-webui:latest` | 7860 (interno) | Geração de imagens com IA via AUTOMATIC1111 WebUI. Utiliza a GTX 1650 4GB para inferência. Recomendado modelos SD 1.5 ou SDXL-Turbo dado o limite de VRAM. |

> 💡 Com 4 GB de VRAM: prefira modelos SD 1.5 (512×512) ou SDXL com `--lowvram`. Evite SDXL full e Flux sem quantização.

---

### 🔊 Camada 13 — Voz (TTS)

| Container | Imagem | Porta(s) | Descrição |
|---|---|---|---|
| **Coqui TTS** | `ghcr.io/coqui-ai/tts:latest` | 5002 (interno) | Síntese de voz com clonagem a partir de amostras de áudio. Ideal para narração de podcasts e vídeos com voz personalizada em português. |
| **Piper TTS** | `rhasspy/wyoming-piper:latest` | 10200 (interno) | TTS rápido e leve, otimizado para CPU. Excelente para geração de voz em volume sem ocupar GPU. Vozes em português disponíveis nativamente. |

---

### 🎵 Camada 14 — Música

| Container | Imagem | Porta(s) | Descrição |
|---|---|---|---|
| **AudioCraft** | `python:3.11-slim` (custom) | 7000 (interno) | Geração de trilhas sonoras e efeitos sonoros via Meta AudioCraft (MusicGen / AudioGen). Usado nos pipelines de vídeo e podcast para trilha de fundo automatizada. |

> ⚠️ Com GTX 1650, use modelos `small` ou `medium`. Nunca iniciar junto com Stable Diffusion ou Ollama com modelos grandes.

---

### 🎞️ Camada 15 — Media Processor

| Container | Imagem | Porta(s) | Descrição |
|---|---|---|---|
| **Media Processor API** | `python:3.12-slim` (custom) | 8000 (interno) | API REST central que recebe requisições de processamento de mídia e distribui jobs para a fila RabbitMQ. Ponto de entrada para todos os pipelines de produção de conteúdo. |
| **Media Worker** | `python:3.12-slim` (custom) | — | Worker genérico que consome jobs da fila e delega para os workers especializados das camadas 10–14 conforme o tipo de tarefa. |

---

### 🪣 Camada 16 — Storage

| Container | Imagem | Porta(s) | Descrição |
|---|---|---|---|
| **MinIO** | `minio/minio:latest` | 9000, 9001 (internos) | Object storage S3-compatível auto-hospedado. Centraliza armazenamento de mídia gerada (imagens, vídeos, áudios, modelos). Integra nativamente com WordPress, n8n e workers. Armazena dados no HDD de 1 TB. |

---

### 🔗 Camada 17 — Integrações

| Container | Imagem | Porta(s) | Descrição |
|---|---|---|---|
| **Prometheus** | `prom/prometheus:latest` | 9090 (interno) | Coleta e armazena métricas de todos os containers em série temporal. Scraping configurável por serviço. |
| **Grafana** | `grafana/grafana:latest` | 3000 (interno) | Dashboards visuais para métricas do Prometheus. Alertas por email ou Telegram. Dashboard recomendado: ID 14282. |
| **cAdvisor** | `gcr.io/cadvisor/cadvisor:latest` | 8080 (interno) | Coleta automática de métricas de todos os containers Docker (CPU, RAM, rede, I/O de disco). Fonte de dados para o Prometheus. |
| **Uptime Kuma** | `louislam/uptime-kuma:latest` | 3001 (interno) | Monitoramento de uptime com alertas. Verifica disponibilidade de todos os serviços e notifica via Telegram, email ou webhook. |
| **Duplicati** | `duplicati/duplicati:latest` | 8200 (interno) | Backup incremental criptografado. Suporta HDD local, S3/MinIO, Google Drive. Agendamento por cron e retenção configurável por dias. |

---

## 🔢 Ordem de Inicialização

Siga a ordem abaixo para evitar erros de dependência. Containers que dependem de banco de dados ou fila precisam que esses serviços já estejam `healthy`.

```
1️⃣  database        → mariadb, postgresql, redis, rabbitmq
2️⃣  edge            → nginx-proxy-manager
3️⃣  security        → crowdsec, authelia
4️⃣  orchestration   → portainer
5️⃣  database-admin  → adminer
6️⃣  storage         → minio
7️⃣  cms             → wordpress
8️⃣  automation      → n8n
9️⃣  integrations    → cadvisor, prometheus, grafana, uptime-kuma, duplicati

── Sob demanda (um por vez) ──────────────────────────────

🔟  llm             → ollama → open-webui
1️⃣1️⃣  image-gen       → stable-diffusion
1️⃣2️⃣  transcription   → whisper
1️⃣3️⃣  tts             → piper-tts OU coqui-tts
1️⃣4️⃣  music           → audiocraft
1️⃣5️⃣  vision          → llava (via ollama)
1️⃣6️⃣  video           → video-worker
1️⃣7️⃣  media           → media-processor-api → media-worker
```

---

## 🚀 Início Rápido

### Pré-requisitos

```bash
# Docker Engine
docker --version          # 24.0+

# Docker Compose v2
docker compose version    # v2.0+

# Portas disponíveis
sudo ss -tlnp | grep -E ':(80|443)\s'
# Sem saída = portas livres ✅

# UID/GID do usuário (importante para volumes WSL2)
id -u && id -g            # geralmente: 1000 / 1000
```

### Passo 1 — Configurar o WSL2

```cmd
# No Windows — copiar o .wslconfig para o diretório do usuário
copy .wslconfig %USERPROFILE%\.wslconfig

# Reiniciar o WSL para aplicar
wsl --shutdown
```

### Passo 2 — Clonar o repositório

```bash
git clone https://github.com/seu-usuario/docker-configuration.git
cd docker-configuration
```

### Passo 3 — Configurar o `.env` global

```bash
cp .env.example .env
nano .env
```

Campos obrigatórios mínimos:

```dotenv
NETWORK_NAME=proxy_network
NETWORK_SUBNET=172.20.0.0/24
NETWORK_GATEWAY=172.20.0.1
DOMAIN_NAME=meudominio.com
TIMEZONE=America/Sao_Paulo
PUID=1000
PGID=1000
SSD_PATH=/home/usuario/docker-configuration
HDD_PATH=/mnt/hdd/docker-configuration
```

### Passo 4 — Executar scripts de setup

```bash
chmod +x scripts/*.sh

# 1. Criar Docker network
./scripts/setup-networks.sh

# 2. Criar symlinks do .env em todos os serviços
./scripts/setup-env-links.sh
```

### Passo 5 — Iniciar pela ordem correta

```bash
# Dados primeiro
cd database/mariadb  && bash scripts/start.sh && cd ../..
cd database/redis    && bash scripts/start.sh && cd ../..

# Edge
cd edge/nginx-proxy-manager && bash scripts/start.sh && cd ../..

# Continuar conforme a ordem de inicialização...
```

### Passo 6 — Instalar o backup automático

```bash
# Versão simples — backup todo dia às 02:00
bash scripts/install-backup-cron-v1.sh

# Versão flexível — define horário interativamente via .env
bash scripts/install-backup-cron-v2.sh
```

---

## 🔧 Scripts Globais

Todos os scripts ficam em `scripts/` e seguem o mesmo padrão: variáveis de cor, cabeçalhos visuais, log com timestamp e saída descritiva de cada etapa.

### Ordem de execução

```
clone do repositório
        │
        ▼
setup-networks.sh              ← uma vez: cria a bridge network
        │
        ▼
setup-env-links.sh             ← uma vez: cria os symlinks .env
        │
        ▼
[subir os containers]          ← start.sh por serviço, na ordem das camadas
        │
        ▼
install-backup-cron-v1.sh      ← uma vez: registra cron fixo 02:00
    ou
install-backup-cron-v2.sh      ← uma vez: registra cron interativo
        │
        ▼
backup-all-v1.sh / v2.sh       ← automático via cron ou manual sob demanda
```

---

### `scripts/setup-networks.sh`

Cria todas as Docker networks necessárias com as configurações do `.env` global.

**Quando usar:**
- Na primeira vez que o projeto é clonado
- Após alterar `NETWORK_NAME`, `NETWORK_SUBNET` ou `NETWORK_GATEWAY` no `.env`
- Após um `docker network rm` acidental

**Como usar:**

```bash
chmod +x scripts/setup-networks.sh
./scripts/setup-networks.sh
```

**O que o script faz:**

1. Carrega o `.env` global da raiz
2. Para cada network configurada, verifica se já existe
3. Se existir: compara configuração atual com o `.env` e avisa sobre divergências
4. Se não existir: cria com `--driver bridge`, subnet e gateway definidos
5. Lista todas as networks bridge disponíveis ao final
6. Exibe containers conectados a cada network

**Saída esperada:**

```
================================================
🌐 Configurando Docker Networks
================================================
✅ Variáveis carregadas do .env

   📡 Criando proxy_network...
   ✅ proxy_network (criada)
      Subnet:   172.20.0.0/24
      Gateway:  172.20.0.1

================================================
🎉 Configuração de Networks concluída!
================================================

📋 Networks Bridge disponíveis:
NAME             DRIVER    SCOPE
proxy_network    bridge    local
bridge           bridge    local
```

**Adicionar novas networks:** Descomente os blocos comentados no script para criar networks isoladas para banco de dados, IA ou backend.

---

### `scripts/setup-env-links.sh`

Percorre todos os `docker-compose.yml` do projeto e cria um **symlink** `.env` em cada pasta de serviço apontando para o `.env` global da raiz.

**Quando usar:**
- Na primeira vez que o projeto é clonado
- Ao adicionar um novo container ao projeto
- Se algum symlink for quebrado (aparece em vermelho no `ls -la`)

**Como usar:**

```bash
chmod +x scripts/setup-env-links.sh
./scripts/setup-env-links.sh
```

**O que o script faz:**

1. Localiza o `.env` global na raiz
2. Busca recursivamente todos os `docker-compose.yml` (excluindo `.git`, `scripts`, `docs`)
3. Para `[layer]/[service]/`: cria symlink `../../.env` (2 níveis acima)
4. Para serviços na raiz: cria symlink `../.env` (1 nível acima)
5. Symlink correto existente → confirma "OK"
6. Symlink apontando para destino errado → atualiza automaticamente
7. Arquivo `.env` regular existente → faz backup com timestamp e substitui por symlink

**Saída esperada:**

```
================================================
🔗 Criando Symlinks do .env
   Estrutura: [layer]/[service]/.env → ../../.env
================================================

✅ Arquivo .env global encontrado

📁 [edge]
   ✅ edge/nginx-proxy-manager/.env → ../../.env (criado)
   ✅ edge/cloudflare-tunnel/.env → ../../.env (criado)

📁 [security]
   ✅ security/authelia/.env → ../../.env (criado)
   ✅ security/crowdsec/.env → ../../.env (criado)

📁 [database]
   ✅ database/mariadb/.env → ../../.env (criado)
   ✅ database/postgresql/.env → ../../.env (criado)
   ✅ database/redis/.env → ../../.env (criado)
   ✅ database/rabbitmq/.env → ../../.env (criado)

[...]

================================================
🎉 Symlinks criados com sucesso!
   Total de serviços processados: 26
================================================
```

**Verificar symlinks:**

```bash
# Listar todos os symlinks .env
find . -name '.env' -type l | sort

# Verificar destino de um symlink
readlink edge/nginx-proxy-manager/.env
# ../../.env

# Testar se o symlink está funcional
cat edge/nginx-proxy-manager/.env | head -3
```

---

### `scripts/backup-all-v1.sh`

Executa o `backup.sh` de todos os containers em ordem de dependência. Versão com **log único diário** — indicada para agendamento simples de uma execução por dia.

**Quando usar:** agendamento fixo (ex: apenas às 02:00), ou manualmente antes de atualizações.

```bash
bash scripts/backup-all-v1.sh
```

**Saída esperada:**

```
================================================
💾 Backup Global - Stack Homelab
   2025-03-09 02:00:01
================================================

📁 [database]
   🔄 mariadb — iniciando backup...
   ✅ mariadb — backup concluído
   🔄 postgresql — iniciando backup...
   ✅ postgresql — backup concluído
   ⚠️  redis — backup.sh não encontrado (pulando)

📁 [storage]
   🔄 minio — iniciando backup...
   ✅ minio — backup concluído

[...]

🧹 Limpando logs antigos (mantendo últimos 30)...
   ✅ Limpeza concluída

================================================
📋 Resumo do Backup Global
================================================
   Total de serviços : 26
   ✅ Sucesso          : 18
   ⚠️  Pulados          : 7
   ❌ Falhas           : 1

🔴 Serviços com falha:
   • cms/wordpress

💡 Para investigar: cat logs/backup-all_20250309.log
================================================
```

**Log gerado:** `logs/backup-all_YYYYMMDD.log`

---

### `scripts/backup-all-v2.sh`

Idêntico ao v1 em comportamento, com uma diferença: o **nome do log inclui horário** (`YYYYMMDD_HHMMSS`). Indicado para agendamentos com múltiplas execuções por dia, onde cada execução deve manter seu log independente.

```bash
bash scripts/backup-all-v2.sh
```

**Log gerado:** `logs/backup-all_YYYYMMDD_HHMMSS.log`

| | v1 | v2 |
|---|---|---|
| **Nome do log** | `backup-all_20250309.log` | `backup-all_20250309_020001.log` |
| **2 execuções/dia** | Segunda sobrescreve a primeira | Cada uma tem seu próprio log |
| **Quando usar** | Agendamento único diário | Múltiplos horários no dia |

---

### `scripts/install-backup-cron-v1.sh`

Registra o `backup-all-v1.sh` no crontab com horário **fixo**: todos os dias às **02:00**. Sem perguntas, sem configuração.

**Quando usar:** quando não há necessidade de personalizar o horário.

```bash
bash scripts/install-backup-cron-v1.sh
```

O script:
1. Verifica e inicia o serviço `cron` se necessário
2. Remove entrada anterior se existir
3. Registra `0 2 * * *` no crontab
4. Oferece registrar no Windows Task Scheduler (acorda o WSL2 às 02:00)

**Saída esperada:**

```
================================================
⏰ Instalando Cron — Backup Global
   Horário fixo: todos os dias às 02:00
================================================

✅ Cron registrado com sucesso!

================================================
📋 Configuração registrada
================================================
   Horário    : todos os dias às 02:00
   Agendamento: 0 2 * * *
   Script     : /home/usuario/docker-configuration/scripts/backup-all.sh
   Log cron   : /home/usuario/docker-configuration/logs/backup-all-cron.log

⚠️  ATENÇÃO — Comportamento no WSL2:
   O cron só executa enquanto o WSL2 estiver ativo.
   Se o WSL2 estiver fechado às 02:00, o backup NÃO rodará.

🪟 Deseja registrar também no Windows Task Scheduler? (s/N):
```

---

### `scripts/install-backup-cron-v2.sh`

Registra o `backup-all-v2.sh` no crontab com agendamento **totalmente configurável**, lido do `BACKUP_SCHEDULE` no `.env` ou digitado interativamente.

**Quando usar:** quando você quer controle total sobre horário, dias da semana e frequência.

```bash
bash scripts/install-backup-cron-v2.sh
```

O script:
1. Lê `BACKUP_SCHEDULE` do `.env` e pergunta se quer usar ou alterar
2. Exibe tabela de exemplos de sintaxe cron
3. Mostra resumo e pede confirmação antes de instalar
4. Oferece atualizar o `.env` se o horário for diferente do registrado
5. Detecta o primeiro horário para o Windows Task Scheduler
6. Avisa sobre limitação de horários múltiplos no Windows

**Saída esperada:**

```
================================================
⏰ Instalando Agendamento — Backup Global
================================================

📅 Configuração do agendamento

   Formato cron: minuto hora dia-do-mês mês dia-da-semana

   Exemplos:
     0 2 * * *       → todo dia às 02:00
     0 2,14 * * *    → duas vezes por dia (02h e 14h)
     0 */6 * * *     → a cada 6 horas
     0 2 * * 1-5     → dias úteis às 02:00
     0 2 * * 6,0     → fins de semana às 02:00
     0 2 * * 1,3,5   → seg, qua e sex às 02:00
     30 1,13 * * *   → 01:30 e 13:30 todos os dias

   Valor atual no .env: 0 2 * * *

   Usar esse agendamento? (S/n):
```

---

## 💾 Estratégia de Backup

O projeto usa **três camadas complementares** de backup que não se substituem:

### Camada 1 — Backup operacional (`backup.sh` por container)

Script local em cada serviço, executado **manualmente antes de operações de risco** (atualizar imagem, migrar dados, rollback). Gera um `.tar.gz` local em `./backups/` em segundos.

```bash
# Antes de atualizar um serviço
bash database/mariadb/scripts/backup.sh

# Algo deu errado após a atualização
bash database/mariadb/scripts/restore.sh
```

### Camada 2 — Backup global automático (`backup-all`)

Orquestra todos os `backup.sh` da stack em ordem de dependência, executado pelo cron automaticamente. Gera histórico rotativo de até 30 logs.

```bash
# Instalar agendamento — feito uma vez
bash scripts/install-backup-cron-v1.sh   # horário fixo 02:00
bash scripts/install-backup-cron-v2.sh   # horário configurável via .env
```

### Camada 3 — Backup de desastre (Duplicati)

O Duplicati (Camada 17) faz backup incremental criptografado dos `data/` de todos os serviços para HDD, MinIO ou Google Drive. Cobre perda total do SSD, troca de hardware ou migração de servidor.

| | `backup.sh` | `backup-all` | Duplicati |
|---|---|---|---|
| **Escopo** | Um container | Toda a stack | Toda a stack |
| **Destino** | `./backups/` local | `./backups/` por serviço | HDD / MinIO / Cloud |
| **Quando** | Manual, sob demanda | Cron automático | Cron automático |
| **Velocidade** | Segundos | Minutos | Minutos a horas |
| **Restauração** | `bash restore.sh` | `bash restore.sh` por serviço | Interface web Duplicati |
| **Caso de uso** | Rollback rápido | Histórico diário | Desastre / troca de hardware |

---

## 🌐 Docker Networks

| Variável | Valor sugerido | Uso |
|---|---|---|
| `NETWORK_NAME` | `proxy_network` | Network principal compartilhada |
| `NETWORK_SUBNET` | `172.20.0.0/24` | Sub-rede (até 254 containers) |
| `NETWORK_GATEWAY` | `172.20.0.1` | Gateway da network |

**Networks adicionais opcionais** (descomentar no `setup-networks.sh`):

```bash
DATABASE_NETWORK_NAME=database_network   # 172.21.0.0/24 — isolamento de bancos
AI_NETWORK_NAME=ai_network               # 172.22.0.0/24 — isolamento de workers de IA
```

---

## 🔑 Arquivo .env Global

Um único `.env` na raiz controla toda a stack. Cada serviço acessa as variáveis via symlink. **Nunca versionar este arquivo** — apenas o `.env.example` vai ao Git.

```bash
cp .env.example .env
nano .env
```

O `.env.example` cobre as seguintes seções:

```dotenv
# ==========================================
# 🌐 REDE, CONECTIVIDADE E DOMÍNIO
# ==========================================
NETWORK_NAME=network_name
NETWORK_SUBNET=127.0.0.0/24
NETWORK_GATEWAY=127.0.0.1
DOMAIN_NAME=localhost

# ==========================================
# 🌍 CONFIGURAÇÕES REGIONAIS
# ==========================================
TIMEZONE=America/Sao_Paulo
LOCALE=pt_BR.UTF-8

# ==========================================
# 👤 USUÁRIO E PERMISSÕES
# ==========================================
# Use: id -u e id -g no Linux/WSL para obter seus valores
PUID=1000
PGID=1000

# ==========================================
# 💾 CAMINHOS DE ARMAZENAMENTO
# ==========================================
SSD_PATH=/home/usuario/docker-configuration
HDD_PATH=/mnt/hdd/docker-configuration

# ==========================================
# 🔄 BACKUP
# ==========================================
BACKUP_RETENTION_DAYS=7
BACKUP_SCHEDULE="0 2 * * *"
BACKUP_WINDOWS_TIME="02:00"

# (Demais variáveis adicionadas por cada container ao longo da stack)
```

> ⚠️ Cada camada acrescenta suas próprias variáveis ao `.env.example` via commits `chore(env-example)` — consulte o histórico do Git para ver o que cada container adicionou.

---

## ✅ Boas Práticas

### Segurança

- **Porta admin comentada por padrão** em todos os `docker-compose.yml` — descomentar apenas durante o setup inicial
- **Senhas geradas aleatoriamente**: `openssl rand -base64 32`
- **Nenhum container expõe portas diretamente** — tudo roteado pelo NPM
- **2FA via Authelia** em todos os painéis administrativos
- **`.env` nunca versionado** — apenas `.env.example` vai ao Git

### Recursos (8 GB RAM / 4 GB VRAM)

- **Limites de memória em todos os containers** — evita OOM kills em cascata
- **`memswap_limit == mem_limit`** — desabilita swap por container, protege o SSD
- **Workers de IA exclusivamente sob demanda** — nunca dois simultaneamente
- **Mídia e modelos no HDD** — preserva o SSD de 256 GB para dados operacionais
- **`restart: unless-stopped`** — reinício automático após falhas, nunca após `docker stop`

### Volumes e Dados

- **`./data/`** — dados persistentes no SSD
- **`./backups/`** — backups operacionais locais
- **`HDD_PATH`** — cópia fria via Duplicati com retenção configurável por `BACKUP_RETENTION_DAYS`
- **`./scripts/`** montado como `:ro` — scripts acessíveis dentro do container

---

## 🔧 Manutenção

### Verificar saúde de todos os containers

```bash
docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
```

### Verificar uso de recursos

```bash
docker stats --no-stream --format \
  "table {{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.MemPerc}}"
```

### Limpar recursos não utilizados

```bash
docker image prune -f    # Imagens sem uso
docker volume prune -f   # Volumes órfãos
docker network prune -f  # Redes sem uso
```

### Atualizar um serviço com segurança

```bash
# 1. Backup antes de qualquer alteração
bash [layer]/[service]/scripts/backup.sh

# 2. Baixar nova imagem
docker compose -f [layer]/[service]/docker-compose.yml pull

# 3. Recriar
docker compose -f [layer]/[service]/docker-compose.yml up -d --force-recreate

# 4. Verificar saúde
docker inspect [container] --format='{{.State.Health.Status}}'
```

### Ver logs de backup

```bash
# Último log de backup global
ls -t logs/backup-all_*.log | head -1 | xargs cat

# Log do cron (execuções automáticas)
cat logs/backup-all-cron.log

# Todos os logs disponíveis
ls -lh logs/backup-all_*.log
```

### Verificar cron instalado

```bash
crontab -l
```

---

## ❓ FAQ

**P: Posso rodar todos os containers ao mesmo tempo?**

R: Não é recomendado. Com 5 GB para WSL2, o limite prático é de 10 a 12 containers médios. Workers de IA consomem entre 1,5 e 4 GB cada. Mantenha sempre ativos apenas os das camadas 1–7 e 17; os demais sob demanda.

---

**P: Qual versão dos scripts de backup devo usar — v1 ou v2?**

R: Use **v1** se quiser um backup simples todo dia às 02:00 sem nenhuma configuração. Use **v2** se quiser escolher o horário, rodar em múltiplos momentos do dia ou agendar apenas em certos dias da semana — o agendamento é lido do `BACKUP_SCHEDULE` no `.env` e pode ser alterado interativamente.

---

**P: Qual a diferença entre `backup-all-v1` e `backup-all-v2`?**

R: O comportamento é idêntico. A única diferença é o nome do arquivo de log: v1 gera `backup-all_YYYYMMDD.log` (uma execução do mesmo dia sobrescreve), v2 gera `backup-all_YYYYMMDD_HHMMSS.log` (cada execução tem seu próprio arquivo). Use v2 quando `BACKUP_SCHEDULE` tiver múltiplos horários no dia.

---

**P: O cron roda se o WSL2 estiver fechado?**

R: Não. O cron do Linux dentro do WSL2 só executa enquanto o WSL2 está ativo. Para garantir que o backup rode mesmo com o WSL2 fechado, execute `install-backup-cron-v1.sh` ou `v2.sh` e responda `s` quando perguntado sobre o Windows Task Scheduler — ele acorda o WSL2 no horário certo.

---

**P: O Duplicati substitui os scripts de backup?**

R: Não. São três camadas complementares. O `backup.sh` por container faz rollback operacional local em segundos. O `backup-all` orquestra todos os `backup.sh` automaticamente via cron. O Duplicati faz backup incremental criptografado para destino externo para casos de desastre. Nenhum substitui o outro.

---

**P: O `.env` global funciona com symlinks?**

R: Sim. O Docker Compose segue o symlink e lê o arquivo real. O `setup-env-links.sh` garante que o caminho relativo `../../.env` seja válido a partir de qualquer `[layer]/[service]/`.

---

**P: Como adicionar um novo container?**

R: 1) Crie `[layer]/[service]/`; 2) Adicione `docker-compose.yml` e `README.md`; 3) Execute `./scripts/setup-env-links.sh`; 4) Adicione as novas variáveis ao `.env.example`; 5) Adicione o path em `BACKUP_ORDER` nos arquivos `backup-all-v1.sh` e `backup-all-v2.sh`.

---

**P: LLaVA é um container separado?**

R: Não. É um modelo carregado no Ollama (`ollama pull llava`). Está listado como camada separada porque tem limites de VRAM próprios e não deve ser carregado junto com outros modelos grandes.

---

**P: O que fazer se o WSL2 ficar sem memória?**

R: 1) `wsl --shutdown` no PowerShell; 2) Aguardar 10 segundos e reiniciar o WSL; 3) Identificar containers com alto consumo via `docker stats`; 4) Reduzir `mem_limit` dos containers problemáticos no `.env`.

---

**P: Qual a diferença entre Coqui TTS e Piper TTS?**

R: Coqui TTS oferece clonagem de voz a partir de amostras de áudio — ideal quando a voz final importa (podcasts, narração de marca). Piper TTS é mais leve e rápido, otimizado para CPU — ideal para geração em volume onde velocidade importa mais que personalização da voz.

---

**P: Por que `swap=2GB` e não mais no `.wslconfig`?**

R: Swap excessivo no WSL2 grava continuamente no disco. Com um SSD de 256 GB e ciclos de escrita limitados, manter o swap em 2 GB preserva a vida útil do drive. Para workloads de IA que precisem de mais memória, o correto é gerenciar quais modelos ficam carregados no Ollama.

---

## 📚 Referências

| Recurso | Link |
|---|---|
| Docker Engine | [docs.docker.com](https://docs.docker.com) |
| Docker Compose | [docs.docker.com/compose](https://docs.docker.com/compose/) |
| WSL2 | [learn.microsoft.com/wsl](https://learn.microsoft.com/pt-br/windows/wsl/) |
| WSL2 .wslconfig | [learn.microsoft.com/wsl/wsl-config](https://learn.microsoft.com/pt-br/windows/wsl/wsl-config) |
| Nginx Proxy Manager | [nginxproxymanager.com](https://nginxproxymanager.com/) |
| Cloudflare Tunnel | [developers.cloudflare.com](https://developers.cloudflare.com/cloudflare-one/connections/connect-networks/) |
| Authelia | [authelia.com](https://www.authelia.com/) |
| CrowdSec | [crowdsec.net](https://www.crowdsec.net/) |
| Portainer | [portainer.io](https://www.portainer.io/) |
| Ollama | [ollama.com](https://ollama.com/) |
| Open WebUI | [github.com/open-webui/open-webui](https://github.com/open-webui/open-webui) |
| n8n | [n8n.io](https://n8n.io/) |
| Stable Diffusion | [github.com/AUTOMATIC1111/stable-diffusion-webui](https://github.com/AUTOMATIC1111/stable-diffusion-webui) |
| Whisper ASR | [github.com/ahmetoner/whisper-asr-webservice](https://github.com/ahmetoner/whisper-asr-webservice) |
| Coqui TTS | [github.com/coqui-ai/TTS](https://github.com/coqui-ai/TTS) |
| Piper TTS | [github.com/rhasspy/piper](https://github.com/rhasspy/piper) |
| AudioCraft | [github.com/facebookresearch/audiocraft](https://github.com/facebookresearch/audiocraft) |
| MinIO | [min.io](https://min.io/) |
| Prometheus | [prometheus.io](https://prometheus.io/) |
| Grafana | [grafana.com](https://grafana.com/) |
| Duplicati | [duplicati.com](https://www.duplicati.com/) |

---

<div align="center">

**Homelab Stack — Pequenas Startups & Desenvolvedores Independentes**

![Camadas](https://img.shields.io/badge/Camadas-17-4A90D9?style=flat-square)
![Containers](https://img.shields.io/badge/Containers-26%2B-2496ED?style=flat-square&logo=docker)
![Scripts](https://img.shields.io/badge/Scripts-6-orange?style=flat-square)
![WSL2](https://img.shields.io/badge/Testado-WSL2%20Ubuntu%2024-success?style=flat-square&logo=ubuntu)
![Hardware](https://img.shields.io/badge/Hardware-GTX%201650%20%7C%208GB%20RAM-76B900?style=flat-square&logo=nvidia)

*Cada container possui seu próprio README com documentação completa, scripts de ciclo de vida e exemplos práticos.*

</div>
