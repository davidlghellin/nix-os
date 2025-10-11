#!/usr/bin/env bash
# mic_status.sh — Estado del micrófono para Waybar (NixOS)
# Siempre imprime una línea JSON válida.

set -euo pipefail
PATH="/run/current-system/sw/bin:$PATH"

json() {
  # $1 text, $2 class, $3 tooltip
  local t="$1" c="$2" tip="$3"
  # Escapar \, ", y saltos de línea en tooltip
  tip="${tip//\\/\\\\}"
  tip="${tip//\"/\\\"}"
  tip="${tip//$'\n'/\\n}"
  printf '{"text":"%s","class":"%s","tooltip":"%s"}\n' "$t" "$c" "$tip"
}

if ! command -v pactl >/dev/null 2>&1; then
  json " n/a" "off" "pactl no disponible"
  exit 0
fi

# Forzar inglés para que los parseos no fallen (yes/no)
export LANG=C LC_ALL=C

# ¿Apps grabando desde el micro?
rec_count="$(pactl list source-outputs short 2>/dev/null | wc -l | tr -d ' ')"
if [ "${rec_count:-0}" -gt 0 ]; then
  tip="$(pactl list source-outputs 2>/dev/null \
        | grep -E 'application.name =|media.name =' \
        | sed 's/.*= "\(.*\)"/• \1/' )"
  [ -z "$tip" ] && tip="Grabando"
  json " REC" "recording" "$tip"
  exit 0
fi

# Detectar source por defecto (puede estar vacío en algunos setups)
default_src="$(pactl info 2>/dev/null | sed -n 's/^Default Source: //p')"
if [ -z "$default_src" ] || [ "$default_src" = "n/a" ]; then
  default_src="$(pactl list short sources 2>/dev/null | awk 'NR==1{print $2}')"
fi
[ -z "$default_src" ] && { json " n/a" "off" "No hay fuentes de micrófono"; exit 0; }

# ¿Está muteado?
mute_line="$(pactl get-source-mute "$default_src" 2>/dev/null || true)"
if echo "$mute_line" | grep -Eqi 'yes'; then
  json "" "muted" "Micrófono en mute"
  exit 0
fi

# Activo pero sin uso
json "" "idle" "Micrófono activo (sin uso)"
