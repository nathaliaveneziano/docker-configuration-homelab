#!/bin/bash
# ==========================================
# ⏰ INSTALL BACKUP CRON
# ==========================================
# Registra o backup-all-v2.sh no crontab do usuário
# com o agendamento definido no .env global
#
# Comportamento no WSL2:
#   O cron do WSL2 só roda enquanto o WSL está ativo.
#   Se o Windows estiver ligado mas o WSL2 fechado no
#   horário agendado, o backup não será executado.
#   Por isso o script também registra uma tarefa via
#   Windows Task Scheduler (opcional), que acorda o
#   WSL2 no horário certo mesmo que esteja fechado.
#
# Versão      : v2 — agendamento interativo via .env (BACKUP_SCHEDULE)
# Localização : docker-configuration/scripts/install-backup-cron.sh

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
BACKUP_SCRIPT="$SCRIPT_DIR/backup-all-v2.sh"
CRON_MARKER="# docker-configuration backup-all-v2"

echo -e "${BLUE}================================================${NC}"
echo -e "${BLUE}⏰ Instalando Agendamento — Backup Global${NC}"
echo -e "${BLUE}================================================${NC}"
echo ""

# ==========================================
# VERIFICAR SCRIPT DE BACKUP
# ==========================================
if [ ! -f "$BACKUP_SCRIPT" ]; then
    echo -e "${RED}❌ Script não encontrado: $BACKUP_SCRIPT${NC}"
    echo -e "${YELLOW}   Execute primeiro: bash scripts/setup-env-links.sh${NC}"
    exit 1
fi

chmod +x "$BACKUP_SCRIPT"

# ==========================================
# CARREGAR .ENV
# ==========================================
if [ ! -f "$ROOT_DIR/.env" ] && [ ! -L "$ROOT_DIR/.env" ]; then
    echo -e "${RED}❌ Arquivo .env não encontrado em: $ROOT_DIR${NC}"
    exit 1
fi

set -a
source "$ROOT_DIR/.env"
set +a

# ==========================================
# CONFIGURAÇÃO DO AGENDAMENTO
# ==========================================
echo -e "${CYAN}📅 Configuração do agendamento${NC}"
echo ""
echo -e "   Formato cron: ${YELLOW}minuto hora dia-do-mês mês dia-da-semana${NC}"
echo ""
echo -e "   Exemplos:"
echo -e "     ${GREEN}0 2 * * *${NC}       → todo dia às 02:00"
echo -e "     ${GREEN}0 2,14 * * *${NC}    → duas vezes por dia (02h e 14h)"
echo -e "     ${GREEN}0 */6 * * *${NC}     → a cada 6 horas"
echo -e "     ${GREEN}0 2 * * 1-5${NC}     → dias úteis às 02:00"
echo -e "     ${GREEN}0 2 * * 6,0${NC}     → fins de semana às 02:00"
echo -e "     ${GREEN}0 2 * * 1,3,5${NC}   → seg, qua e sex às 02:00"
echo -e "     ${GREEN}30 1,13 * * *${NC}   → 01:30 e 13:30 todos os dias"
echo ""

# Ler agendamento do .env ou pedir interativamente
if [ -n "${BACKUP_SCHEDULE:-}" ]; then
    echo -e "   Valor atual no ${YELLOW}.env${NC}: ${GREEN}${BACKUP_SCHEDULE}${NC}"
    echo ""
    read -p "   Usar esse agendamento? (S/n): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Nn]$ ]]; then
        echo ""
        read -p "   Digite o novo agendamento cron: " CRON_SCHEDULE
        echo ""
    else
        CRON_SCHEDULE="$BACKUP_SCHEDULE"
    fi
else
    echo -e "   ${YELLOW}⚠️  BACKUP_SCHEDULE não definido no .env${NC}"
    echo ""
    read -p "   Digite o agendamento cron desejado: " CRON_SCHEDULE
    echo ""
fi

# Validar que não está vazio
if [ -z "$CRON_SCHEDULE" ]; then
    echo -e "${RED}❌ Agendamento não pode ser vazio${NC}"
    exit 1
fi

# ==========================================
# CONFIRMAR CONFIGURAÇÃO
# ==========================================
echo ""
echo -e "${CYAN}📋 Resumo da configuração${NC}"
echo -e "   Agendamento cron : ${GREEN}$CRON_SCHEDULE${NC}"
echo -e "   Script           : ${GREEN}$BACKUP_SCRIPT${NC}"
echo -e "   Log de saída     : ${GREEN}$ROOT_DIR/logs/backup-all-cron.log${NC}"
echo ""
read -p "   Confirmar instalação? (S/n): " -n 1 -r
echo
if [[ $REPLY =~ ^[Nn]$ ]]; then
    echo -e "${YELLOW}❌ Instalação cancelada${NC}"
    exit 0
fi

# ==========================================
# GARANTIR QUE O CRON ESTÁ RODANDO NO WSL2
# ==========================================
if ! pgrep -x cron > /dev/null 2>&1; then
    echo ""
    echo -e "${YELLOW}⚠️  Serviço cron não está rodando — iniciando...${NC}"
    sudo service cron start
    echo -e "${GREEN}✅ Cron iniciado${NC}"
fi

