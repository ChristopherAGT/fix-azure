#!/bin/bash

# 🎨 Colores
verde='\e[1;32m'
rojo='\e[1;31m'
azul='\e[1;34m'
amarillo='\e[1;33m'
neutro='\e[0m'

# 🗺️ Verifica si geoiplookup está disponible
GEOIP_DISPONIBLE=$(command -v geoiplookup >/dev/null && echo "true" || echo "false")

# Función para obtener duración legible a partir de segundos
function duracion_legible() {
  local T=$1
  printf '%02d:%02d:%02d' $((T/3600)) $((T%3600/60)) $((T%60))
}

monitor_ssh() {
  clear
  echo -e "${azul}📡 MONITOR DE CONEXIONES SSH${neutro}"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  
  # --- Mostrar conexiones activas ---
  who | while read user tty date time ip_raw; do
    ip=$(echo "$ip_raw" | tr -d '()')
    login_time=$(who -u | grep "$tty" | awk '{print $6, $7}')
    epoch_start=$(date -d "$login_time" +%s 2>/dev/null)
    epoch_now=$(date +%s)
    duration=$((epoch_now - epoch_start))
    tiempo=$(duracion_legible $duration)

    # Procesos SSH del usuario
    procs=$(ps -u "$user" | grep sshd | wc -l)

    # Idle con comando w
    idle=$(w -h | grep "$tty" | awk '{print $4}')
    idle=${idle:-"N/A"}

    # GeoIP
    if [[ "$GEOIP_DISPONIBLE" == "true" ]]; then
      geo=$(geoiplookup "$ip" | awk -F ': ' '{print $2}')
    else
      geo="GeoIP no disponible"
    fi

    # IP sospechosa
    if [[ "$ip" =~ ^(45\.|103\.|1\.1\.1\.1) ]]; then
      alerta="${rojo}⚠️ Sospechosa${neutro}"
    else
      alerta="${verde}✔️ OK${neutro}"
    fi

    echo -e "${amarillo}👤 Usuario:${neutro} $user"
    echo -e "${amarillo}📍 IP:${neutro} $ip ($geo)"
    echo -e "${amarillo}⏰ Conectado desde:${neutro} $date $time"
    echo -e "${amarillo}⏳ Tiempo activo:${neutro} $tiempo"
    echo -e "${amarillo}🛌 Inactivo (idle):${neutro} $idle"
    echo -e "${amarillo}🔢 Procesos SSH:${neutro} $procs"
    echo -e "${amarillo}🕵️ Estado IP:${neutro} $alerta"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  done

  echo
  echo -e "${azul}📋 LISTA COMPLETA DE USUARIOS${neutro}"
  echo "=============================================================="
  printf "%-5s %-15s %-10s %-15s %-10s\n" "N°" "USUARIO" "STATUS" "CONEXIONES" "IDLE"
  echo "=============================================================="

  # Obtener usuarios con shell válido (no system users)
  usuarios=($(awk -F: '$7 ~ /(\/bash|\/sh|\/zsh|\/dash)/ {print $1}' /etc/passwd))

  n=1
  for u in "${usuarios[@]}"; do
    # Contar sesiones activas
    sesiones_act=0
    tiempo_total=0
    idle_max=0
    online="Offline"

    # Buscar todas las ttys de ese usuario en who
    while read user tty date time ip_raw; do
      if [[ "$user" == "$u" ]]; then
        online="Online"
        sesiones_act=$((sesiones_act + 1))

        login_time=$(who -u | grep "$tty" | awk '{print $6, $7}')
        epoch_start=$(date -d "$login_time" +%s 2>/dev/null)
        epoch_now=$(date +%s)
        duration=$((epoch_now - epoch_start))
        tiempo_total=$((tiempo_total + duration))

        idle=$(w -h | grep "$tty" | awk '{print $4}')
        # Convertir idle a segundos para comparar
        if [[ "$idle" =~ ([0-9]+):([0-9]+) ]]; then
          idle_sec=$(( ${BASH_REMATCH[1]}*60 + ${BASH_REMATCH[2]} ))
        elif [[ "$idle" =~ ([0-9]+) ]]; then
          idle_sec=${BASH_REMATCH[1]}
        else
          idle_sec=0
        fi
        (( idle_sec > idle_max )) && idle_max=$idle_sec
      fi
    done < <(who)

    # Formato legible de idle max
    idle_legible="N/A"
    if (( idle_max > 0 )); then
      idle_legible=$(duracion_legible $idle_max)
    fi

    tiempo_legible=$(duracion_legible $tiempo_total)

    printf "%-5s %-15s %-10s %-15s %-10s\n" "$n)" "$u" "$online" "$sesiones_act/$tiempo_legible" "$idle_legible"

    n=$((n+1))
  done

  echo "=============================================================="
}

# Refresca cada 10 segundos
while true; do
  monitor_ssh
  echo -e "${azul}⏱️ Refrescando en 10 segundos... Ctrl+C para salir.${neutro}"
  sleep 10
done
