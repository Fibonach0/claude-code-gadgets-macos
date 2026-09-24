#!/bin/bash
# El horario de no molestar: qué calla y qué deja pasar igual.
set -u
S=${S:-$HOME/.claude/gadgets/bin/silencio.sh}
ok=0; mal=0
mirar() {  # descripción, esperado (calla|suena)
  local real; if en_silencio "${3:-}"; then real=calla; else real=suena; fi
  if [ "$real" = "$2" ]; then ok=$((ok+1)); printf '  ok    %-46s %s\n' "$1" "$real"
  else mal=$((mal+1)); printf '  FALLA %-46s %s (esperaba %s)\n' "$1" "$real" "$2"; fi
}

hora_actual=$(date +%-H)
. "$S"

# Ventana que cruza la medianoche y contiene la hora actual.
SILENCIO_DESDE=$(( (hora_actual + 23) % 24 )); SILENCIO_HASTA=$(( (hora_actual + 2) % 24 ))
SILENCIO_DIAS=""; SILENCIO=1
mirar "dentro del horario de silencio" calla
mirar "dentro del horario, pero urgente" suena urgente

# Ventana que NO contiene la hora actual.
SILENCIO_DESDE=$(( (hora_actual + 3) % 24 )); SILENCIO_HASTA=$(( (hora_actual + 5) % 24 ))
mirar "fuera del horario" suena

# Día entero silenciado.
SILENCIO_DIAS=$(LC_TIME=C date +%a | tr 'A-Z' 'a-z' | sed 's/mon/lun/;s/tue/mar/;s/wed/mie/;s/thu/jue/;s/fri/vie/;s/sat/sab/;s/sun/dom/')
mirar "día entero en la lista de silencio" calla
mirar "ese día, pero urgente" suena urgente
SILENCIO_DIAS=""

# Apagado del todo.
SILENCIO=0; SILENCIO_DESDE=$(( (hora_actual + 23) % 24 )); SILENCIO_HASTA=$(( (hora_actual + 2) % 24 ))
mirar "con SILENCIO=0 no calla nunca" suena

echo; echo "aciertos: $ok   errores: $mal"