# ==========================================
# REMOVER ENTRADA ANTIGA SE EXISTIR
# ==========================================
if crontab -l 2>/dev/null | grep -qF "backup-all-v2.sh"; then
    echo ""
    echo -e "${YELLOW}⚠️  Entrada anterior encontrada — removendo...${NC}"
    crontab -l 2>/dev/null \
        | grep -v "backup-all-v2.sh" \
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

echo ""
echo -e "${GREEN}✅ Cron registrado com sucesso!${NC}"

# ==========================================
# ATUALIZAR .ENV COM O NOVO AGENDAMENTO
# ==========================================
# Se o usuário digitou um agendamento diferente do .env,
# pergunta se quer atualizar o .env também
if [ "${CRON_SCHEDULE}" != "${BACKUP_SCHEDULE:-}" ]; then
    echo ""
    read -p "   Atualizar BACKUP_SCHEDULE no .env com o novo valor? (S/n): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Nn]$ ]]; then
        if grep -q "^BACKUP_SCHEDULE=" "$ROOT_DIR/.env" 2>/dev/null; then
            sed -i "s|^BACKUP_SCHEDULE=.*|BACKUP_SCHEDULE=\"$CRON_SCHEDULE\"|" "$ROOT_DIR/.env"
        else
            echo "BACKUP_SCHEDULE=\"$CRON_SCHEDULE\"" >> "$ROOT_DIR/.env"
        fi
        echo -e "${GREEN}✅ .env atualizado com BACKUP_SCHEDULE=\"$CRON_SCHEDULE\"${NC}"
    fi
fi

# ==========================================
# AVISO IMPORTANTE SOBRE WSL2
# ==========================================
echo ""
echo -e "${YELLOW}⚠️  ATENÇÃO — Limitação do WSL2:${NC}"
echo -e "${YELLOW}   O cron só executa enquanto o WSL2 estiver ativo.${NC}"
echo -e "${YELLOW}   Se o WSL2 estiver fechado no horário agendado,${NC}"
echo -e "${YELLOW}   o backup NÃO será executado pelo cron.${NC}"
echo ""

# ==========================================
# WINDOWS TASK SCHEDULER (OPCIONAL)
# ==========================================
# Detecta primeiro horário do agendamento para o schtasks
# Ex: "0 2,14 * * *" → extrai "02:00" como horário principal
FIRST_HOUR=$(echo "$CRON_SCHEDULE" | awk '{print $2}' | cut -d',' -f1 | sed 's/\*/0/')
FIRST_MINUTE=$(echo "$CRON_SCHEDULE" | awk '{print $1}' | cut -d',' -f1 | sed 's/\*/0/')
WINDOWS_TIME=$(printf "%02d:%02d" "$FIRST_HOUR" "$FIRST_MINUTE")

# Sobrescrever com .env se definido explicitamente
if [ -n "${BACKUP_WINDOWS_TIME:-}" ]; then
    WINDOWS_TIME="$BACKUP_WINDOWS_TIME"
fi

if command -v schtasks.exe > /dev/null 2>&1; then
    echo -e "${CYAN}🪟 Windows Task Scheduler detectado${NC}"
    echo -e "   Registrar tarefa que acorda o WSL2 no horário do backup"
    echo -e "   Horário principal detectado: ${GREEN}$WINDOWS_TIME${NC}"
    echo ""
    echo -e "   ${YELLOW}Nota:${NC} Para agendamentos com múltiplos horários (ex: 02h e 14h),"
    echo -e "   apenas o primeiro horário (${GREEN}$WINDOWS_TIME${NC}) será registrado no Windows."
    echo -e "   Os demais horários funcionarão apenas se o WSL2 já estiver ativo."
    echo ""
    read -p "   Registrar no Windows Task Scheduler? (S/n): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Nn]$ ]]; then
        TASK_NAME="docker-configuration-backup-all"

        # Remover tarefa anterior se existir
        schtasks.exe /delete /tn "$TASK_NAME" /f > /dev/null 2>&1 || true

        schtasks.exe /create \
            /tn "$TASK_NAME" \
            /tr "wsl bash $BACKUP_SCRIPT" \
            /sc daily \
            /st "$WINDOWS_TIME" \
            /f > /dev/null 2>&1

        echo -e "${GREEN}✅ Tarefa registrada no Windows Task Scheduler${NC}"
        echo -e "   Nome    : ${GREEN}$TASK_NAME${NC}"
        echo -e "   Horário : ${GREEN}$WINDOWS_TIME diariamente${NC}"
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
echo -e "   Ver crontab atual    : ${GREEN}crontab -l${NC}"
echo -e "   Remover agendamento  : ${GREEN}crontab -l | grep -v 'backup-all' | crontab -${NC}"
echo -e "   Testar agora         : ${GREEN}bash $BACKUP_SCRIPT${NC}"
echo -e "   Ver último log       : ${GREEN}ls -t $ROOT_DIR/logs/backup-all_*.log | head -1 | xargs cat${NC}"
echo -e "   Ver log do cron      : ${GREEN}cat $ROOT_DIR/logs/backup-all-cron.log${NC}"
echo -e "   Re-executar setup    : ${GREEN}bash $SCRIPT_DIR/install-backup-cron.sh${NC}"
echo ""
