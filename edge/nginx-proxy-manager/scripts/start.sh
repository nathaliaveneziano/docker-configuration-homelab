#!/bin/bash
# ==========================================
# 🚀 START - NGINX Proxy Manager
# ==========================================

set -e

# Cores para output
BLUE='\033[0;34m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

# Detectar diretórios
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BASE_DIR="$(dirname "$SCRIPT_DIR")"
ROOT_DIR="$(dirname "$(dirname "$BASE_DIR")")"

echo -e "${BLUE}================================================${NC}"
echo -e "${BLUE}🚀 Iniciando NGINX Proxy Manager${NC}"
echo -e "${BLUE}================================================${NC}"

# ==========================================
# VERIFICAR SE .ENV EXISTE
# ==========================================
ROOT_ENV="$BASE_DIR/.env"
if [ ! -f "$ROOT_ENV" ] && [ ! -L "$ROOT_ENV" ]; then
    echo -e "${RED}❌ Arquivo .env não encontrado em: $ROOT_DIR${NC}"
    echo -e "${YELLOW}   Copie o template: cp .env.example .env${NC}"
    echo -e "${YELLOW}   Execute o setup de symlinks: bash scripts/setup-env-links.sh${NC}"
    exit 1
fi

# Carregar variáveis do .env
set -a
source "$ROOT_ENV"
set +a

# Obter nome do container (com fallback)
CONTAINER="${NPM_CONTAINER:-nginx-proxy-manager}"

# ==========================================
# VERIFICAR SE A NETWORK EXISTE
# ==========================================
if [ -z "$NETWORK_NAME" ]; then
    echo -e "${RED}❌ Variável NETWORK_NAME não definida no .env${NC}"
    exit 1
fi

if ! docker network inspect "$NETWORK_NAME" &>/dev/null; then
    echo -e "${YELLOW}⚠️ Network '$NETWORK_NAME' não encontrada — criando...${NC}"
    SETUP_NETWORKS="$ROOT_DIR/scripts/setup-networks.sh"
    if [ -f "$SETUP_NETWORKS" ]; then
        bash "$SETUP_NETWORKS"
    else
        echo -e "${RED}❌ Script setup-networks.sh não encontrado em: $SETUP_NETWORKS${NC}"
        exit 1
    fi
fi

# ==========================================
# CRIAR ESTRUTURA DE DIRETÓRIOS
# ==========================================
echo -e "${YELLOW}📁 Verificando estrutura de diretórios...${NC}"
mkdir -p "$BASE_DIR"/{data,backups,scripts}
mkdir -p "$BASE_DIR/data/letsencrypt"

# ==========================================
# INICIAR CONTAINER
# ==========================================
cd "$BASE_DIR"

# Configurações de healthcheck
INTERVAL="${NPM_INTERVAL}"
TIMEOUT="${NPM_TIMEOUT}"
RETRIES="${NPM_RETRIES}"
START_PERIOD="${NPM_START_PERIOD}"

echo -e "${YELLOW}🐳 Subindo container...${NC}"
docker compose --env-file "$ROOT_ENV" up -d --remove-orphans --quiet-pull

# Aguardar start_period antes de verificar healthcheck
COUNTDOWN=$START_PERIOD
while [ $COUNTDOWN -gt 0 ]; do
    printf "\r⏳ Aguardando inicialização... %2ds restantes" $COUNTDOWN
    sleep 1
    ((COUNTDOWN--))
done
echo ""

# ==========================================
# VERIFICAR HEALTHCHECK
# ==========================================
if ! docker ps --format '{{.Names}}' | grep -q "^${CONTAINER}$"; then
    echo -e "${RED}❌ Falha ao iniciar container${NC}"
    echo -e "${YELLOW}   Logs do container:${NC}"
    docker compose --env-file "$ROOT_ENV" logs --tail=50
    exit 1
fi

COUNT_RETRIES=0
while [ "$COUNT_RETRIES" -lt "$RETRIES" ]; do
    ((++COUNT_RETRIES))
    COUNT_TIMEOUT=0

    while [ "$COUNT_TIMEOUT" -lt "$INTERVAL" ]; do
        # Usa || true para que set -e não interrompa caso container ainda esteja iniciando
        STATUS=$(docker inspect --format='{{.State.Health.Status}}' "$CONTAINER" 2>/dev/null || echo "starting")

        if [ "$STATUS" = "healthy" ]; then
            echo -e "\n${GREEN}✅ Container $CONTAINER está saudável!${NC}"

            NPM_PORT_HOST=$(docker port "$CONTAINER" 81 2>/dev/null || echo "${NPM_PORT:-81}")

            echo -e "\n${BLUE}================================================${NC}"
            echo -e "${BLUE}🌐 INFORMAÇÕES DE ACESSO${NC}"
            echo -e "${BLUE}================================================${NC}"
            echo -e "   Interface Admin: ${GREEN}http://localhost:${NPM_PORT_HOST}${NC}"
            echo -e "   HTTP:            ${GREEN}http://localhost:80${NC}"
            echo -e "   HTTPS:           ${GREEN}https://localhost:443${NC}"
            echo -e "${BLUE}================================================${NC}"
            echo -e "${YELLOW}🔑 CREDENCIAIS PADRÃO (primeiro acesso):${NC}"
            echo -e "   Email: ${GREEN}admin@example.com${NC}"
            echo -e "   Senha: ${GREEN}changeme${NC}"
            echo -e "${YELLOW}   ⚠️ Altere a senha imediatamente após o primeiro login!${NC}"
            echo -e "${YELLOW}   ⚠️ Após configurar o proxy host, comente a porta 81 no docker-compose.yml${NC}"
            echo -e "${BLUE}================================================${NC}"
            exit 0

        elif [ "$STATUS" == "unhealthy" ]; then
            echo -e "\n${RED}❌ Container $CONTAINER não está saudável!${NC}"
            echo -e "${YELLOW}📋 Últimos logs:${NC}"
            docker compose logs --tail=50
            exit 1
        fi

        ((++COUNT_TIMEOUT))
        PERCEN=$((COUNT_TIMEOUT * 100 / INTERVAL))
        printf "\r⏳ Tentativa %d/%d (%3d%%) | Status: %-12s" $COUNT_RETRIES $RETRIES $PERCEN "$STATUS"
        sleep 1
    done

    echo -e "\n${YELLOW}⚠️ Tentativa $COUNT_RETRIES/$RETRIES esgotada${NC}"
done

echo -e "\n${RED}❌ Timeout: Container não ficou saudável após $RETRIES tentativas${NC}"
docker compose logs --tail=50
exit 1
