# silencio.sh — el horario en que los gadgets no te molestan.
#
# No es un script: lo cargan los demás con `source`, y cada uno pregunta
# `en_silencio` antes de mandar una notificación.
#
# Config en ~/.config/claude-gadgets/config:
#   SILENCIO_DESDE=22      # de 22:00…
#   SILENCIO_HASTA=8       # …a 8:00 (cruza la medianoche sin problema)
#   SILENCIO_DIAS="sab dom"  # días enteros en silencio
#   SILENCIO=0             # apaga el modo no molestar
#
# Lo urgente igual suena: un servicio caído a las 3 de la mañana sigue siendo
# noticia. Cada gadget decide qué es urgente pasando "urgente" como segundo
# argumento; en el silencio, lo demás queda anotado en el log y listo.

en_silencio() {   # $1 = "urgente" para pasar igual
  [ "${SILENCIO:-1}" = 0 ] && return 1
  [ "${1:-}" = urgente ] && return 1

  local hoy hora desde hasta
  hoy=$(LC_TIME=C date +%a | tr 'A-Z' 'a-z')     # mon, tue, sat…
  case "$hoy" in
    mon) hoy=lun ;; tue) hoy=mar ;; wed) hoy=mie ;; thu) hoy=jue ;;
    fri) hoy=vie ;; sat) hoy=sab ;; sun) hoy=dom ;;
  esac
  for d in ${SILENCIO_DIAS:-}; do
    [ "$(tr 'A-Z' 'a-z' <<<"$d" | cut -c1-3)" = "$hoy" ] && return 0
  done

  hora=$(date +%-H)
  desde=${SILENCIO_DESDE:-22}; hasta=${SILENCIO_HASTA:-8}
  if [ "$desde" -lt "$hasta" ]; then
    [ "$hora" -ge "$desde" ] && [ "$hora" -lt "$hasta" ] && return 0
  else
    # Cruza la medianoche: 22 → 8 es "de 22 en adelante O antes de las 8".
    { [ "$hora" -ge "$desde" ] || [ "$hora" -lt "$hasta" ]; } && return 0
  fi
  return 1
}
