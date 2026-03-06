#!/bin/bash
# ==========================================
# 🔗 SETUP - Symlinks do .env
# ==========================================
# Cria symlinks do .env global em cada serviço
# Estrutura: docker-configuration/[layer]/[service]/
# Localização: docker-configuration/scripts/setup-env-links.sh

set -e

BLUE='\033[0;34m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
CYAN='\033[0;36m'
NC='\033[0m'

# Detectar diretório raiz (garantir path absoluto)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"
ENV_FILE="$ROOT_DIR/.env"

# ==========================================
# CAMADAS CONHECIDAS (layer directories)
# ==========================================
# Camada 1  – Edge / Entrada
# Camada 2  – Segurança
# Camada 3  – Orquestração & Gestão
# Camada 4  – IA
# Camada 5  – Processamento de Mídia
# Camada 6  – Automação
# Camada 7  – Dados
# Camada 8  – CMS & Apps
# Camada 9  – Observabilidade
# Camada 10 – Backup
KNOWN_LAYERS=(
    "edge"
    "security"
    "orchestration"
    "ai"
    "media"
    "automation"
    "data"
    "apps"
    "observability"
    "backup"
)

# Diretórios a ignorar (não são serviços)
IGNORED_DIRS=(
    "scripts"
    "utils"
    "backup"
    "_backup"
    "docs"
    "data"
)

# ==========================================
# FUNÇÕES AUXILIARES
# ==========================================

is_known_layer() {
    local dir="$1"
    for layer in "${KNOWN_LAYERS[@]}"; do
        [[ "$dir" == "$layer" ]] && return 0
    done
    return 1
}

is_ignored_dir() {
    local dir="$1"
    for ignored in "${IGNORED_DIRS[@]}"; do
        [[ "$dir" == "$ignored" ]] && return 0
    done
    return 1
}

# ==========================================
# HEADER
# ==========================================
echo -e "${BLUE}================================================${NC}"
echo -e "${BLUE}🔗 Criando Symlinks do .env${NC}"
echo -e "${BLUE}   Estrutura: [layer]/[service]/.env → ../../.env${NC}"
echo -e "${BLUE}================================================${NC}"
echo ""

# Verificar se .env global existe
if [ ! -f "$ENV_FILE" ]; then
    echo -e "${RED}❌ Arquivo .env não encontrado em: $ROOT_DIR${NC}"
    echo -e "${YELLOW}   Copie o .env.example para .env e configure as variáveis${NC}"
    echo -e "${YELLOW}   Exemplo: cp $ROOT_DIR/.env.example $ROOT_DIR/.env${NC}"
    exit 1
fi

echo -e "${GREEN}✅ Arquivo .env global encontrado: $ENV_FILE${NC}"
echo ""

# ==========================================
# PROCESSAR CADA SERVIÇO
# ==========================================
SERVICE_COUNT=0
CURRENT_LAYER=""

