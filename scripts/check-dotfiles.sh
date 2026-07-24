#!/usr/bin/env bash
#
# Verifica que los dotfiles no tengan enlaces muertos.
#
# Nace de una auditoría manual (jul 2026) que encontró 8 roturas que llevaban
# meses sin detectar: binarios que no existen (alacritty, orca), herramientas
# de un compositor usadas en otro (hyprshot en niri), rutas del store escritas
# a mano que el GC se llevó (temas de rofi), scripts inexistentes (applets de
# rofi en waybar) y claves de config renombradas al subir de release.
#
# Uso:  ./scripts/check-dotfiles.sh
# Salida: 0 si todo está bien, 1 si hay algo roto.

set -uo pipefail
cd "$(dirname "$0")/.." || exit 1

fallos=0
avisos=0
rojo=$'\e[31m'; verde=$'\e[32m'; ama=$'\e[33m'; fin=$'\e[0m'

ok()    { printf '  %s✓%s %s\n' "$verde" "$fin" "$1"; }
mal()   { printf '  %s✗%s %s\n' "$rojo" "$fin" "$1"; fallos=$((fallos+1)); }
aviso() { printf '  %s!%s %s\n' "$ama" "$fin" "$1"; avisos=$((avisos+1)); }
titulo(){ printf '\n\e[1m%s\e[0m\n' "$1"; }

