#!/bin/bash
# Hook de avisos: notificación + sonido en la Mac, y deja el estado de cada
# sesión en ~/.claude/estado/ para el widget de la barra de menú (SwiftBar).
# Uso: avisar.sh <prompt|necesita|listo|fin>   (JSON del hook por stdin)
evento="$1"
input=$(cat)
sid=$(jq -r '.session_id // "x"' <<<"$input")
cwd=$(jq -r '.cwd // ""' <<<"$input")
msg=$(jq -r '.message // empty' <<<"$input")
proyecto=$(basename "${cwd:-?}")
dir=~/.claude/estado; mkdir -p "$dir"
f="$dir/sesion-$sid.json"

guardar() { jq -n --arg e "$1" --arg p "$proyecto" --arg c "$cwd" --arg m "$msg" \
  '{estado:$e, proyecto:$p, cwd:$c, mensaje:$m, ts:(now|floor)}' > "$f"; }

# Sólo aviso si no estás mirando la terminal (o el editor) donde corre Claude.
frente=$(lsappinfo info -only name "$(lsappinfo front)" 2>/dev/null | sed 's/.*="\(.*\)"/\1/')
case "$TERM_PROGRAM" in
  iTerm.app) mia="iTerm2" ;;  Apple_Terminal|"") mia="Terminal" ;;
  vscode) mia="Code" ;;       ghostty) mia="Ghostty" ;;  WarpTerminal) mia="Warp" ;;
  *) mia="$TERM_PROGRAM" ;;
esac
avisar() {  # titulo, texto, sonido[, "urgente"]
  [ "$frente" = "$mia" ] && return
  # En horario de silencio sólo pasa lo que te está bloqueando.
  declare -f en_silencio >/dev/null && en_silencio "${4:-}" && return
  # osascript en segundo plano: un hook nunca debe quedar colgado esperando.
  # (terminal-notifier se cuelga en este macOS, por eso no se usa.)
  local t=${1//\"/\'} m=${2//\"/\'}
  osascript -e "display notification \"$m\" with title \"$t\" sound name \"$3\"" \
    >/dev/null 2>&1 &
  disown
}

case "$evento" in
  prompt)   guardar trabajando ;;
  necesita) guardar esperando; avisar "Claude · $proyecto" "${msg:-Te necesita}" Glass urgente ;;
  listo)    guardar listo;     avisar "Claude · $proyecto" "Terminó" Hero ;;
  fin)      rm -f "$f" ;;
esac
# Limpio sesiones viejas (más de 1 día sin actividad).
find "$dir" -name 'sesion-*.json' -mtime +1 -delete 2>/dev/null
exit 0
