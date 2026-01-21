#!/usr/bin/env bash
# cam_status.sh — Estado de cámara para Waybar (NixOS)
# Imprime SIEMPRE una línea JSON: {"text":"…","class":"…","tooltip":"…"}

PATH="/run/current-system/sw/bin:$PATH"

json() {
  # $1 text, $2 class, $3 tooltip
  # escapamos saltos de línea en tooltip
  local tip="${3//$'\n'/\\n}"
  printf '{"text":"%s","class":"%s","tooltip":"%s"}\n' "$1" "$2" "$tip"
}

# 1) Detectar dispositivos de vídeo
shopt -s nullglob
videos=(/dev/video*)
shopt -u nullglob

if [ ${#videos[@]} -eq 0 ]; then
  json " n/a" "off" "No hay dispositivos /dev/video*"
  exit 0
fi

# 2) ¿Algún proceso usa la cámara?
procs=""
if command -v lsof >/dev/null 2>&1; then
  procs="$(lsof -w "${videos[@]}" 2>/dev/null | awk 'NR>1{print $1}' | sort -u)"
else
  # Fallback con fuser (puede no dar nombres bonitos, pero indica uso)
  if command -v fuser >/dev/null 2>&1; then
    pids="$(fuser -va "${videos[@]}" 2>/dev/null | awk 'NR>1{print $1}' | tr -s ' ' | cut -d' ' -f1 | sort -u)"
    if [ -n "$pids" ]; then
      # intenta mapear PIDs a nombres de proceso
      while read -r pid; do
        [ -n "$pid" ] && ps -o comm= -p "$pid"
      done <<< "$pids" | sort -u > /tmp/.cam_procs_$$
      procs="$(cat /tmp/.cam_procs_$$)"
      rm -f /tmp/.cam_procs_$$
    fi
  fi
fi

if [ -n "$procs" ]; then
  tip="$(printf '%s\n' "$procs" | sed 's/^/• /')"
  json " ON" "on" "$tip"
  exit 0
fi

# 3) Libre
json "" "off" "Cámara libre"
