#!/bin/bash
# ==========================================
# ⏰ INSTALL BACKUP CRON
# ==========================================
# Registra o backup-all-v1.sh no crontab do usuário
# com agendamento fixo: todos os dias às 02:00
#
# Comportamento no WSL2:
#   O cron do WSL2 só roda enquanto o WSL está ativo.
#   Se o Windows estiver ligado mas o WSL2 fechado no
#   horário agendado, o backup não será executado.
#   Por isso o script também registra uma tarefa via
#   Windows Task Scheduler (opcional), que acorda o
#   WSL2 no horário certo mesmo que esteja fechado.
#
# Versão      : v1 — horário fixo 02:00 todos os dias
# Localização : docker-configuration/scripts/install-backup-cron.sh

set -e

# Cores para output
BLUE='\033[0;34m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

# Detectar diretórios
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"
BACKUP_SCRIPT="$SCRIPT_DIR/backup-all-v1.sh"
CRON_MARKER="# docker-configuration backup-all-v1"

# Agendamento fixo: todo dia às 02:00
CRON_SCHEDULE="0 2 * * *"
WINDOWS_TIME="02:00"

echo -e "${BLUE}================================================${NC}"
echo -e "${BLUE}⏰ Instalando Cron — Backup Global${NC}"
echo -e "${BLUE}   Horário fixo: todos os dias às 02:00${NC}"
echo -e "${BLUE}================================================${NC}"
echo ""

# ==========================================
# VERIFICAR SCRIPT DE BACKUP
# ==========================================
if [ ! -f "$BACKUP_SCRIPT" ]; then
    echo -e "${RED}❌ Script não encontrado: $BACKUP_SCRIPT${NC}"
    exit 1
fi

chmod +x "$BACKUP_SCRIPT"

# ==========================================
# GARANTIR QUE O CRON ESTÁ RODANDO NO WSL2
# ==========================================
if ! pgrep -x cron > /dev/null 2>&1; then
    echo -e "${YELLOW}⚠️  Serviço cron não está rodando — iniciando...${NC}"
    sudo service cron start
    echo -e "${GREEN}✅ Cron iniciado${NC}"
fi

# ==========================================
# REMOVER ENTRADA ANTIGA SE EXISTIR
# ==========================================
if crontab -l 2>/dev/null | grep -qF "backup-all-v1.sh"; then
    echo -e "${YELLOW}⚠️  Entrada anterior encontrada — removendo...${NC}"
    crontab -l 2>/dev/null \
        | grep -v "backup-all-v1.sh" \
        | grep -v "$CRON_MARKER" \
        | crontab -
    echo -e "${GREEN}✅ Entrada anterior removida${NC}"
fi

# ==========================================
# REGISTRAR NO CRONTAB
# ==========================================
CRON_ENTRY="$CRON_SCHEDULE bash $BACKUP_SCRIPT >> $ROOT_DIR/logs/backup-all-cron.log 2>&1"

(
    crontab -l 2>/dev/null
    echo ""
    echo "$CRON_MARKER"
    echo "$CRON_ENTRY"
) | crontab -

echo -e "${GREEN}✅ Cron registrado com sucesso!${NC}"
echo ""
echo -e "${BLUE}================================================${NC}"
echo -e "${BLUE}📋 Configuração registrada${NC}"
echo -e "${BLUE}================================================${NC}"
echo -e "   Horário    : ${GREEN}todos os dias às 02:00${NC}"
echo -e "   Agendamento: ${GREEN}$CRON_SCHEDULE${NC}"
echo -e "   Script     : ${GREEN}$BACKUP_SCRIPT${NC}"
echo -e "   Log cron   : ${GREEN}$ROOT_DIR/logs/backup-all-cron.log${NC}"
echo ""

# ==========================================
# AVISO IMPORTANTE SOBRE WSL2
# ==========================================
echo -e "${YELLOW}⚠️  ATENÇÃO — Comportamento no WSL2:${NC}"
echo -e "${YELLOW}   O cron só executa enquanto o WSL2 estiver ativo.${NC}"
echo -e "${YELLOW}   Se o WSL2 estiver fechado às 02:00, o backup NÃO rodará.${NC}"
echo ""

# ==========================================
# VERIFICAR SE SCHTASKS ESTÁ DISPONÍVEL (WSL2)
# ==========================================
if command -v schtasks.exe > /dev/null 2>&1; then
    echo ""
    read -p "🪟 Deseja registrar também no Windows Task Scheduler? (s/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Ss]$ ]]; then
        TASK_NAME="docker-configuration-backup-all"

        schtasks.exe /delete /tn "$TASK_NAME" /f > /dev/null 2>&1 || true

        schtasks.exe /create \
            /tn "$TASK_NAME" \
            /tr "wsl bash $BACKUP_SCRIPT" \
            /sc daily \
            /st "$WINDOWS_TIME" \
            /f > /dev/null 2>&1

        echo -e "${GREEN}✅ Tarefa registrada no Windows Task Scheduler${NC}"
        echo -e "   Nome   : ${GREEN}$TASK_NAME${NC}"
        echo -e "   Horário: ${GREEN}$WINDOWS_TIME diariamente${NC}"
        echo -e "   ${GREEN}O backup rodará mesmo que o WSL2 esteja fechado${NC}"
    fi
else
    echo -e "   ${YELLOW}Para garantir execução com WSL2 fechado, execute no PowerShell:${NC}"
    echo -e "   ${GREEN}schtasks /create /tn \"docker-configuration-backup-all\" /tr \"wsl bash $BACKUP_SCRIPT\" /sc daily /st $WINDOWS_TIME /f${NC}"
fi

# ==========================================
# RESUMO FINAL
# ==========================================
echo ""
echo -e "${BLUE}================================================${NC}"
echo -e "${GREEN}🎉 Instalação concluída!${NC}"
echo -e "${BLUE}================================================${NC}"
echo ""
echo -e "${YELLOW}💡 Comandos úteis:${NC}"
echo -e "   Ver crontab atual  : ${GREEN}crontab -l${NC}"
echo -e "   Remover entrada    : ${GREEN}crontab -l | grep -v 'backup-all-v1.sh' | crontab -${NC}"
echo -e "   Testar manualmente : ${GREEN}bash $BACKUP_SCRIPT${NC}"
echo -e "   Ver log de hoje    : ${GREEN}cat $ROOT_DIR/logs/backup-all_\$(date +%Y%m%d).log${NC}"
echo -e "   Ver log do cron    : ${GREEN}cat $ROOT_DIR/logs/backup-all-cron.log${NC}"
echo ""