existe_bin() {
  case "$1" in
    /*|'~'/*|'$HOME'/*) [ -e "${1/#\~/$HOME}" ] || [ -e "${1/#\$HOME/$HOME}" ] ;;
    *) command -v "$1" >/dev/null 2>&1 ;;
  esac
}

##############################################################################
titulo "1. Binarios invocados por los compositores"
##############################################################################

# --- niri: spawn / spawn-sh / spawn-at-startup ---
python3 - <<'PY' > /tmp/.chk_niri 2>/dev/null
import re
txt = open('dotfiles/niri/.config/niri/config.kdl').read()
pat = r'\b(spawn-sh-at-startup|spawn-at-startup|spawn-sh|spawn)\b\s+((?:"(?:[^"\\]|\\.)*"\s*)+)'
for m in re.finditer(pat, txt):
    ini = txt.rfind('\n', 0, m.start()) + 1
    if txt[ini:m.start()].strip().startswith('//'):
        continue
    linea = txt[:m.start()].count('\n') + 1
    args = re.findall(r'"((?:[^"\\]|\\.)*)"', m.group(2))
    if 'sh' in m.group(1).split('-'):
        tok = re.findall(r'[a-zA-Z0-9_./~$-]+', args[0])
        exe = tok[0] if tok else ''
    else:
        exe = args[0]
    if exe:
        print(f'{linea}\t{exe}')
PY

while IFS=$'\t' read -r linea exe; do
  [ -n "${exe:-}" ] || continue
  existe_bin "$exe" || mal "niri L$linea: '$exe' no existe"
done < <(sort -u -k2 /tmp/.chk_niri)

# --- hyprland: exec-once y binds con exec ---
python3 - <<'PY' > /tmp/.chk_hypr 2>/dev/null
import re
txt = open('dotfiles/hypr/.config/hypr/hyprland.conf').read()
variables = {'$' + m.group(1): m.group(2).strip()
             for m in re.finditer(r'^\s*\$(\w+)\s*=\s*(.+?)\s*$', txt, re.M)}
for m in re.finditer(r'^\s*(exec-once|bind[lset]*)\s*=\s*(.+)$', txt, re.M):
    linea = txt[:m.start()].count('\n') + 1
    cuerpo = m.group(2)
    if m.group(1) == 'exec-once':
        cmd = cuerpo
    else:
        partes = [p.strip() for p in cuerpo.split(',')]
        if len(partes) < 3 or partes[2] != 'exec':
            continue
        cmd = ','.join(partes[3:]).strip()
    cmd = re.sub(r'^\[.*?\]\s*', '', cmd).split('#')[0].strip()
    for k, v in variables.items():
        cmd = cmd.replace(k, v)
    tok = re.findall(r'[a-zA-Z0-9_./~$-]+', cmd)
    if tok:
        print(f'{linea}\t{tok[0]}')
PY

while IFS=$'\t' read -r linea exe; do
  [ -n "${exe:-}" ] || continue
  existe_bin "$exe" || mal "hyprland L$linea: '$exe' no existe"
done < <(sort -u -k2 /tmp/.chk_hypr)

[ "$fallos" -eq 0 ] && ok "todos los binarios de niri e hyprland existen"

##############################################################################
titulo "1b. Acciones del menú de apagado (wlogout)"
##############################################################################
# Por aquí se colaron DOS fallos: "Salir" con `hyprctl dispatch exit` no hacía
# nada en niri, y al cambiarlo a `loginctl terminate-session` dejaba pantalla
# negra en Hyprland. Se comprueban los binarios y se avisa de los comandos
# atados a un compositor concreto.
python3 - <<'PY' > /tmp/.chk_wlog 2>/dev/null
import re
try:
    txt = open('dotfiles/wlogout/.config/wlogout/layout').read()
except OSError:
    raise SystemExit
etiqueta = None
for n, linea in enumerate(txt.splitlines(), 1):
    m = re.search(r'"label"\s*:\s*"([^"]+)"', linea)
    if m:
        etiqueta = m.group(1)
    m = re.search(r'"action"\s*:\s*"([^"]+)"', linea)
    if m:
        cmd = m.group(1)
        tok = re.findall(r'[a-zA-Z0-9_./~$-]+', cmd)
        if tok:
            print(f'{n}\t{etiqueta or "?"}\t{tok[0]}\t{cmd}')
PY

hubo_wlog=0
while IFS=$'\t' read -r linea etiqueta exe cmd; do
  [ -n "${exe:-}" ] || continue
  hubo_wlog=1
  if ! existe_bin "$exe"; then
    mal "wlogout L$linea ($etiqueta): '$exe' no existe"
  elif printf '%s' "$cmd" | grep -qE "^(hyprctl|niri) "; then
    aviso "wlogout L$linea ($etiqueta): '$cmd' solo sirve en un compositor"
  fi
done < /tmp/.chk_wlog
[ "$hubo_wlog" -eq 1 ] && [ "$fallos" -eq 0 ] && ok "acciones de wlogout correctas"

##############################################################################
titulo "2. Comandos de un compositor usados en el otro"
##############################################################################
# hyprctl/hyprshot hablan por el socket de Hyprland: en niri no hacen nada.
# Sin tubería hacia `while`: crearía una subshell y el contador de fallos
# (y con él el código de salida) se perdería al terminar el bucle.
intrusos=$(grep -nE "hyprctl|hyprshot" dotfiles/niri/.config/niri/config.kdl 2>/dev/null \
           | grep -vE "^\s*[0-9]+:\s*//")
if [ -n "$intrusos" ]; then
  while IFS= read -r l; do
    [ -n "$l" ] && mal "niri usa una herramienta de Hyprland: ${l:0:80}"
  done <<< "$intrusos"
else
  ok "niri no depende de hyprctl/hyprshot"
fi

##############################################################################
titulo "3. Rutas del store escritas a mano"
##############################################################################
# Se rompen al actualizar el paquete o cuando el GC borra la versión vieja.
encontradas=$(grep -rn "/nix/store/[a-z0-9]\{32\}" dotfiles/ 2>/dev/null | grep -v Binary)
if [ -n "$encontradas" ]; then
  while IFS= read -r l; do
    ruta=$(printf '%s' "$l" | grep -oE "/nix/store/[a-z0-9]{32}-[^\"' ]*" | head -1)
    if [ -e "$ruta" ]; then
      aviso "ruta del store fija (hoy existe, se romperá): ${l%%:*}"
    else
      mal "ruta del store MUERTA: ${l%%:*} → $ruta"
    fi
  done <<< "$encontradas"
else
  ok "ninguna ruta del store escrita a mano"
fi

##############################################################################
titulo "4. Ficheros y rutas referenciados"
##############################################################################
# Solo líneas ACTIVAS: una ruta dentro de un comentario no rompe nada.
python3 - "$HOME" <<'PY' > /tmp/.chk_rutas
import os, re, sys
home = sys.argv[1]
pat = re.compile(r'(\$HOME|~|/home/[a-z]+)/[A-Za-z0-9._/-]+')
# Falsos positivos conocidos: plantillas de nombre de fichero y frases con punto.
ignorar = re.compile(r'(screenshot_|/multimedia\.$|/Imagenes$)')
vistas = {}
for raiz, _, ficheros in os.walk('dotfiles'):
    for f in ficheros:
        ruta = os.path.join(raiz, f)
        try:
            crudo = open(ruta, 'rb').read()
        except OSError:
            continue
        # Los binarios (iconos png, sonidos...) dan coincidencias basura al
        # interpretar sus bytes como texto: se detectan por el byte nulo.
        if b'\0' in crudo[:8192]:
            continue
        lineas = crudo.decode('utf-8', errors='ignore').splitlines()
        for n, linea in enumerate(lineas, 1):
            s = linea.strip()
            if s.startswith(('#', '//', '*', '/*')):
                continue
            for m in pat.finditer(linea):
                p = m.group(0).replace('$HOME', home)
                if p.startswith('~'):
                    p = home + p[1:]
                if ignorar.search(p):
                    continue
                vistas.setdefault(p, f'{ruta}:{n}')
for p, donde in sorted(vistas.items()):
    if not os.path.exists(p):
        print(f'{p}\t{donde}')
PY

faltan=0
while IFS=$'\t' read -r p donde; do
  [ -n "${p:-}" ] || continue
  mal "referencia inexistente: $p  ($donde)"
  faltan=$((faltan+1))
done < /tmp/.chk_rutas
[ "$faltan" -eq 0 ] && ok "todas las rutas de líneas activas existen"

##############################################################################
titulo "5. Sintaxis de las configuraciones"
##############################################################################

if command -v niri >/dev/null 2>&1; then
  if niri validate -c dotfiles/niri/.config/niri/config.kdl >/dev/null 2>&1; then
    ok "niri validate"
  else
    mal "niri validate falla"
  fi
fi

# Se valida como JSONC, que es lo que waybar acepta de verdad: comentarios
# de línea (fuera de strings) y comas finales. Con json.loads a pelo daría
# fallos falsos, y un script con falsos positivos se acaba ignorando.
python3 - <<'PY' > /tmp/.chk_json
import json, os, re

def jsonc(txt):
    fuera, i, n = [], 0, len(txt)
    en_str = escape = False
    while i < n:
        c = txt[i]
        if en_str:
            fuera.append(c)
            if escape:      escape = False
            elif c == '\\': escape = True
            elif c == '"':  en_str = False
            i += 1
            continue
        if c == '"':
            en_str = True; fuera.append(c); i += 1; continue
        if txt.startswith('//', i):
            while i < n and txt[i] != '\n': i += 1
            continue
        if txt.startswith('/*', i):
            j = txt.find('*/', i + 2)
            i = n if j < 0 else j + 2
            continue
        fuera.append(c); i += 1
    limpio = ''.join(fuera)
    return re.sub(r',(\s*[}\]])', r'\1', limpio)   # comas finales

for raiz, _, ficheros in os.walk('dotfiles'):
    for f in ficheros:
        if not f.endswith(('.json', '.jsonc')):
            continue
        ruta = os.path.join(raiz, f)
        try:
            json.loads(jsonc(open(ruta, encoding='utf-8').read()))
            print(f'ok\t{ruta}')
        except Exception as e:
            print(f'mal\t{ruta}\t{e}')
PY

while IFS=$'\t' read -r estado ruta err; do
  [ -n "${estado:-}" ] || continue
  if [ "$estado" = ok ]; then ok "JSONC válido: $(basename "$ruta")"
  else mal "JSONC inválido: $ruta — $err"; fi
done < /tmp/.chk_json

for s in dotfiles/bin/bin/*; do
  [ -f "$s" ] || continue
  head -1 "$s" | grep -q "bash" || continue
  bash -n "$s" 2>/dev/null || mal "sintaxis bash: $s"
done

# Solo si Hyprland está corriendo ahora mismo.
if command -v hyprctl >/dev/null 2>&1 && hyprctl version >/dev/null 2>&1; then
  errs=$(hyprctl configerrors 2>/dev/null | grep -c "Config error" || true)
  if [ "${errs:-0}" -eq 0 ]; then
    ok "hyprctl configerrors: sin errores"
  else
    mal "hyprctl configerrors: $errs errores (ejecuta 'hyprctl configerrors')"
  fi
fi

##############################################################################
titulo "Resumen"
##############################################################################
rm -f /tmp/.chk_niri /tmp/.chk_hypr /tmp/.chk_wlog /tmp/.chk_rutas /tmp/.chk_json
if [ "$fallos" -eq 0 ]; then
  printf '  %s%d fallos%s, %d avisos\n' "$verde" "$fallos" "$fin" "$avisos"
  exit 0
else
  printf '  %s%d fallos%s, %d avisos\n' "$rojo" "$fallos" "$fin" "$avisos"
  exit 1
fi
