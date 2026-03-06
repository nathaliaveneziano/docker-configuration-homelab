#!/bin/bash
# ==========================================
# 🛑 STOP - NGINX Proxy Manager
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

echo -e "${BLUE}================================================${NC}"
echo -e "${BLUE}🛑 Parando NGINX Proxy Manager${NC}"
echo -e "${BLUE}================================================${NC}"

cd "$BASE_DIR"

# ==========================================
# VERIFICAR SE .ENV EXISTE
# ==========================================
ROOT_ENV="$BASE_DIR/.env"
if [ ! -f "$ROOT_ENV" ] && [ ! -L "$ROOT_ENV" ]; then
    echo -e "${RED}❌ Arquivo .env não encontrado em: $BASE_DIR${NC}"
    echo -e "${YELLOW}   Execute bash scripts/setup-env-links.sh na raiz do projeto${NC}"
    exit 1
fi

# Carregar variáveis do .env
set -a
source "$ROOT_ENV"
set +a

# Obter nome do container (com fallback)
CONTAINER="${NPM_CONTAINER:-nginx-proxy-manager}"

# ==========================================
# VERIFICAR SE CONTAINER ESTÁ RODANDO
# ==========================================
if ! docker ps --format '{{.Names}}' | grep -q "^${CONTAINER}$"; then
    echo -e "${YELLOW}⚠️  Container $CONTAINER não está rodando${NC}"
    exit 0
fi

# Capturar volumes antes de parar (para oferecer remoção depois)
VOLUMES=$(docker inspect -f '{{range .Mounts}}{{.Name}}{{"\n"}}{{end}}' "$CONTAINER" 2>/dev/null | grep -v '^$' || true)

# ==========================================
# PERGUNTAR SOBRE BACKUP ANTES DE PARAR
# ==========================================
read -p "💾 Deseja fazer backup antes de parar? (S/n): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Nn]$ ]]; then
    echo -e "${YELLOW}📦 Executando backup...${NC}"
    bash "$SCRIPT_DIR/backup.sh"
fi

# ==========================================
# PARAR CONTAINER
# ==========================================
echo -e "${YELLOW}🛑 Parando container $CONTAINER...${NC}"
docker compose --env-file "$ROOT_ENV" down

echo -e "${GREEN}✅ Container $CONTAINER parado com sucesso!${NC}"

# ==========================================
# OPÇÃO DE REMOVER VOLUMES (DADOS)
# ==========================================
if [ -n "$VOLUMES" ]; then
    echo ""
    read -p "🗑️  Deseja remover os dados (volumes)? (s/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Ss]$ ]]; then
        echo -e "${RED}⚠️  ATENÇÃO: Isso removerá PERMANENTEMENTE:${NC}"
        echo -e "${RED}   • Configurações de proxy hosts${NC}"
        echo -e "${RED}   • Certificados SSL${NC}"
        echo -e "${RED}   • Usuários e senhas${NC}"
        echo -e "${RED}   • Todas as configurações do NPM${NC}"
        echo ""
        read -p "⚠️  CONFIRMA remoção PERMANENTE? (digite 'CONFIRMO'): " CONFIRM

        if [ "${CONFIRM,,}" == "confirmo" ]; then
            echo -e "${RED}🗑️  Removendo volumes...${NC}"
            docker compose --env-file "$ROOT_ENV" down -v
            echo -e "${RED}✅ Volumes removidos${NC}"
        else
            echo -e "${YELLOW}❌ Remoção cancelada${NC}"
        fi
    fi
fi

echo -e "${BLUE}================================================${NC}"
echo -e "${BLUE}💡 Para iniciar novamente: bash scripts/start.sh${NC}"
echo -e "${BLUE}================================================${NC}"
