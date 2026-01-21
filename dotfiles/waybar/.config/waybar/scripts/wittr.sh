#!/usr/bin/env bash
# Módulo de clima para Waybar (usa wttr.in)

req=$(curl -sf "wttr.in/?format=%t|%C|%l")
if [ -z "$req" ]; then
  echo '{"text":"--","tooltip":"No data"}'
  exit 0
fi

# Divide campos: temperatura | descripción | ubicación
temp=$(echo "$req" | awk -F"|" '{print $1}')
desc=$(echo "$req" | awk -F"|" '{print $2}')
loc=$(echo "$req" | awk -F"|" '{print $3}')

# Determina icono según la descripción
icon="☁️"
case "$desc" in
  *Sunny*|*Clear*) icon="☀️" ;;
  *Partly*|*Cloud*|*Overcast*) icon="🌤️" ;;
  *Rain*|*Drizzle*) icon="🌧️" ;;
  *Thunder*|*Storm*) icon="⛈️" ;;
  *Snow*|*Sleet*) icon="❄️" ;;
  *Fog*|*Mist*|*Haze*) icon="🌫️" ;;
esac

# Texto principal e información extra
bar="${icon} ${temp}"
tooltip="${loc} — ${desc}"

# Devuelve JSON para Waybar
echo "{\"text\": \"${bar}\", \"tooltip\": \"${tooltip}\"}"
