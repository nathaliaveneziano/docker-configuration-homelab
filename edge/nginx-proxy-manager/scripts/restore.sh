#!/bin/bash
# ==========================================
# ♻️ RESTORE - NGINX Proxy Manager
# ==========================================
# Restaura backup dos dados do NPM

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

echo -e "${BLUE}================================================${NC}"
echo -e "${BLUE}♻️  Restauração - NGINX Proxy Manager${NC}"
echo -e "${BLUE}================================================${NC}"

# ==========================================
# VERIFICAR SE HÁ BACKUPS DISPONÍVEIS
# ==========================================
if [ ! -d "$BACKUP_DIR" ] || [ -z "$(ls -A "$BACKUP_DIR"/backup_*.tar.gz 2>/dev/null)" ]; then
    echo -e "${RED}❌ Nenhum backup encontrado em $BACKUP_DIR${NC}"

    if [ -n "$HDD_PATH" ] && [ -d "$HDD_PATH/backups/$CONTAINER" ]; then
        HDD_BACKUP_DIR="$HDD_PATH/backups/$CONTAINER"
        if [ -n "$(ls -A "$HDD_BACKUP_DIR"/backup_*.tar.gz 2>/dev/null)" ]; then
            echo -e "${YELLOW}💡 Backups encontrados no HDD: $HDD_BACKUP_DIR${NC}"
            echo -e "${YELLOW}   Copie o backup desejado para $BACKUP_DIR e execute novamente${NC}"
        fi
    fi

    exit 1
fi

# ==========================================
# SELEÇÃO INTERATIVA DE BACKUP
# ==========================================
echo -e "${YELLOW}📋 Backups disponíveis:${NC}"
echo ""

# Popula array para uso com select
mapfile -t BACKUP_LIST < <(ls -t "$BACKUP_DIR"/*.tar.gz 2>/dev/null)

select BACKUP_FILE in "${BACKUP_LIST[@]}"; do
    if [ -n "$BACKUP_FILE" ]; then
        break
    fi
    echo -e "${YELLOW}Opção inválida. Tente novamente.${NC}"
done

BACKUP_SIZE=$(du -h "$BACKUP_FILE" | cut -f1)
BACKUP_DATE=$(stat -c %y "$BACKUP_FILE" | cut -d'.' -f1)

echo ""
echo -e "${YELLOW}📦 Backup selecionado:${NC}"
echo -e "   Arquivo: $(basename "$BACKUP_FILE")"
echo -e "   Tamanho: $BACKUP_SIZE"
echo -e "   Data:    $BACKUP_DATE"
echo ""

# ==========================================
# CONFIRMAÇÃO DE SEGURANÇA
# ==========================================
echo -e "${RED}⚠️  ATENÇÃO: Esta operação irá:${NC}"
echo -e "${RED}   • SOBRESCREVER todos os dados atuais do NPM${NC}"
echo -e "${RED}   • Apagar configurações existentes${NC}"
echo -e "${RED}   • Substituir certificados SSL atuais${NC}"
echo ""
read -p "⚠️  Deseja continuar? (s/N): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Ss]$ ]]; then
    echo -e "${RED}❌ Operação cancelada${NC}"
    exit 0
fi

# ==========================================
# PARAR CONTAINER SE ESTIVER RODANDO
# ==========================================
if docker ps --format '{{.Names}}' | grep -q "^${CONTAINER}$"; then
    echo -e "${YELLOW}🛑 Parando container $CONTAINER...${NC}"
    cd "$BASE_DIR"
    docker compose --env-file "$ROOT_ENV" down
fi

# ==========================================
# BACKUP DE SEGURANÇA DOS DADOS ATUAIS
# ==========================================
if [ -d "$DATA_DIR" ] && [ -n "$(ls -A "$DATA_DIR" 2>/dev/null)" ]; then
    SAFETY_BACKUP="$BACKUP_DIR/${CONTAINER}_pre_restore_$(date +%Y%m%d_%H%M%S).tar.gz"
    echo -e "${YELLOW}🔒 Criando backup de segurança dos dados atuais...${NC}"
    cd "$BASE_DIR"
    tar -czf "$SAFETY_BACKUP" data/ 2>/dev/null || true

    if [ -f "$SAFETY_BACKUP" ]; then
        SAFETY_SIZE=$(du -h "$SAFETY_BACKUP" | cut -f1)
        echo -e "${GREEN}✅ Backup de segurança: $(basename "$SAFETY_BACKUP") (${SAFETY_SIZE})${NC}"
    fi
fi

# ==========================================
# RESTAURAR BACKUP
# ==========================================
echo -e "${YELLOW}🗑️  Removendo dados antigos...${NC}"
rm -rf "$DATA_DIR"

echo -e "${YELLOW}📥 Extraindo backup...${NC}"
cd "$BASE_DIR"
tar -xzf "$BACKUP_FILE"

if [ ! -d "$DATA_DIR" ]; then
    echo -e "${RED}❌ Erro ao extrair backup — diretório data/ não encontrado${NC}"
    exit 1
fi

# ==========================================
# AJUSTAR PERMISSÕES (CRÍTICO WSL2)
# ==========================================
echo -e "${YELLOW}🔧 Ajustando permissões...${NC}"
PUID="${PUID:-1000}"
PGID="${PGID:-1000}"

chown -R "${PUID}:${PGID}" "$DATA_DIR" 2>/dev/null || \
    sudo chown -R "${PUID}:${PGID}" "$DATA_DIR" 2>/dev/null || \
    echo -e "${YELLOW}⚠️  Não foi possível ajustar permissões (tente com sudo)${NC}"

# ==========================================
# REINICIAR CONTAINER
# ==========================================
bash "$SCRIPT_DIR/start.sh"