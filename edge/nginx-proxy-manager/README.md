# 🌐 NGINX Proxy Manager

<div align="center">

![Status](https://img.shields.io/badge/status-testado%20e%20funcional-brightgreen?style=for-the-badge&logo=checkmarx)
![Docker](https://img.shields.io/badge/Docker-2496ED?style=for-the-badge&logo=docker&logoColor=white)
![Nginx](https://img.shields.io/badge/nginx-%23009639.svg?style=for-the-badge&logo=nginx&logoColor=white)
![Version](https://img.shields.io/badge/versão-2.13.6-blue?style=for-the-badge)
![WSL2](https://img.shields.io/badge/WSL2-Otimizado-orange?style=for-the-badge&logo=windows)
![Let's Encrypt](https://img.shields.io/badge/Let's%20Encrypt-SSL%20Automático-003A70?style=for-the-badge)

**Reverse proxy com interface web intuitiva, certificados SSL automáticos via Let's Encrypt e gestão centralizada de tráfego — otimizado para WSL2 com hardware limitado.**

[📦 Docker Hub](https://hub.docker.com/r/jc21/nginx-proxy-manager) · [📖 Documentação Oficial](https://nginxproxymanager.com/) · [💬 Comunidade](https://github.com/NginxProxyManager/nginx-proxy-manager/discussions) · [🐛 Issues](https://github.com/NginxProxyManager/nginx-proxy-manager/issues)

</div>

---

## 📋 Índice

- [Características](#-características)
- [Arquitetura](#-arquitetura)
- [Requisitos](#-requisitos)
- [Instalação](#-instalação)
- [Configuração](#-configuração)
- [Uso](#-uso)
- [Scripts Disponíveis](#-scripts-disponíveis)
- [Backup e Restauração](#-backup-e-restauração)
- [Healthcheck](#-healthcheck)
- [Segurança](#-segurança)
- [Otimizações WSL2](#-otimizações-wsl2)
- [Exemplos Práticos](#-exemplos-práticos)
- [Casos de Uso Reais](#-casos-de-uso-reais)
- [Troubleshooting](#-troubleshooting)
- [Monitoramento](#-monitoramento)
- [Atualização](#-atualização)
- [FAQ](#-faq)
- [Referências](#-referências)

---

## ✨ Características

### Funcionalidades Principais

| Funcionalidade | Descrição |
|---|---|
| 🖥️ **Interface Web** | Painel admin completo na porta 81 |
| 🔒 **SSL Automático** | Certificados Let's Encrypt com renovação automática |
| 🔄 **Proxy Reverso** | Roteamento de domínios para containers internos |
| 🌐 **HTTP/2** | Suporte nativo para melhor performance |
| 🔌 **WebSockets** | Suporte completo para conexões WS/WSS |
| 📊 **Access Lists** | Controle de acesso por IP ou autenticação básica |
| 🔀 **Redirecionamentos** | Regras 301/302 gerenciadas pela interface |
| 🌊 **Streams TCP/UDP** | Proxy de protocolos além do HTTP |
| 📝 **Custom Locations** | Routing granular dentro de um mesmo domínio |
| 📦 **SQLite** | Banco leve sem dependências externas |

### Diferenciais desta Configuração

- ✅ **Testado e funcional** com healthcheck confirmado `healthy`
- ✅ **Otimizado para WSL2** com NVIDIA GTX 1650 / 8GB RAM
- ✅ **Dual backup** automático: SSD (velocidade) + HDD (segurança)
- ✅ **Scripts inteligentes** com validações, feedback visual e recovery
- ✅ **Porta admin segura** comentada por padrão (boas práticas)
- ✅ **Limites de recursos** ajustados para hardware homelab
- ✅ **IPv6 desabilitado** para compatibilidade plena com WSL2

---

## 🏗️ Arquitetura

### Diagrama de Funcionamento

```
                        INTERNET
                            │
                    ┌───────▼────────┐
                    │   Cloudflare   │  (opcional - Camada 1)
                    │   Tunnel/DNS   │
                    └───────┬────────┘
                            │ :80 / :443
                    ┌───────▼────────┐
                    │     NGINX      │
                    │  Proxy Manager │  ← Você está aqui
                    │  (este serviço)│
                    └───┬───┬───┬───┘
                        │   │   │
              ┌─────────┘   │   └─────────┐
              │             │             │
     ┌────────▼───┐  ┌──────▼─────┐  ┌───▼──────┐
     │    N8N     │  │  Open WebUI│  │ Portainer │
     │  :5678     │  │   :8080    │  │  :9443    │
     └────────────┘  └────────────┘  └──────────┘
              (Todos na mesma Docker Network)
```

### Estrutura de Volumes

```
edge/nginx-proxy-manager/
├── docker-compose.yml          # Configuração principal
├── .env                        # Symlink → ../../.env (global)
│
├── data/                       # 📁 Dados persistentes
│   ├── database.sqlite         # Banco de dados (configs, hosts, users)
│   ├── letsencrypt/            # Certificados SSL
│   │   ├── live/               # Certificados ativos
│   │   ├── renewal/            # Configurações de renovação
│   │   └── archive/            # Histórico de certificados
│   ├── nginx/                  # Configs geradas automaticamente
│   │   ├── proxy_host/         # Um arquivo por proxy host
│   │   ├── redirection_host/   # Redirecionamentos
│   │   └── stream/             # Streams TCP/UDP
│   └── logs/                   # Logs (excluídos do backup)
│
├── backups/                    # 💾 Backups locais (SSD)
│   └── backup_YYYYMMDD_HHMMSS.tar.gz
│
└── scripts/                    # 🔧 Scripts operacionais
    ├── start.sh
    ├── stop.sh
    ├── backup.sh
    └── restore.sh
```

### Fluxo de Rede

```
Request: https://app.meudominio.com
    │
    ├─ NPM verifica certificado SSL (/data/letsencrypt)
    ├─ Termina TLS (HTTPS → HTTP interno)
    ├─ Consulta banco SQLite para regra de proxy
    └─ Encaminha para container destino na rede Docker
```

---

## 📦 Requisitos

### Hardware Recomendado (Testado)

| Componente | Mínimo | Recomendado (Testado) |
|---|---|---|
| **RAM** | 128 MB | 256 MB (limite configurado) |
| **CPU** | 0.1 core | 0.5 core |
| **SSD** | 100 MB | 500 MB (incluindo backups) |
| **Portas** | 80, 443 | 80, 443 (+ 81 temporário) |

### Software

| Software | Versão Mínima | Verificação |
|---|---|---|
| **Docker Engine** | 24.0+ | `docker --version` |
| **Docker Compose** | v2.0+ | `docker compose version` |
| **WSL2** (Windows) | Kernel 5.10+ | `wsl --version` |
| **Ubuntu WSL** | 22.04+ | `lsb_release -a` |

### Verificação de Pré-requisitos

```bash
# Verificar Docker
docker --version
# Docker version 27.x.x, build ...

# Verificar Compose v2
docker compose version
# Docker Compose version v2.x.x

# Verificar portas disponíveis
sudo ss -tlnp | grep -E ':(80|443|81)\s'
# Nenhuma saída = portas livres ✅

# Verificar usuário e grupo (para WSL2)
id -u && id -g
# 1000
# 1000
```

---

## 🚀 Instalação

### Passo 1 — Clonar e configurar o repositório

```bash
# Clonar o projeto
git clone https://github.com/seu-usuario/docker-configuration.git
cd docker-configuration

# Criar o arquivo .env global a partir do template
cp .env.example .env

# Editar com seus valores
nano .env
```

**Variáveis mínimas obrigatórias no `.env`:**

```dotenv
# Rede
NETWORK_NAME=network_name
NETWORK_SUBNET=172.20.0.0/24
NETWORK_GATEWAY=172.20.0.1

# Regional
TIMEZONE=America/Sao_Paulo
PUID=1000
PGID=1000

# Armazenamento
SSD_PATH=/home/usuario/docker-configuration
HDD_PATH=/mnt/hdd/docker-configuration

# NPM
NPM_PORT=81
NPM_CONTAINER=nginx-proxy-manager
NPM_LIMITS_MEMORY=256M
NPM_LIMITS_CPUS=0.5
NPM_RESERVATIONS_MEMORY=128M
NPM_INTERVAL=60
NPM_TIMEOUT=10
NPM_RETRIES=3
NPM_START_PERIOD=30
```

### Passo 2 — Criar symlinks e networks

```bash
# Dar permissão de execução nos scripts globais
chmod +x scripts/setup-env-links.sh
chmod +x scripts/setup-networks.sh

# Criar symlinks do .env em cada serviço
./scripts/setup-env-links.sh

# Criar a Docker network
./scripts/setup-networks.sh
```

### Passo 3 — Preparar o serviço

```bash
# Navegar até o serviço
cd edge/nginx-proxy-manager

# Dar permissão de execução nos scripts
chmod +x scripts/*.sh

# (Primeiro uso) Descomentar a porta 81 para acesso inicial
nano docker-compose.yml
# Remover o comentário da linha:
# - "${NPM_PORT:-81}:81"
```

### Passo 4 — Iniciar

```bash
./scripts/start.sh
```

**Saída esperada no terminal:**

```
================================================
🚀 Iniciando NGINX Proxy Manager
================================================
📁 Verificando estrutura de diretórios...
🐳 Subindo container...
⏳ Aguardando inicialização... 30s restantes
⏳ Aguardando inicialização...  1s restantes
⏳ Healthcheck | Tentativa 1/3 ( 15%) | Status: starting
⏳ Healthcheck | Tentativa 1/3 ( 45%) | Status: starting
⏳ Healthcheck | Tentativa 1/3 ( 82%) | Status: healthy

✅ Container nginx-proxy-manager está saudável!

================================================
🌐 INFORMAÇÕES DE ACESSO
================================================
   Interface Admin: http://localhost:81
   HTTP:            http://localhost:80
   HTTPS:           https://localhost:443
================================================
🔑 CREDENCIAIS PADRÃO (primeiro acesso):
   Email: admin@example.com  |  Senha: changeme
⚠️  Altere imediatamente após o primeiro login!
================================================
```

### Passo 5 — Primeiro acesso e segurança

1. Abra `http://localhost:81`
2. Faça login com `admin@example.com` / `changeme`
3. Altere o email e defina uma senha forte
4. Após configurar, **comente novamente a porta 81** no `docker-compose.yml`:
   ```yaml
   # - "${NPM_PORT:-81}:81"
   ```
5. Reinicie o container:
   ```bash
   docker compose down && docker compose up -d
   ```

---

## ⚙️ Configuração

### Variáveis de Ambiente Completas

#### 🌐 Rede e Domínio

| Variável | Padrão | Descrição |
|---|---|---|
| `NETWORK_NAME` | `network_name` | Nome da Docker network externa |
| `NETWORK_SUBNET` | `172.20.0.0/24` | Sub-rede da network |
| `NETWORK_GATEWAY` | `172.20.0.1` | Gateway da network |
| `DOMAIN_NAME` | `localhost` | Domínio principal |

#### 🌍 Regional

| Variável | Padrão | Descrição |
|---|---|---|
| `TIMEZONE` | `America/Sao_Paulo` | Fuso horário do container |
| `PUID` | `1000` | User ID do processo (use `id -u`) |
| `PGID` | `1000` | Group ID do processo (use `id -g`) |

#### 🐳 NPM — Container

| Variável | Padrão | Descrição |
|---|---|---|
| `NPM_CONTAINER` | `nginx-proxy-manager` | Nome do container |
| `NPM_PORT` | `81` | Porta da interface admin |

#### 🎚️ NPM — Recursos

| Variável | Padrão | Descrição |
|---|---|---|
| `NPM_LIMITS_MEMORY` | `256M` | Limite máximo de RAM |
| `NPM_LIMITS_CPUS` | `0.5` | Limite de CPU (50% de 1 core) |
| `NPM_RESERVATIONS_MEMORY` | `128M` | RAM garantida para iniciar |

#### 🏥 NPM — Healthcheck

| Variável | Padrão | Descrição |
|---|---|---|
| `NPM_INTERVAL` | `60` | Segundos entre verificações |
| `NPM_TIMEOUT` | `10` | Segundos para timeout de cada check |
| `NPM_RETRIES` | `3` | Tentativas antes de `unhealthy` |
| `NPM_START_PERIOD` | `30` | Segundos de graça na inicialização |

#### 💾 Backup

| Variável | Padrão | Descrição |
|---|---|---|
| `SSD_PATH` | `/home/usuario/docker-configuration` | Caminho no SSD |
| `HDD_PATH` | `/mnt/hdd/docker-configuration` | Caminho no HDD para backup frio |
| `BACKUP_RETENTION_DAYS` | `7` | Dias de retenção no HDD |

---

## 🎯 Uso

### Adicionar Proxy Host

1. Acesse a interface web (porta 81 ou via proxy reverso)
2. Clique em **Proxy Hosts → Add Proxy Host**
3. Preencha a aba **Details**:

   | Campo | Exemplo | Descrição |
   |---|---|---|
   | Domain Names | `app.meudominio.com` | Domínio público |
   | Scheme | `http` | Protocolo interno |
   | Forward Hostname/IP | `n8n` | Nome do container |
   | Forward Port | `5678` | Porta interna |
   | Cache Assets | ✅ | Cache de estáticos |
   | Block Common Exploits | ✅ | Proteção básica |
   | Websockets Support | ✅ | Se o app usar WS |

4. Preencha a aba **SSL**:
   - Selecione **Request a new SSL Certificate**
   - Email: seu email real
   - ✅ Force SSL
   - ✅ HTTP/2 Support
   - ✅ HSTS Enabled (opcional, mas recomendado)

5. Clique em **Save**

### Adicionar Redirecionamento

1. **Hosts → Redirection Hosts → Add Redirection Host**
2. Exemplo `www` → `non-www`:
   - Domain: `www.meudominio.com`
   - Scheme: `https`
   - Forward Domain Name: `meudominio.com`
   - HTTP Code: `301`
   - ✅ Block Common Exploits

### Configurar Access List (Proteção por IP/Senha)

1. **Access Lists → Add Access List**
2. Defina regras:
   - **Allow**: IPs permitidos (ex: `192.168.0.0/24`)
   - **Deny**: IPs bloqueados
   - **Authorization**: Usuário/senha básicos
3. Associe ao proxy host em **Details → Access List**

### Expor Serviço via Stream (TCP/UDP)

1. **Hosts → Streams → Add Stream**
2. Configure:
   - Incoming Port: porta pública
   - Forwarding Host: IP ou container
   - Forwarding Port: porta interna
   - TCP/UDP conforme necessário

---

## 🔧 Scripts Disponíveis

### `start.sh` — Iniciar o serviço

```bash
bash scripts/start.sh
```

**O que faz:**
1. Verifica existência do `.env`
2. Carrega todas as variáveis
3. Verifica se a Docker network existe (cria automaticamente se não existir)
4. Cria estrutura de diretórios (`data/`, `backups/`, `scripts/`, `data/letsencrypt/`)
5. Sobe o container com `docker compose up -d`
6. Aguarda o `start_period` configurado
7. Monitora o healthcheck em tempo real com barra de progresso
8. Exibe informações de acesso ao confirmar `healthy`

**Saída de sucesso:**
```
✅ Container nginx-proxy-manager está saudável!

================================================
🌐 INFORMAÇÕES DE ACESSO
================================================
   Interface Admin: http://localhost:81
   HTTP:            http://localhost:80
   HTTPS:           https://localhost:443
================================================
```

**Saída de erro (container unhealthy):**
```
❌ Container nginx-proxy-manager não está saudável!
📋 Últimos logs:
[logs do container aqui...]
```

---

### `stop.sh` — Parar o serviço

```bash
bash scripts/stop.sh
```

**O que faz:**
1. Verifica se o container está rodando
2. Pergunta se deseja fazer backup antes de parar
3. Para o container com `docker compose down`
4. Se houver volumes, pergunta se deseja removê-los
5. Exige confirmação digitando `CONFIRMO` para remoção permanente

**Saída esperada:**
```
================================================
🛑 Parando NGINX Proxy Manager
================================================
💾 Deseja fazer backup antes de parar? (S/n): s
📦 Executando backup...
✅ Backup criado (SSD)
🛑 Parando container nginx-proxy-manager...
✅ Container nginx-proxy-manager parado com sucesso!
================================================
💡 Para iniciar novamente: bash scripts/start.sh
================================================
```

> ⚠️ **Atenção:** Para remover volumes você deve digitar `CONFIRMO` (com exatidão). Isso apaga permanentemente todos os dados, certificados e configurações.

---

### `backup.sh` — Realizar backup

```bash
bash scripts/backup.sh
```

**O que faz:**
1. Carrega variáveis do `.env`
2. Verifica se o diretório `data/` existe
3. Informa se o container está rodando (backup a quente) ou parado (backup a frio)
4. Cria arquivo compactado `.tar.gz` excluindo logs e temporários
5. Copia para o HDD se `HDD_PATH` estiver configurado
6. Remove backups antigos no HDD (respeita `BACKUP_RETENTION_DAYS`)
7. Mantém apenas os 5 backups mais recentes no SSD

**Saída esperada:**
```
================================================
💾 Iniciando Backup - NGINX Proxy Manager
================================================
⚠️  Container nginx-proxy-manager está rodando — backup a quente
📦 Compactando dados...
✅ Backup criado (SSD)
   /home/usuario/docker-configuration/edge/nginx-proxy-manager/backups/backup_20250227_143022.tar.gz (4.2M)
📤 Copiando para HDD...
✅ Backup copiado para HDD
   /mnt/hdd/docker-configuration/backups/nginx-proxy-manager/backup_20250227_143022.tar.gz (4.2M)
🧹 Limpando backups antigos no HDD (>7 dias)...
🧹 Limpando backups antigos no SSD (mantendo últimos 5)...
================================================
📋 Backups disponíveis (SSD):
-rw-r--r-- 1 user user 4.2M Feb 27 14:30 backup_20250227_143022.tar.gz
================================================
🎉 Backup concluído com sucesso!
================================================
```

**Arquivos excluídos do backup (para economizar espaço):**
- `data/logs/` — logs rotativos
- `data/nginx/temp/` — cache temporário do nginx
- Qualquer arquivo `*.log` ou `*.tmp`

---

### `restore.sh` — Restaurar backup

```bash
bash scripts/restore.sh
```

**O que faz:**
1. Lista todos os backups disponíveis para seleção interativa
2. Exibe detalhes do backup selecionado (nome, tamanho, data)
3. Solicita confirmação antes de prosseguir
4. Para o container se estiver rodando
5. Cria backup de segurança dos dados atuais (antes de sobrescrever)
6. Remove dados antigos
7. Extrai o backup selecionado
8. Ajusta permissões para compatibilidade com WSL2
9. Reinicia o container

**Saída esperada:**
```
================================================
♻️  Restauração - NGINX Proxy Manager
================================================
📋 Backups disponíveis:

1) backup_20250227_143022.tar.gz
2) backup_20250226_020001.tar.gz
3) backup_20250225_020001.tar.gz
#? 1

📦 Backup selecionado:
   Arquivo: backup_20250227_143022.tar.gz
   Tamanho: 4.2M
   Data:    2025-02-27 14:30:22

⚠️  ATENÇÃO: Esta operação irá:
   • SOBRESCREVER todos os dados atuais do NPM
   • Apagar configurações existentes
   • Substituir certificados SSL atuais

⚠️  Deseja continuar? (s/N): s
🛑 Parando container nginx-proxy-manager...
🔒 Criando backup de segurança dos dados atuais...
✅ Backup de segurança: nginx-proxy-manager_pre_restore_20250227_150000.tar.gz (4.1M)
🗑️  Removendo dados antigos...
📥 Extraindo backup...
🔧 Ajustando permissões...
================================================
🚀 Iniciando NGINX Proxy Manager
================================================
📁 Verificando estrutura de diretórios...
🐳 Subindo container...
⏳ Aguardando inicialização... 30s restantes
⏳ Healthcheck | Tentativa 1/3 ( 82%) | Status: healthy

✅ Container nginx-proxy-manager está saudável!
================================================
🎉 Dados restaurados com sucesso!
================================================
```

---

## 💾 Backup e Restauração

### Estratégia Dual SSD + HDD

```
Backup a quente (container rodando):
  data/ → tar.gz → SSD (backups/)
                 → HDD (backups/nginx-proxy-manager/)

Retenção SSD: últimos 5 arquivos
Retenção HDD: últimos N dias (BACKUP_RETENTION_DAYS=7)
```

### Backup Automático via Cron

```bash
# Editar crontab
crontab -e

# Backup diário às 02:00
0 2 * * * /caminho/completo/docker-configuration/edge/nginx-proxy-manager/scripts/backup.sh >> /var/log/npm-backup.log 2>&1

# Backup semanal às 03:00 de domingo
0 3 * * 0 /caminho/completo/docker-configuration/edge/nginx-proxy-manager/scripts/backup.sh
```

### O que o backup contém

| Item | Incluído | Motivo |
|---|---|---|
| `database.sqlite` | ✅ | Hosts, usuários, configurações |
| Certificados SSL | ✅ | Let's Encrypt (evita rate limit) |
| Configs nginx | ✅ | Regras de proxy geradas |
| Chaves JWT | ✅ | Autenticação da interface |
| `data/logs/` | ❌ | Volátil, recriado automaticamente |
| `data/nginx/temp/` | ❌ | Cache temporário |

### Copiar backup do HDD para SSD (antes de restore)

```bash
# Listar backups no HDD
ls -lth /mnt/hdd/docker-configuration/backups/nginx-proxy-manager/

# Copiar para pasta local
cp /mnt/hdd/docker-configuration/backups/nginx-proxy-manager/backup_YYYYMMDD_HHMMSS.tar.gz \
   ./backups/

# Executar restore
bash scripts/restore.sh
```

---

## 🏥 Healthcheck

### Como funciona

O healthcheck verifica periodicamente se a API interna do NPM está respondendo:

```yaml
healthcheck:
  test: ["CMD", "wget", "--quiet", "--tries=1", "--spider", "http://localhost:81/api/schema"]
  interval: 60s       # Verificação a cada 60 segundos
  timeout: 10s        # Timeout de cada verificação
  retries: 3          # 3 falhas consecutivas = unhealthy
  start_period: 30s   # 30s de graça para o container inicializar
```

### Estados possíveis

| Estado | Significado | Ação |
|---|---|---|
| `starting` | Container iniciando (dentro do `start_period`) | Aguardar |
| `healthy` | API respondendo corretamente | ✅ Tudo certo |
| `unhealthy` | API falhou 3 vezes consecutivas | Verificar logs |
| `none` | Healthcheck não configurado | — |

### Verificar status manualmente

```bash
# Status atual
docker inspect nginx-proxy-manager --format='{{.State.Health.Status}}'

# Histórico de checks (últimos 5)
docker inspect nginx-proxy-manager --format='{{json .State.Health}}' | jq '.Log[-5:]'

# Monitorar em tempo real
watch -n 5 "docker inspect nginx-proxy-manager --format='{{.State.Health.Status}}'"
```

### Por que `wget` e não `curl`?

A imagem base do NPM usa Alpine Linux. O `wget` é incluído por padrão no Alpine, enquanto `curl` pode não estar presente em todas as versões. Usar `wget` garante que o healthcheck funcione independente da versão da imagem.

---

## 🔒 Segurança

### Camadas de proteção implementadas

#### 1. Porta Admin Comentada

A porta 81 (interface de administração) vem **comentada por padrão** no `docker-compose.yml`:

```yaml
# - "${NPM_PORT:-81}:81"  ← descomente APENAS para setup inicial
```

Após a configuração, o acesso ao painel deve ser feito via proxy reverso com SSL:
- Crie um proxy host: `npm.seudominio.com` → `nginx-proxy-manager:81`
- Ative SSL + Force HTTPS
- A porta 81 nunca fica exposta publicamente

#### 2. Confirmação Dupla para Ações Destrutivas

Ao parar o serviço, o `stop.sh` exige:
1. Confirmação de backup (`S/n`)
2. Para remoção de volumes: digitar literalmente `CONFIRMO`

#### 3. Backup de Segurança Pré-Restore

Antes de qualquer restauração, o `restore.sh` cria automaticamente um backup dos dados atuais com timestamp, evitando perda irreversível de dados.

#### 4. Limites de Recursos

```yaml
mem_limit: 256M          # Evita que NPM consuma RAM de outros serviços
memswap_limit: 256M      # Desabilita swap (protege SSD)
cpus: 0.5                # Máximo 50% de 1 core
```

#### 5. Boas práticas adicionais recomendadas

```bash
# Habilitar fail2ban para proteção contra brute force
# (integração com CrowdSec na Camada 2)

# Usar Access Lists no NPM para restringir acesso a serviços internos
# Admin panels devem ter IP whitelist

# Habilitar HSTS nos proxy hosts em produção
# Strict-Transport-Security: max-age=31536000; includeSubDomains

# Usar senhas geradas aleatoriamente
openssl rand -base64 32
```

---

## 🪟 Otimizações WSL2

### Arquivo `.wslconfig` recomendado

Localização: `C:\Users\SeuUsuario\.wslconfig`

```ini
[wsl2]
memory=5GB              # 5 de 8GB — deixa 3GB para Windows
processors=3            # 3 de 4 cores — mantém Windows responsivo
swap=2GB                # Buffer para picos de memória
pageReporting=true      # Libera RAM não usada para Windows

[experimental]
autoMemoryReclaim=gradual   # Recuperação gradual de RAM
networkingMode=mirrored     # Melhor integração de rede com Windows
```

> **Por que 5GB e não 6GB?** Com 6GB para WSL2, o Windows fica com apenas 2GB — insuficiente para SO + Chrome + VSCode. Com 5GB, ambos os lados ficam confortáveis.

### Aplicar configurações WSL2

```powershell
# PowerShell como Administrador
wsl --shutdown

# Aguardar 8-10 segundos e reiniciar WSL
wsl

# Verificar dentro do WSL
free -h       # Deve mostrar ~5GB total
nproc         # Deve mostrar 3
```

### Por que `DISABLE_IPV6=true`?

No WSL2, o IPv6 pode causar problemas de roteamento entre containers e o host Windows. Desabilitar garante que o NPM use apenas IPv4, evitando erros de binding e problemas com Let's Encrypt.

### Por que `PUID/PGID=1000`?

No WSL2, o usuário padrão é o UID/GID 1000. Mapear o container para o mesmo usuário evita problemas de permissão nos volumes montados. Confirme com:

```bash
id -u  # deve retornar 1000
id -g  # deve retornar 1000
```

---

## 💻 Exemplos Práticos

### Configuração dos serviços para funcionar com NPM

Todos os serviços que serão roteados pelo NPM devem:
1. Estar na mesma Docker network
2. **Não** expor portas publicamente (`ports:`)
3. Usar `expose:` para documentar a porta interna

```yaml
# ❌ Errado — expõe porta diretamente
services:
  meu-app:
    ports:
      - "8080:8080"

# ✅ Correto — roteado pelo NPM
services:
  meu-app:
    expose:
      - "8080"
    networks:
      - network

networks:
  network:
    external: true
    name: ${NETWORK_NAME}
```

### JavaScript / Node.js

Verificando se o serviço está acessível pelo proxy:

```javascript
// check-proxy.js
const https = require('https');

const options = {
  hostname: 'app.meudominio.com',
  port: 443,
  path: '/health',
  method: 'GET',
};

const req = https.request(options, (res) => {
  console.log(`Status: ${res.statusCode}`);
  console.log(`SSL: ${res.socket.authorized ? '✅ Válido' : '❌ Inválido'}`);
  console.log(`Protocolo: ${res.httpVersion}`);
});

req.on('error', (e) => {
  console.error(`Erro: ${e.message}`);
});

req.end();
```

Consumindo uma API atrás do proxy com headers corretos:

```javascript
// api-client.js
const axios = require('axios');

const client = axios.create({
  baseURL: 'https://api.meudominio.com',
  timeout: 5000,
  headers: {
    'X-Forwarded-Proto': 'https',  // NPM injeta automaticamente
    'Content-Type': 'application/json',
  },
});

// O NPM injeta automaticamente:
// X-Real-IP: IP real do cliente
// X-Forwarded-For: cadeia de IPs
// X-Forwarded-Proto: https

async function fetchData() {
  try {
    const response = await client.get('/users');
    console.log(response.data);
  } catch (error) {
    console.error('Erro:', error.response?.status, error.message);
  }
}

fetchData();
```

WebSocket através do NPM (com Websockets Support ativado):

```javascript
// ws-client.js
const WebSocket = require('ws');

// NPM roteia WSS → WS interno automaticamente
const ws = new WebSocket('wss://chat.meudominio.com/ws');

ws.on('open', () => {
  console.log('Conectado via NPM proxy ✅');
  ws.send(JSON.stringify({ type: 'ping' }));
});

ws.on('message', (data) => {
  console.log('Recebido:', data.toString());
});

ws.on('error', (err) => {
  console.error('Erro WS:', err.message);
});
```

### Python

Verificando certificado SSL e headers do proxy:

```python
# check_proxy.py
import requests
import ssl
import socket

def check_proxy(url: str):
    """Verifica se o proxy está funcionando corretamente."""
    try:
        response = requests.get(url, timeout=5)
        
        print(f"✅ Status: {response.status_code}")
        print(f"🔒 SSL: {'Válido' if response.url.startswith('https') else 'HTTP'}")
        print(f"⚡ HTTP/2: {response.raw.version == 20}")
        
        # Headers injetados pelo NPM
        forwarded_for = response.request.headers.get('X-Forwarded-For', 'N/A')
        print(f"🌐 X-Forwarded-For: {forwarded_for}")
        
        return response.status_code == 200
    except requests.exceptions.SSLError as e:
        print(f"❌ Erro SSL: {e}")
        return False
    except requests.exceptions.ConnectionError as e:
        print(f"❌ Erro de conexão: {e}")
        return False

if __name__ == "__main__":
    check_proxy("https://app.meudominio.com/health")
```

Flask atrás do NPM (capturando IP real):

```python
# app.py
from flask import Flask, request, jsonify

app = Flask(__name__)

# Configurar Flask para confiar nos headers do proxy
from werkzeug.middleware.proxy_fix import ProxyFix
app.wsgi_app = ProxyFix(
    app.wsgi_app,
    x_for=1,    # X-Forwarded-For
    x_proto=1,  # X-Forwarded-Proto
    x_host=1,   # X-Forwarded-Host
)

@app.route('/info')
def info():
    return jsonify({
        'ip_real': request.remote_addr,          # IP real (via NPM)
        'ip_forwarded': request.headers.get('X-Forwarded-For'),
        'protocolo': request.headers.get('X-Forwarded-Proto'),
        'host': request.headers.get('X-Forwarded-Host'),
        'https': request.is_secure,
    })

if __name__ == '__main__':
    # Nunca expõe diretamente — o NPM faz o roteamento
    app.run(host='0.0.0.0', port=5000)
```

### PHP

WordPress / Laravel atrás do proxy:

```php
<?php
// config/proxy.php

/**
 * Detectar IP real do usuário quando atrás do NPM
 * O NPM injeta X-Real-IP e X-Forwarded-For automaticamente
 */
function getClientIP(): string
{
    $headers = [
        'HTTP_X_REAL_IP',
        'HTTP_X_FORWARDED_FOR',
        'HTTP_CLIENT_IP',
        'REMOTE_ADDR',
    ];

    foreach ($headers as $header) {
        if (!empty($_SERVER[$header])) {
            $ip = trim(explode(',', $_SERVER[$header])[0]);
            if (filter_var($ip, FILTER_VALIDATE_IP)) {
                return $ip;
            }
        }
    }

    return $_SERVER['REMOTE_ADDR'] ?? '0.0.0.0';
}

/**
 * Verificar se a requisição chegou via HTTPS pelo NPM
 */
function isHTTPS(): bool
{
    return (
        (!empty($_SERVER['HTTPS']) && $_SERVER['HTTPS'] !== 'off') ||
        ($_SERVER['HTTP_X_FORWARDED_PROTO'] ?? '') === 'https' ||
        ($_SERVER['SERVER_PORT'] ?? 0) == 443
    );
}

// Uso
echo "IP: " . getClientIP() . PHP_EOL;
echo "HTTPS: " . (isHTTPS() ? 'Sim ✅' : 'Não ❌') . PHP_EOL;
```

Laravel — configurar `TrustedProxies`:

```php
<?php
// app/Http/Middleware/TrustProxies.php

namespace App\Http\Middleware;

use Illuminate\Http\Middleware\TrustProxies as Middleware;
use Illuminate\Http\Request;

class TrustProxies extends Middleware
{
    // Confiar em todos os proxies na mesma rede Docker
    // Substitua pelo IP/subnet da sua Docker network
    protected $proxies = [
        '172.20.0.0/24',  // sua NETWORK_SUBNET
    ];

    protected $headers =
        Request::HEADER_X_FORWARDED_FOR |
        Request::HEADER_X_FORWARDED_HOST |
        Request::HEADER_X_FORWARDED_PORT |
        Request::HEADER_X_FORWARDED_PROTO |
        Request::HEADER_X_FORWARDED_AWS_ELB;
}
```

---

## 🎯 Casos de Uso Reais

### Caso 1: Homelab com múltiplos serviços

```
meudominio.com
├── n8n.meudominio.com          → n8n:5678
├── portainer.meudominio.com    → portainer:9443
├── app.meudominio.com          → meuapp:3000
├── api.meudominio.com          → backend:8080
├── grafana.meudominio.com      → grafana:3000
└── npm.meudominio.com          → nginx-proxy-manager:81
```

Benefício: Um único certificado wildcard ou certificados individuais por subdomínio — tudo gerenciado pela interface sem editar arquivos de configuração.

### Caso 2: Exposição segura com Cloudflare Tunnel

```
Internet → Cloudflare Tunnel → NPM → Serviços internos
```

Nenhuma porta precisa estar aberta no roteador. O Cloudflare Tunnel conecta ao NPM internamente, que distribui para os serviços.

### Caso 3: Ambiente de desenvolvimento local

```
/etc/hosts:
127.0.0.1  app.local
127.0.0.1  api.local
127.0.0.1  admin.local
```

Configurar no NPM com certificados self-signed para simular produção localmente.

### Caso 4: Migração de serviços sem downtime

```
Antes: api.meudominio.com → backend-v1:8080
Após:  api.meudominio.com → backend-v2:8080
```

A troca é feita na interface do NPM em segundos, sem alterar DNS ou reconfigurar clients.

---

## 🔍 Troubleshooting

### ❌ Container não inicia

**Sintoma:** `start.sh` falha ou container não aparece em `docker ps`

```bash
# 1. Ver logs detalhados
docker compose logs --tail=100

# 2. Verificar se portas estão em uso
sudo ss -tlnp | grep -E ':(80|443)\s'

# 3. Verificar permissões do diretório data/
ls -la data/

# 4. Forçar recriação
docker compose down --remove-orphans
docker compose up -d --force-recreate

# 5. Verificar .env
cat .env | grep -E 'NETWORK|NPM|PUID|PGID'
```

---

### ❌ Porta 81 não acessível

**Sintoma:** `http://localhost:81` retorna "connection refused"

```bash
# 1. Confirmar que a linha está descomentada no docker-compose.yml
grep "81:81" docker-compose.yml

# 2. Verificar se container está rodando
docker ps | grep nginx-proxy-manager

# 3. Verificar mapeamento de porta
docker port nginx-proxy-manager

# 4. Reiniciar após descomentar a porta
docker compose down && docker compose up -d
```

---

### ❌ Certificado SSL não emitido

**Sintoma:** Erro ao solicitar certificado Let's Encrypt

```bash
# 1. Verificar se porta 80 está acessível externamente
# (necessário para o desafio HTTP-01 do Let's Encrypt)
curl -I http://seudominio.com

# 2. Verificar se DNS aponta para o IP correto
nslookup seudominio.com

# 3. Ver logs específicos do Let's Encrypt
docker compose logs | grep -i "letsencrypt\|certbot\|acme"

# 4. Rate limit: máximo 5 certificados por domínio/semana
# Use o ambiente de staging para testes:
# Nas configurações avançadas do NPM, adicionar:
# --staging (apenas para testes, remove a flag em produção)
```

---

### ❌ Erro 502 Bad Gateway

**Sintoma:** NPM retorna 502 ao acessar o serviço

```bash
# 1. Verificar se o container destino está rodando
docker ps | grep nome-do-container

# 2. Verificar se está na mesma rede
docker network inspect ${NETWORK_NAME} | grep -A5 "Containers"

# 3. Testar conectividade interna
docker exec nginx-proxy-manager wget -q --spider http://nome-do-container:porta
# Se falhar: container não está na mesma rede ou porta errada

# 4. Verificar nome do container no NPM
# Forward Hostname deve ser exatamente o container_name
docker ps --format "{{.Names}}"
```

---

### ❌ Alto uso de memória

**Sintoma:** Container consumindo mais de 256MB

```bash
# Verificar uso real
docker stats nginx-proxy-manager --no-stream

# Se consistentemente acima de 200MB, aumentar o limite no .env:
NPM_LIMITS_MEMORY=512M
NPM_RESERVATIONS_MEMORY=256M

# Aplicar
docker compose down && docker compose up -d
```

---

### ❌ Erro de permissões (WSL2)

**Sintoma:** `Permission denied` ao iniciar ou nos logs

```bash
# Verificar PUID/PGID
id -u   # deve retornar 1000
id -g   # deve retornar 1000

# Corrigir permissões do diretório data/
sudo chown -R 1000:1000 ./data

# Verificar variáveis no .env
grep "PUID\|PGID" .env
```

---

### ❌ Network não encontrada

**Sintoma:** `Error: network not found` ao subir o container

```bash
# Verificar se a network existe
docker network ls | grep ${NETWORK_NAME}

# Criar manualmente se necessário
docker network create \
  --driver bridge \
  --subnet 172.20.0.0/24 \
  --gateway 172.20.0.1 \
  ${NETWORK_NAME}

# Ou usar o script global
bash ../../scripts/setup-networks.sh
```

---

### ❌ Symlink .env quebrado

**Sintoma:** Variáveis não carregam, erros de `NETWORK_NAME` vazio

```bash
# Verificar status do symlink
ls -la .env

# Se aparecer em vermelho (broken link):
rm .env
ln -s ../../.env .env

# Verificar se o .env global existe
ls -la ../../.env

# Recriar todos os symlinks
bash ../../scripts/setup-env-links.sh
```

---

### ❌ Healthcheck sempre `starting` ou `unhealthy`

**Sintoma:** Container sobe mas nunca fica `healthy`

```bash
# 1. Testar o comando de healthcheck manualmente
docker exec nginx-proxy-manager wget --quiet --tries=1 --spider http://localhost:81/api/schema
echo "Exit code: $?"
# 0 = sucesso, qualquer outro = falha

# 2. Aumentar start_period se servidor for lento
# No .env:
NPM_START_PERIOD=60

# 3. Ver histórico detalhado
docker inspect nginx-proxy-manager | jq '.[0].State.Health'

# 4. Verificar se a API está respondendo internamente
docker exec nginx-proxy-manager wget -qO- http://localhost:81/api/schema | head -50
```

---

### ❌ Logs de acesso muito grandes

**Sintoma:** Uso excessivo de disco em `data/logs/`

```bash
# Verificar tamanho atual
du -sh data/logs/

# Os logs do container já têm rotação configurada (10MB × 3 arquivos)
# Para os logs internos do nginx dentro do NPM:
docker exec nginx-proxy-manager find /data/logs -name "*.log" -size +10M

# Truncar log específico (sem parar o container)
docker exec nginx-proxy-manager truncate -s 0 /data/logs/proxy-host-1_access.log
```

---

## 📊 Monitoramento

### Comandos essenciais

```bash
# Status geral
docker ps -f name=nginx-proxy-manager

# Uso de recursos em tempo real
docker stats nginx-proxy-manager

# Uso de recursos (snapshot único)
docker stats nginx-proxy-manager --no-stream --format \
  "CPU: {{.CPUPerc}} | RAM: {{.MemUsage}} | NET: {{.NetIO}}"

# Logs em tempo real
docker compose logs -f

# Logs das últimas 2 horas
docker compose logs --since 2h

# Logs com filtro de erro
docker compose logs | grep -i "error\|warn\|crit"
```

### Métricas de saúde

```bash
# Script de monitoramento rápido
cat <<'EOF' > /tmp/npm-monitor.sh
#!/bin/bash
CONTAINER="nginx-proxy-manager"
STATUS=$(docker inspect --format='{{.State.Health.Status}}' $CONTAINER 2>/dev/null || echo "stopped")
MEM=$(docker stats $CONTAINER --no-stream --format "{{.MemPerc}}" 2>/dev/null || echo "N/A")
CPU=$(docker stats $CONTAINER --no-stream --format "{{.CPUPerc}}" 2>/dev/null || echo "N/A")
UPTIME=$(docker inspect --format='{{.State.StartedAt}}' $CONTAINER 2>/dev/null | cut -dT -f1)

echo "📊 NPM Status Report — $(date '+%Y-%m-%d %H:%M:%S')"
echo "   Health:  $STATUS"
echo "   Memory:  $MEM"
echo "   CPU:     $CPU"
echo "   Started: $UPTIME"
EOF
chmod +x /tmp/npm-monitor.sh
bash /tmp/npm-monitor.sh
```

### Integração com Prometheus + cAdvisor

O cAdvisor (Camada 9 — Observabilidade) coleta métricas de todos os containers automaticamente. Para visualizar no Grafana:

```bash
# cAdvisor expõe métricas em /metrics
# Configurar no prometheus.yml:

scrape_configs:
  - job_name: 'cadvisor'
    scrape_interval: 30s
    static_configs:
      - targets: ['cadvisor:8080']

# Métricas disponíveis para o NPM:
# container_memory_usage_bytes{name="nginx-proxy-manager"}
# container_cpu_usage_seconds_total{name="nginx-proxy-manager"}
# container_network_receive_bytes_total{name="nginx-proxy-manager"}
# container_network_transmit_bytes_total{name="nginx-proxy-manager"}
```

Dashboard recomendado no Grafana: **ID 14282** (Docker container & host metrics)

### Alertas simples via shell

```bash
# Adicionar ao crontab para alertas por email:
*/5 * * * * docker inspect nginx-proxy-manager --format='{{.State.Health.Status}}' | grep -v healthy && echo "NPM UNHEALTHY" | mail -s "Alerta Docker" seu@email.com
```

---

## 🔄 Atualização

### Processo seguro com rollback

```bash
# 1. Fazer backup antes de atualizar
bash scripts/backup.sh

# 2. Verificar versão atual
docker exec nginx-proxy-manager cat /app/package.json | grep '"version"'

# 3. Baixar nova imagem
docker compose pull

# 4. Aplicar atualização
docker compose down
docker compose up -d

# 5. Verificar se ficou healthy
watch -n 3 "docker inspect nginx-proxy-manager --format='{{.State.Health.Status}}'"

# 6. Se houver problema, restaurar versão anterior
docker compose down
docker run -d --name npm-rollback jc21/nginx-proxy-manager:2.12.3  # versão anterior conhecida
# Ou restaurar backup:
bash scripts/restore.sh
```

### Verificar mudanças antes de atualizar

```bash
# Ver releases disponíveis
curl -s https://api.github.com/repos/NginxProxyManager/nginx-proxy-manager/releases/latest \
  | grep '"tag_name"'
```

---

## ❓ FAQ

**P: Por que a porta 81 vem comentada por padrão?**

R: Segurança. A porta 81 dá acesso total ao painel admin sem autenticação de dois fatores. Mantê-la aberta na internet é um vetor de ataque. Após o setup inicial, o acesso deve ser exclusivamente via proxy reverso com HTTPS — o próprio NPM faz isso criando um proxy host apontando para si mesmo (`npm.seudominio.com → nginx-proxy-manager:81`).

---

**P: Posso usar MariaDB em vez de SQLite?**

R: Sim, mas não é recomendado para esta configuração. O SQLite economiza ~200-300MB de RAM e elimina a necessidade de um container adicional. Para um homelab com hardware limitado (8GB RAM), cada MB importa. O SQLite suporta centenas de proxy hosts sem degradação de performance.

---

**P: O que acontece se o container reiniciar enquanto há tráfego?**

R: O `stop_grace_period: 15s` garante que o nginx aguarde até 15 segundos para conexões ativas finalizarem antes de forçar a parada. Com `restart: unless-stopped`, o container reinicia automaticamente em caso de falha.

---

**P: Por que usar `memswap_limit` igual ao `mem_limit`?**

R: Quando `memswap_limit == mem_limit`, o Docker desabilita completamente o swap para o container. Isso protege o SSD de writes excessivos e garante que o container falhe de forma previsível (OOM kill) em vez de degradar silenciosamente.

---

**P: O Let's Encrypt tem limite de certificados?**

R: Sim. O limite principal é 5 certificados **novos** por domínio registrado por semana. **Renovações não contam** para este limite. Para testes, use a opção de staging — e somente em produção solicite certificados reais.

---

**P: Como acessar o NPM de fora da rede local sem abrir a porta 81?**

R: Use o Cloudflare Tunnel (Camada 1) ou uma VPN. Com o Cloudflare Tunnel, o container se conecta ao Cloudflare via outbound — nenhuma porta precisa estar aberta no roteador.

---

**P: Os backups funcionam com o container rodando?**

R: Sim. O `backup.sh` realiza backup a quente (hot backup). O SQLite suporta leitura simultânea, então o backup é consistente mesmo com o NPM em operação. Para ambientes críticos, pode-se parar o container antes (`stop.sh`) e usar backup a frio.

---

**P: Como verificar qual versão do NPM está rodando?**

```bash
docker exec nginx-proxy-manager cat /app/package.json | grep '"version"'
# ou
docker inspect jc21/nginx-proxy-manager:latest --format='{{index .Config.Labels "org.opencontainers.image.version"}}'
```

---

**P: Posso ter múltiplos NPM rodando?**

R: Não é recomendado. Um NPM por ambiente é suficiente e mais simples de gerenciar. Se precisar isolamento, use access lists e hosts separados dentro do mesmo NPM.

---

**P: Como desabilitar o log de acesso para um host específico?**

R: Na aba **Details** do proxy host, clique em **Advanced** e adicione:
```nginx
access_log off;
```

---

## 📚 Referências

### Documentação Oficial

| Recurso | Link |
|---|---|
| Site Oficial | [nginxproxymanager.com](https://nginxproxymanager.com/) |
| Setup Completo | [nginxproxymanager.com/setup](https://nginxproxymanager.com/setup/) |
| Configuração Avançada | [nginxproxymanager.com/advanced-config](https://nginxproxymanager.com/advanced-config/) |
| GitHub | [github.com/NginxProxyManager/nginx-proxy-manager](https://github.com/NginxProxyManager/nginx-proxy-manager) |
| Docker Hub | [hub.docker.com/r/jc21/nginx-proxy-manager](https://hub.docker.com/r/jc21/nginx-proxy-manager) |
| Discussões | [github.com/NginxProxyManager/nginx-proxy-manager/discussions](https://github.com/NginxProxyManager/nginx-proxy-manager/discussions) |

### Versões

| Tag | Descrição |
|---|---|
| `latest` | Sempre a versão mais recente (recomendado) |
| `2` | Série 2.x mais recente |
| `2.13.6` | Versão específica (pin para produção) |

### Relacionados

| Ferramenta | Propósito |
|---|---|
| [Certbot](https://certbot.eff.org/) | Cliente Let's Encrypt standalone |
| [Traefik](https://traefik.io/) | Alternativa ao NPM (mais complexo) |
| [Caddy](https://caddyserver.com/) | Alternativa com auto-SSL por config |
| [CrowdSec](https://www.crowdsec.net/) | IPS integrado com NPM (Camada 2) |
| [Authelia](https://www.authelia.com/) | SSO/2FA para serviços (Camada 2) |

---

<div align="center">

**Parte do projeto [docker-configuration](../) — Homelab Stack para pequenas startups**

![Camada](https://img.shields.io/badge/Camada-1%20Edge%20%2F%20Entrada-4A90D9?style=flat-square)
![Testado](https://img.shields.io/badge/Testado-WSL2%20Ubuntu%2024-success?style=flat-square&logo=ubuntu)
![Hardware](https://img.shields.io/badge/Hardware-NVIDIA%20GTX%201650%20%7C%208GB%20RAM-76B900?style=flat-square&logo=nvidia)

</div>
