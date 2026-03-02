#!/bin/bash
# ==========================================
# 🌐 SETUP - Docker Networks
# ==========================================
# Cria todas as networks Docker necessárias
# Localização: docker-configuration/scripts/setup-networks.sh

set -e

BLUE='\033[0;34m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"

echo -e "${BLUE}================================================${NC}"
echo -e "${BLUE}🌐 Configurando Docker Networks${NC}"
echo -e "${BLUE}================================================${NC}"

# Carregar .env
if [ -f "$ROOT_DIR/.env" ]; then
    set -a
    source "$ROOT_DIR/.env"
    set +a
    echo -e "${GREEN}✅ Variáveis carregadas do .env${NC}"
else
    echo -e "${YELLOW}⚠️  Arquivo .env não encontrado${NC}"
    echo -e "${YELLOW}   Usando valores padrão${NC}"
fi

echo ""

# Função para criar network
create_network() {
    local NET_NAME=$1
    local NET_SUBNET=$2
    local NET_GATEWAY=$3
    local NET_DESCRIPTION=$4
    
    if docker network inspect "$NET_NAME" &>/dev/null; then
        echo -e "   ✅ ${NET_NAME} (já existe)"
        
        # Exibir informações
        EXISTING_SUBNET=$(docker network inspect "$NET_NAME" --format '{{range .IPAM.Config}}{{.Subnet}}{{end}}')
        EXISTING_GATEWAY=$(docker network inspect "$NET_NAME" --format '{{range .IPAM.Config}}{{.Gateway}}{{end}}')
        
        if [ "$EXISTING_SUBNET" != "$NET_SUBNET" ] || [ "$EXISTING_GATEWAY" != "$NET_GATEWAY" ]; then
            echo -e "      ${YELLOW}⚠️  Configuração diferente do .env:${NC}"
            echo -e "         Atual:    $EXISTING_SUBNET / $EXISTING_GATEWAY"
            echo -e "         .env:     $NET_SUBNET / $NET_GATEWAY"
        else
            echo -e "      Subnet:   $EXISTING_SUBNET"
            echo -e "      Gateway:  $EXISTING_GATEWAY"
        fi
    else
        echo -e "   ${YELLOW}📡 Criando ${NET_NAME}...${NC}"
        
        docker network create \
            --driver bridge \
            --subnet "$NET_SUBNET" \
            --gateway "$NET_GATEWAY" \
            --label "description=$NET_DESCRIPTION" \
            --label "project=docker-configuration" \
            "$NET_NAME"
        
        echo -e "   ${GREEN}✅ ${NET_NAME} (criada)${NC}"
        echo -e "      Subnet:   $NET_SUBNET"
        echo -e "      Gateway:  $NET_GATEWAY"
    fi
    
    echo ""
}

# ==========================================
# CRIAR NETWORKS PRINCIPAIS
# ==========================================

# Network principal (proxy, serviços web)
create_network \
    "${NETWORK_NAME}" \
    "${NETWORK_SUBNET}" \
    "${NETWORK_GATEWAY}" \
    "Network principal para proxy e serviços web"

# Adicionar mais networks conforme necessário
# Descomente e configure conforme seu projeto:

# Network para bancos de dados
# create_network \
#     "${DATABASE_NETWORK_NAME:-database_network}" \
#     "${DATABASE_NETWORK_SUBNET:-172.21.0.0/24}" \
#     "${DATABASE_NETWORK_GATEWAY:-172.21.0.1}" \
#     "Network isolada para bancos de dados"

# Network para backend
# create_network \
#     "${BACKEND_NETWORK_NAME:-backend_network}" \
#     "${BACKEND_NETWORK_SUBNET:-172.22.0.0/24}" \
#     "${BACKEND_NETWORK_GATEWAY:-172.22.0.1}" \
#     "Network para serviços backend"

# Network para IA/ML
# create_network \
#     "${AI_NETWORK_NAME:-ai_network}" \
#     "${AI_NETWORK_SUBNET:-172.23.0.0/24}" \
#     "${AI_NETWORK_GATEWAY:-172.23.0.1}" \
#     "Network para serviços de IA (Ollama, Stable Diffusion, etc)"

# ==========================================
# RESUMO
# ==========================================

echo -e "${BLUE}================================================${NC}"
echo -e "${GREEN}🎉 Configuração de Networks concluída!${NC}"
echo -e "${BLUE}================================================${NC}"
echo ""

# Listar todas as networks bridge
echo -e "${YELLOW}📋 Networks Bridge disponíveis:${NC}"
docker network ls --filter "driver=bridge" --format "table {{.Name}}\t{{.Driver}}\t{{.Scope}}"
echo ""

# Listar containers conectados (se houver)
echo -e "${YELLOW}🔗 Containers conectados às networks:${NC}"
for network in $(docker network ls --filter "driver=bridge" --format "{{.Name}}"); do
    CONTAINER_COUNT=$(docker network inspect "$network" --format '{{len .Containers}}')
    if [ "$CONTAINER_COUNT" -gt 0 ]; then
        echo -e "   ${GREEN}$network${NC} ($CONTAINER_COUNT container(s))"
        docker network inspect "$network" --format '{{range .Containers}}      - {{.Name}}{{"\n"}}{{end}}'
    fi
done

echo ""
echo -e "${YELLOW}💡 Dicas:${NC}"
echo -e "   • Inspecionar network: ${GREEN}docker network inspect NETWORK_NAME${NC}"
echo -e "   • Remover network:     ${GREEN}docker network rm NETWORK_NAME${NC}"
echo -e "   • Listar networks:     ${GREEN}docker network ls${NC}"
echo -e "   • Adicionar container: ${GREEN}docker network connect NETWORK_NAME CONTAINER${NC}"
echo ""