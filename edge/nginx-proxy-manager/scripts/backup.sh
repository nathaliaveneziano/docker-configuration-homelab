#!/bin/bash
# ==========================================
# 💾 BACKUP - NGINX Proxy Manager
# ==========================================
# Estratégia: Backup no SSD (rápido) + Cópia no HDD (segurança)

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
BACKUP_DIR="$BASE_DIR/backups"
DATA_DIR="$BASE_DIR/data"

# ==========================================
# CARREGAR VARIÁVEIS
# ==========================================
ROOT_ENV="$BASE_DIR/.env"
if [ ! -f "$ROOT_ENV" ] && [ ! -L "$ROOT_ENV" ]; then
    echo -e "${RED}❌ Arquivo .env não encontrado em: $BASE_DIR${NC}"
    exit 1
fi

set -a
source "$ROOT_ENV"
set +a

# Obter nome do container (com fallback)
CONTAINER="${NPM_CONTAINER:-nginx-proxy-manager}"
# Configuração de retenção (dias)
RETENTION_DAYS="${BACKUP_RETENTION_DAYS:-7}"

echo -e "${BLUE}================================================${NC}"
echo -e "${BLUE}💾 Iniciando Backup - NGINX Proxy Manager${NC}"
echo -e "${BLUE}================================================${NC}"

# ==========================================
# VERIFICAR SE HÁ DADOS PARA BACKUP
# ==========================================
if [ ! -d "$DATA_DIR" ]; then
    echo -e "${RED}❌ Diretório de dados não encontrado: $DATA_DIR${NC}"
    exit 1
fi

mkdir -p "$BACKUP_DIR"

# ==========================================
# STATUS DO CONTAINER
# ==========================================
if docker ps --format '{{.Names}}' | grep -q "^${CONTAINER}$"; then
    echo -e "${YELLOW}⚠️  Container ${CONTAINER} está rodando — backup a quente${NC}"
else
    echo -e "${YELLOW}ℹ️  Container ${CONTAINER} parado — backup a frio${NC}"
fi

# ==========================================
# CRIAR BACKUP
# ==========================================
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
BACKUP_FILE="backup_${TIMESTAMP}.tar.gz"

echo -e "${YELLOW}📦 Compactando dados...${NC}"
cd "$BASE_DIR"

tar -czf "$BACKUP_DIR/$BACKUP_FILE" \
    --exclude='data/logs' \
    --exclude='data/nginx/temp' \
    --exclude='*.log' \
    --exclude='*.tmp' \
    data/

if [ ! -f "$BACKUP_DIR/$BACKUP_FILE" ]; then
    echo -e "${RED}❌ Erro ao criar backup${NC}"
    exit 1
fi

BACKUP_SIZE=$(du -h "$BACKUP_DIR/$BACKUP_FILE" | cut -f1)
echo -e "${GREEN}✅ Backup criado (SSD)${NC}"
echo -e "   $BACKUP_DIR/$BACKUP_FILE (${BACKUP_SIZE})"

# ==========================================
# CÓPIA PARA HDD
# ==========================================
if [ -n "$HDD_PATH" ] && [ -d "$HDD_PATH" ]; then
    HDD_BACKUP_DIR="$HDD_PATH/backups/${CONTAINER}"
    mkdir -p "$HDD_BACKUP_DIR"

    echo -e "${YELLOW}📤 Copiando para HDD...${NC}"
    cp "$BACKUP_DIR/$BACKUP_FILE" "$HDD_BACKUP_DIR/"
    echo -e "${GREEN}✅ Backup copiado para HDD${NC}"
    echo -e "   $HDD_BACKUP_DIR/$BACKUP_FILE (${BACKUP_SIZE})"

    echo -e "${YELLOW}🧹 Limpando backups antigos no HDD (>${RETENTION_DAYS} dias)...${NC}"
    find "$HDD_BACKUP_DIR" -name "backup_*.tar.gz" -type f -mtime +"$RETENTION_DAYS" -delete
fi

# ==========================================
# RETENÇÃO NO SSD (ÚLTIMOS 5)
# ==========================================
echo -e "${YELLOW}🧹 Limpando backups antigos no SSD (mantendo últimos 5)...${NC}"
# shellcheck disable=SC2012
ls -t "$BACKUP_DIR"/backup_*.tar.gz 2>/dev/null | tail -n +6 | xargs -r rm --

# ==========================================
# LISTAR BACKUPS DISPONÍVEIS
# ==========================================
echo -e "${BLUE}================================================${NC}"
echo -e "${BLUE}📋 Backups disponíveis (SSD):${NC}"
ls -lth "$BACKUP_DIR"/backup_*.tar.gz 2>/dev/null | head -5 || echo "  Nenhum backup encontrado"

if [ -n "$HDD_PATH" ] && [ -n "${HDD_BACKUP_DIR:-}" ] && [ -d "$HDD_BACKUP_DIR" ]; then
    echo -e "${BLUE}📋 Backups disponíveis (HDD):${NC}"
    ls -lth "$HDD_BACKUP_DIR"/backup_*.tar.gz 2>/dev/null | head -5 || echo "  Nenhum backup encontrado"
fi

echo -e "${BLUE}================================================${NC}"
echo -e "${GREEN}🎉 Backup concluído com sucesso!${NC}"
echo -e "${BLUE}================================================${NC}"
