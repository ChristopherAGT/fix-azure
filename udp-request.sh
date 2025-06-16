#!/bin/bash

# ░▒▓█🎯 FIX AUTOMÁTICO PARA UDP-REQUEST by @Rufu99 █▓▒░

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# 🎨 COLORES
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[1;36m'
NC='\033[0m' # Sin color
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

# 📂 VARIABLES
SERVICE_FILE="/etc/systemd/system/udprequest.service"
LOG_FILE="/var/log/fix-udprequest.log"
PRIVATE_IP=$(hostname -I | awk '{print $1}')
INTERFACE=$(ip route get 1 | awk '{print $5; exit}')

# ⏳ Spinner
spinner() {
    local pid=$1
    local delay=0.1
    local spinstr='|/-\'
    while ps a | awk '{print $1}' | grep -q "$pid"; do
        local temp=${spinstr#?}
        printf " [%c]  " "$spinstr"
        local spinstr=$temp${spinstr%"$temp"}
        sleep $delay
        printf "\b\b\b\b\b\b"
    done
}

# 📃 Log del proceso
exec > >(tee -a "$LOG_FILE") 2>&1

clear
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo -e " 🛠️ REPARADOR DE UDP-REQUEST [ADMRufu]"
echo -e "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

# ✅ Verificar IP privada
echo -e "${CYAN}🔍 Detectando IP privada...${NC}"
if [[ -z "$PRIVATE_IP" ]]; then
    echo -e "${RED}❌ No se pudo detectar la IP privada. Abortando.${NC}"
    exit 1
fi
echo -e "${GREEN}✅ IP privada detectada: $PRIVATE_IP${NC}"

# ✅ Verificar archivo de servicio
if [[ ! -f "$SERVICE_FILE" ]]; then
    echo -e "${RED}❌ Archivo no encontrado: $SERVICE_FILE${NC}"
    exit 1
fi

# 🧠 Verificar si contiene línea con -ip=
if ! grep -qE '\-ip=[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+' "$SERVICE_FILE"; then
    echo -e "${RED}❗ No se encontró línea con -ip=... Requiere revisión manual.${NC}"
    exit 1
fi

# 📦 Backup antes de editar
cp "$SERVICE_FILE" "$SERVICE_FILE.bak"
echo -e "${YELLOW}🗂️ Backup creado: ${SERVICE_FILE}.bak${NC}"

# 🛠️ Reemplazo de IP en línea -ip=
echo -e "${YELLOW}🔧 Reemplazando IP en el archivo...${NC}"
sed -i -E "s/(-ip=)[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+/\1$PRIVATE_IP/" "$SERVICE_FILE"

# 🧠 Reemplazo de interfaz (opcional)
if grep -q "\-net=" "$SERVICE_FILE"; then
    sed -i -E "s/(-net=)[a-zA-Z0-9]+/\1$INTERFACE/" "$SERVICE_FILE"
    echo -e "${GREEN}🔄 Interfaz de red ajustada a: $INTERFACE${NC}"
fi

# ✅ Verificar reemplazo exitoso
if grep -q "$PRIVATE_IP" "$SERVICE_FILE"; then
    echo -e "${GREEN}✔️ IP privada aplicada correctamente en el archivo.${NC}"
else
    echo -e "${RED}❌ No se pudo aplicar la IP privada. Abortando...${NC}"
    exit 1
fi

# 🛑 Detener y deshabilitar servicio
echo -e "${YELLOW}🛑 Deteniendo servicio...${NC}"
systemctl stop udprequest.service & spinner $!

if systemctl is-enabled udprequest.service &>/dev/null; then
    echo -e "${YELLOW}🚫 Deshabilitando servicio...${NC}"
    systemctl disable udprequest.service & spinner $!
fi

# 🔁 Recargar y reiniciar servicio
echo -e "${YELLOW}♻️ Recargando systemd y reiniciando...${NC}"
systemctl daemon-reload
systemctl restart udprequest.service & spinner $!

# 📋 Mostrar estado del servicio
echo -e "${CYAN}\n📊 Estado del servicio udp-request:${NC}"
systemctl status udprequest.service --no-pager | head -n 12

# 🎉 Éxito
echo -e "\n${GREEN}✅ Reparación completada exitosamente.${NC}"
echo -e "${CYAN}📁 Log disponible en: ${LOG_FILE}${NC}"
