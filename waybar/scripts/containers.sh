#!/usr/bin/env bash
# containers.sh — indicador Docker/Podman para Waybar (NixOS)

set -euo pipefail
PATH="/run/current-system/sw/bin:$PATH"

icon=""  # cambia si tu Nerd Font no lo tiene (p.ej. "🐳")

ENGINE=""
if command -v docker >/dev/null 2>&1; then
  ENGINE="docker"
elif command -v podman >/dev/null 2>&1; then
  ENGINE="podman"
fi

out_json() {
  # $1 = text, $2 = class, $3 = tooltip
  printf '{"text":"%s","class":"%s","tooltip":"%s"}\n' "$1" "$2" "$3"
}

if [ -z "${ENGINE}" ]; then
  out_json "${icon} n/a" "off" "No se encontró docker ni podman en PATH"
  exit 0
fi

# ¿daemon/engine arriba?
if ! ${ENGINE} info >/dev/null 2>&1; then
  # Para podman, puede haber máquina arrancando
  if [ "${ENGINE}" = "podman" ] && command -v podman >/dev/null 2>&1; then
    if podman machine list --format '{{range .}}{{if .Running}}{{println .Name}}{{end}}{{end}}' 2>/dev/null | grep -q .; then
      out_json "${icon} starting" "starting" "Podman machine corriendo, engine aún no listo"
      exit 0
    fi
  fi
  out_json "${icon} off" "off" "El servicio de ${ENGINE} no está disponible"
  exit 0
fi

running="$(${ENGINE} ps -q 2>/dev/null | wc -l | tr -d ' ')"
total="$(${ENGINE} ps -aq 2>/dev/null | wc -l | tr -d ' ')"

text="${icon} ${running}/${total}"
tip="$(${ENGINE} ps --format '• {{.Names}} ({{.Status}})' 2>/dev/null | sed ':a;N;$!ba;s/\n/\\n/g')"
[ -z "${tip}" ] && tip="Sin contenedores activos"

out_json "${text}" "on" "${tip}"
