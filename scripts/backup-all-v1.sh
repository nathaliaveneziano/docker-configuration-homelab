#!/bin/bash
# ==========================================
# 💾 BACKUP ALL - Stack Completa
# ==========================================
# Executa o backup.sh de cada container da stack
# Localização: docker-configuration/scripts/backup-all-v1.sh
#
# Versão      : v1 — agendamento fixo (02:00 todos os dias)
# Uso manual  : bash scripts/backup-all-v1.sh
# Agendamento : configurar via scripts/install-backup-cron.sh

set -e

# Cores para output
BLUE='\033[0;34m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
CYAN='\033[0;36m'
NC='\033[0m'

# Detectar diretórios
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"
LOG_DIR="$ROOT_DIR/logs"

# Um log por dia — execuções do mesmo dia sobrescrevem
LOG_FILE="$LOG_DIR/backup-all_$(date +%Y%m%d).log"

# ==========================================
# SETUP DE LOG
# ==========================================
mkdir -p "$LOG_DIR"

log() {
    echo -e "$1" | tee -a "$LOG_FILE"
}

# ==========================================
# HEADER
# ==========================================
log ""
log "${BLUE}================================================${NC}"
log "${BLUE}💾 Backup Global - Stack Homelab${NC}"
log "${BLUE}   $(date '+%Y-%m-%d %H:%M:%S')${NC}"
log "${BLUE}================================================${NC}"
log ""

# ==========================================
# VERIFICAR .ENV
# ==========================================
if [ ! -f "$ROOT_DIR/.env" ] && [ ! -L "$ROOT_DIR/.env" ]; then
    log "${RED}❌ Arquivo .env não encontrado em: $ROOT_DIR${NC}"
    exit 1
fi

set -a
source "$ROOT_DIR/.env"
set +a

# ==========================================
# ORDEM DE BACKUP
# ==========================================
# Camadas de dados primeiro — garante consistência
# entre dependências (ex: WordPress depende do MariaDB)
# Camadas de IA e mídia por último — são sob demanda
# e podem estar paradas
BACKUP_ORDER=(
    # ── Camada 4 — Bancos de Dados ─────────────────────
    "database/mariadb"
    "database/postgresql"
    "database/redis"
    "database/rabbitmq"

    # ── Camada 16 — Storage ────────────────────────────
    "storage/minio"

    # ── Camada 6 — CMS ─────────────────────────────────
    "cms/wordpress"

    # ── Camada 7 — Automação ───────────────────────────
    "automation/n8n"

    # ── Camada 1 — Edge ────────────────────────────────
    "edge/nginx-proxy-manager"
    "edge/cloudflare-tunnel"

    # ── Camada 2 — Segurança ───────────────────────────
    "security/authelia"
    "security/crowdsec"

    # ── Camada 3 — Orquestração ────────────────────────
    "orchestration/portainer"

    # ── Camada 5 — Admin de Banco ──────────────────────
    "database-admin/adminer"

    # ── Camada 17 — Integrações ────────────────────────
    "integrations/prometheus"
    "integrations/grafana"
    "integrations/uptime-kuma"
    "integrations/duplicati"

    # ── Camada 8 — LLM ─────────────────────────────────
    "llm/ollama"
    "llm/open-webui"

    # ── Camada 9 — Visão ───────────────────────────────
    "vision/llava"

    # ── Camada 10 — Vídeo ──────────────────────────────
    "video/video-worker"

    # ── Camada 11 — Transcrição ────────────────────────
    "transcription/whisper"

    # ── Camada 12 — Geração de Imagem ──────────────────
    "image-gen/stable-diffusion"

    # ── Camada 13 — TTS ────────────────────────────────
    "tts/piper-tts"
    "tts/coqui-tts"

    # ── Camada 14 — Música ─────────────────────────────
    "music/audiocraft"

    # ── Camada 15 — Media Processor ────────────────────
    "media/media-processor-api"
    "media/media-worker"
)

# ==========================================
# CONTADORES
# ==========================================
TOTAL=0
SUCCESS=0
SKIPPED=0
FAILED=0
FAILED_LIST=()

# ==========================================
# EXECUTAR BACKUPS
# ==========================================
CURRENT_LAYER=""

for SERVICE_PATH in "${BACKUP_ORDER[@]}"; do

    LAYER=$(echo "$SERVICE_PATH" | cut -d'/' -f1)
    SERVICE=$(echo "$SERVICE_PATH" | cut -d'/' -f2)
    BACKUP_SCRIPT="$ROOT_DIR/$SERVICE_PATH/scripts/backup.sh"

    if [[ "$CURRENT_LAYER" != "$LAYER" ]]; then
        log ""
        log "${CYAN}📁 [$LAYER]${NC}"
        CURRENT_LAYER="$LAYER"
    fi

    ((++TOTAL))

    if [ ! -f "$BACKUP_SCRIPT" ]; then
        log "   ${YELLOW}⚠️  $SERVICE — backup.sh não encontrado (pulando)${NC}"
        ((++SKIPPED))
        continue
    fi

    log "   🔄 $SERVICE — iniciando backup..."

    if bash "$BACKUP_SCRIPT" >> "$LOG_FILE" 2>&1; then
        log "   ${GREEN}✅ $SERVICE — backup concluído${NC}"
        ((++SUCCESS))
    else
        EXIT_CODE=$?
        log "   ${RED}❌ $SERVICE — falhou (exit $EXIT_CODE)${NC}"
        FAILED_LIST+=("$SERVICE_PATH")
        ((++FAILED))
    fi

done

# ==========================================
# LIMPEZA DE LOGS ANTIGOS
# ==========================================
# Mantém apenas os últimos 30 arquivos de log
log ""
log "${YELLOW}🧹 Limpando logs antigos (mantendo últimos 30)...${NC}"
ls -t "$LOG_DIR"/backup-all_*.log 2>/dev/null | tail -n +31 | xargs -r rm --
log "   ${GREEN}✅ Limpeza concluída${NC}"

# ==========================================
# RESUMO FINAL
# ==========================================
log ""
log "${BLUE}================================================${NC}"
log "${BLUE}📋 Resumo do Backup Global${NC}"
log "${BLUE}   $(date '+%Y-%m-%d %H:%M:%S')${NC}"
log "${BLUE}================================================${NC}"
log "   Total de serviços : $TOTAL"
log "   ${GREEN}✅ Sucesso          : $SUCCESS${NC}"
log "   ${YELLOW}⚠️  Pulados          : $SKIPPED${NC}"
log "   ${RED}❌ Falhas           : $FAILED${NC}"
log ""

if [ ${#FAILED_LIST[@]} -gt 0 ]; then
    log "${RED}🔴 Serviços com falha:${NC}"
    for FAILED_SERVICE in "${FAILED_LIST[@]}"; do
        log "   • $FAILED_SERVICE"
    done
    log ""
    log "${YELLOW}💡 Para investigar: cat $LOG_FILE${NC}"
    log "${BLUE}================================================${NC}"
    exit 1
fi

log "${GREEN}🎉 Backup global concluído com sucesso!${NC}"
log "${YELLOW}💡 Log completo: $LOG_FILE${NC}"
log "${BLUE}================================================${NC}"
