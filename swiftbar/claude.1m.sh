#!/bin/bash
# <swiftbar.title>Claude Code</swiftbar.title>
# <swiftbar.hideRunInTerminal>true</swiftbar.hideRunInTerminal>
# <swiftbar.hideDisablePlugin>true</swiftbar.hideDisablePlugin>
# Barra de menú: % de uso de la sesión (ventana de 5 h) y semanal de Claude,
# sesiones que te esperan, y (opcional) si tu servicio responde.
#
# El uso lo deja ~/.claude/statusline.sh en ~/.claude/estado/uso.json cada vez
# que corre una sesión de Claude Code; las sesiones las deja hooks/avisar.sh.
export PATH=/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin
est=~/.claude/estado
conf=~/.config/claude-gadgets/config
[ -f "$conf" ] && . "$conf"      # HUB_URL, HUB_NOMBRE, LINKS
ahora=$(date +%s)

# ── Uso ──────────────────────────────────────────────────────────────────────
uso="$est/uso.json"
[ -f "$uso" ] || uso="$est/statusline-ultimo.json"
leer() { [ -f "$uso" ] && jq -r "$1 // empty" "$uso" 2>/dev/null; }
p5=$(leer '.rate_limits.five_hour.used_percentage');  r5=$(leer '.rate_limits.five_hour.resets_at')
p7=$(leer '.rate_limits.seven_day.used_percentage');  r7=$(leer '.rate_limits.seven_day.resets_at')
ts=$(leer '.ts'); [ -z "$ts" ] && [ -f "$uso" ] && ts=$(stat -f %m "$uso")

a_epoch() {  # resets_at puede venir en epoch o ISO-8601
  case "$1" in ''|*[!0-9]*) [ -n "$1" ] && date -j -u -f '%Y-%m-%dT%H:%M:%S' "${1%%.*}" +%s 2>/dev/null ;;
                *) echo "$1" ;; esac; }
r5=$(a_epoch "$r5"); r7=$(a_epoch "$r7")
# Si la ventana ya se renovó desde el último dato, el uso volvió a 0.
[ -n "$r5" ] && [ "$ahora" -ge "$r5" ] && p5=0 && r5=""
[ -n "$r7" ] && [ "$ahora" -ge "$r7" ] && p7=0 && r7=""

n() { printf '%.0f' "${1:-0}"; }
barra() { local v; v=$(n "$1"); local l=$(( v / 10 )) i s=""
  for i in 1 2 3 4 5 6 7 8 9 10; do [ $i -le $l ] && s+="▰" || s+="▱"; done; printf '%s' "$s"; }
col() { local v; v=$(n "$1"); [ "$v" -ge 80 ] && echo "#E03131" && return
        [ "$v" -ge 50 ] && echo "#E8590C" && return; echo ""; }
cuando() {  # "hoy 14:00" / "lun 09:00"
  [ -z "$1" ] && return
  if [ "$(date -r "$1" +%F)" = "$(date +%F)" ]; then date -r "$1" +"hoy %H:%M"
  else LC_TIME=es_AR.UTF-8 date -r "$1" +"%a %d %H:%M"; fi; }

# ── Sesiones ─────────────────────────────────────────────────────────────────
esperan=0; trabajan=0; lineas=""
for f in "$est"/sesion-*.json; do
  [ -f "$f" ] || continue
  e=$(jq -r .estado "$f"); p=$(jq -r .proyecto "$f"); t=$(jq -r .ts "$f")
  m=$(jq -r '.mensaje // "" | gsub("[\n|]";" ")' "$f")
  edad=$(( (ahora - t) / 60 ))
  [ "$e" = trabajando ] && [ $edad -gt 120 ] && continue   # sesión colgada
  case $e in
    esperando)  esperan=$((esperan+1));   ic="🟠";;
    trabajando) trabajan=$((trabajan+1)); ic="⚙️";;
    *) ic="✅";;
  esac
  lineas+="$ic $p — $e (hace ${edad}m) | bash=/usr/bin/open param1=-a param2=Terminal terminal=false"$'\n'
  [ -n "$m" ] && [ "$e" = esperando ] && lineas+="--$m"$'\n'
done

# ── Servicio propio (opcional) ───────────────────────────────────────────────
hub=""
[ -n "$HUB_URL" ] && hub=$(curl -s -m 5 -o /dev/null -w '%{http_code}' -H 'Accept: text/plain' "$HUB_URL")

# ── Título ───────────────────────────────────────────────────────────────────
titulo="✳︎"
[ -n "$p5$p7" ] && titulo="✳︎ $(n "$p5")% · $(n "$p7")%"
[ $esperan -gt 0 ] && titulo="$titulo  🟠$esperan"
c=$(col "$(printf '%s\n%s\n' "${p5:-0}" "${p7:-0}" | sort -n | tail -1)")
[ $esperan -gt 0 ] && c="#E8590C"
echo "$titulo |${c:+ color=$c}"
[ -n "$hub" ] && [ "$hub" != 200 ] && echo "${HUB_NOMBRE:-Servicio} caído ($hub) | color=red"
echo "---"

# ── Menú ─────────────────────────────────────────────────────────────────────
echo "Uso de Claude | size=11 color=gray"
if [ -n "$p5$p7" ]; then
  c5=$(col "$p5"); c7=$(col "$p7")
  echo "Sesión (5 h)   $(barra "$p5")  $(n "$p5")% | font=Menlo${c5:+ color=$c5}"
  [ -n "$r5" ] && echo "--Se renueva $(cuando "$r5")"
  echo "Semana (7 d)   $(barra "$p7")  $(n "$p7")% | font=Menlo${c7:+ color=$c7}"
  [ -n "$r7" ] && echo "--Se renueva $(cuando "$r7")"
  [ -n "$ts" ] && echo "Dato de hace $(( (ahora - ts) / 60 )) min (se actualiza al usar Claude Code) | size=11 color=gray"
else
  echo "Sin datos todavía: abrí una sesión de Claude Code | color=gray"
fi
echo "---"
echo "Sesiones | size=11 color=gray"
[ -n "$lineas" ] && printf '%s' "$lineas" || echo "Ninguna activa | color=gray"
if [ -n "$HUB_URL" ]; then
  echo "---"
  [ "$hub" = 200 ] && echo "🟢 ${HUB_NOMBRE:-Servicio}: OK | href=$HUB_URL" \
                   || echo "🔴 ${HUB_NOMBRE:-Servicio}: ${hub:-sin respuesta} | href=$HUB_URL"
fi
for l in "${LINKS[@]}"; do echo "${l%%=*} | href=${l#*=}"; done
echo "---"
echo "Ver uso en claude.ai | href=https://claude.ai/settings/usage"
echo "Limpiar sesiones colgadas | bash=$HOME/.claude/gadgets/bin/claude-limpiar-estado terminal=false refresh=true"
echo "Refrescar | refresh=true"