# Ordenar por path para agrupar por camada no output
while IFS= read -r -d '' compose_file; do
    SERVICE_DIR="$(dirname "$compose_file")"
    SERVICE_NAME="$(basename "$SERVICE_DIR")"
    LAYER_DIR="$(dirname "$SERVICE_DIR")"
    LAYER_NAME="$(basename "$LAYER_DIR")"

    # Ignorar docker-compose.yml que estão diretamente na raiz ou em scripts/utils
    if is_ignored_dir "$SERVICE_NAME"; then
        continue
    fi

    # Ignorar se o "layer" for a própria raiz do projeto (serviços sem camada)
    if [[ "$LAYER_DIR" == "$ROOT_DIR" ]]; then
        # Serviço solto na raiz — caminho relativo é ../.env (um nível)
        SYMLINK_TARGET="../.env"
        DISPLAY_PATH="${SERVICE_NAME}/.env"

        # Ainda assim, ignorar se for um diretório especial
        if is_ignored_dir "$SERVICE_NAME"; then
            continue
        fi

        # Exibir header de serviços raiz
        if [[ "$CURRENT_LAYER" != "__root__" ]]; then
            echo -e "${CYAN}📁 [root]${NC}"
            CURRENT_LAYER="__root__"
        fi
    else
        # Serviço dentro de uma camada — caminho relativo é ../../.env (dois níveis)
        SYMLINK_TARGET="../../.env"
        DISPLAY_PATH="${LAYER_NAME}/${SERVICE_NAME}/.env"

        # Verificar se está dentro de uma camada conhecida
        if ! is_known_layer "$LAYER_NAME"; then
            echo -e "   ${YELLOW}⚠️  Ignorando ${DISPLAY_PATH} (layer '${LAYER_NAME}' desconhecida)${NC}"
            continue
        fi

        # Exibir header da camada quando mudar
        if [[ "$CURRENT_LAYER" != "$LAYER_NAME" ]]; then
            echo -e "${CYAN}📁 [$LAYER_NAME]${NC}"
            CURRENT_LAYER="$LAYER_NAME"
        fi
    fi

    # ------------------------------------------
    # Criar / verificar symlink
    # ------------------------------------------
    cd "$SERVICE_DIR"

    if [ -L ".env" ]; then
        # Já é symlink — verificar se aponta corretamente
        EXISTING_TARGET=$(readlink .env)

        if [ "$EXISTING_TARGET" == "$SYMLINK_TARGET" ]; then
            echo -e "   ✅ ${DISPLAY_PATH} → ${SYMLINK_TARGET} (OK)"
        else
            echo -e "   ${YELLOW}⚠️  ${DISPLAY_PATH} → ${EXISTING_TARGET} (atualizando para ${SYMLINK_TARGET})${NC}"
            rm ".env"
            ln -s "$SYMLINK_TARGET" ".env"
            echo -e "   ✅ ${DISPLAY_PATH} → ${SYMLINK_TARGET} (atualizado)"
        fi

    elif [ -f ".env" ]; then
        # Arquivo regular — fazer backup e substituir por symlink
        BACKUP_NAME=".env.backup.$(date +%Y%m%d_%H%M%S)"
        echo -e "   ${YELLOW}⚠️  ${DISPLAY_PATH} é arquivo regular — criando backup${NC}"
        mv ".env" "$BACKUP_NAME"
        ln -s "$SYMLINK_TARGET" ".env"
        echo -e "   ✅ ${DISPLAY_PATH} → ${SYMLINK_TARGET} (backup salvo em ${BACKUP_NAME})"

    else
        # Não existe — criar symlink
        ln -s "$SYMLINK_TARGET" ".env"
        echo -e "   ✅ ${DISPLAY_PATH} → ${SYMLINK_TARGET} (criado)"
    fi

    ((++SERVICE_COUNT))

done < <(find "$ROOT_DIR" -name "docker-compose.yml" -not -path "*/\.*" -print0 2>/dev/null | sort -z)

# ==========================================
# RESUMO FINAL
# ==========================================
echo ""
echo -e "${BLUE}================================================${NC}"
echo -e "${GREEN}🎉 Symlinks criados com sucesso!${NC}"
echo -e "${GREEN}   Total de serviços processados: ${SERVICE_COUNT}${NC}"
echo -e "${BLUE}================================================${NC}"
echo ""
echo -e "${YELLOW}💡 Dicas:${NC}"
echo -e "   • Verificar todos os symlinks:  ${GREEN}find . -name '.env' -type l | sort${NC}"
echo -e "   • Inspecionar um symlink:       ${GREEN}readlink edge/nginx-proxy-manager/.env${NC}"
echo -e "   • Testar carregamento:          ${GREEN}cat edge/nginx-proxy-manager/.env | head -5${NC}"
echo -e "   • Remover um symlink:           ${GREEN}rm edge/nginx-proxy-manager/.env${NC}"
echo -e "   • Re-executar este script:      ${GREEN}bash scripts/setup-env-links.sh${NC}"
echo ""
echo -e "${YELLOW}📁 Estrutura de camadas esperada:${NC}"
for layer in "${KNOWN_LAYERS[@]}"; do
    echo -e "   ${GREEN}${layer}/${NC}[service]/docker-compose.yml"
done
echo ""
