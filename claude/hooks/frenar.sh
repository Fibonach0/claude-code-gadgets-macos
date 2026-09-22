#!/bin/bash
# Freno de mano: revisa cada comando ANTES de que se ejecute y frena los que no
# tienen vuelta atrás (borrar datos, pisar producción, reescribir la historia
# de git). No pregunta: los frena y le explica a Claude por qué.
#
# Se engancha como hook PreToolUse con matcher "Bash". Lo demás sigue igual:
# si el comando no está en la lista, este hook no dice nada y todo continúa.
#
# Para desactivarlo un rato: FRENO=0 en ~/.config/claude-gadgets/config
export LANG=${LANG:-es_AR.UTF-8}
[ -f ~/.config/claude-gadgets/config ] && . ~/.config/claude-gadgets/config
[ "${FRENO:-1}" = 0 ] && exit 0

entrada=$(cat)
cmd=$(jq -r '.tool_input.command // empty' <<<"$entrada")
[ -z "$cmd" ] && exit 0
plano=$(tr '\n' ' ' <<<"$cmd")

frenar() {  # motivo
  jq -n --arg r "$1" '{
    hookSpecificOutput: {
      hookEventName: "PreToolUse",
      permissionDecision: "deny",
      permissionDecisionReason: ("FRENO DE MANO: " + $r + " Si de verdad hace falta, pedíselo al usuario y que lo corra él.")
    }}'
  printf '%s | %s :: %s\n' "$(date '+%d/%m %H:%M')" "$1" "$(cut -c1-120 <<<"$plano")" >> ~/.claude/estado/freno.log
  exit 0
}
# El comando se parte en tramos (&&, ||, ;, |) y cada uno se mira por separado:
# así "git commit -m 'drop table'" no se confunde con un DROP TABLE de verdad.
revisar_tramo() {
  local t="$1"
  local jefe; jefe=$(awk '{for(i=1;i<=NF;i++){if($i !~ /=/){print $i; exit}}}' <<<"$t" | sed 's|.*/||')


  # ── git: reescribir lo que ya está publicado ──────────────────────────────
  grep -qiE 'git +push.*(--force([^-]|$)|--force-with-lease|-f( |$))' <<<"$t" \
    && frenar "es un push forzado: pisa lo que ya está en el remoto y puede borrar trabajo de otros."
  grep -qiE 'git +push[^|;&]*:( *[a-z]|$)|git +push[^|;&]* --delete' <<<"$t" \
    && frenar "borra una rama del remoto."
  grep -qiE 'git +push[^|;&]* (origin +)?\+' <<<"$t" \
    && frenar "es un push forzado (con +rama), pisa el remoto."

  # ── Borrar archivos en masa ───────────────────────────────────────────────
  if grep -qE 'rm +(-[a-zA-Z]* )*-[a-zA-Z]*[rR][a-zA-Z]*f|rm +(-[a-zA-Z]* )*-[a-zA-Z]*f[a-zA-Z]*[rR]' <<<"$t"; then
    grep -qE 'rm .*(/ |/$|~/? |\$HOME/? |\*)' <<<"$t" \
      && frenar "borra en masa (rm -rf con comodín, el home o la raíz)."
  fi

  # ── Bases de datos: borrar o vaciar ───────────────────────────────────────
  case "$jefe" in git|echo|printf|cat|grep|jq) ;; *)   # texto, no SQL de verdad
    grep -qiE '(drop +(table|database|schema)|truncate +table|delete +from [a-z_.]+ *(;|$))' <<<"$t" \
    && frenar "borra o vacía datos de una base."
  grep -qiE 'supabase +db +(reset|remote +reset)|supabase +projects +delete' <<<"$t" \
    && frenar "resetea o borra un proyecto de Supabase."
  grep -qiE '\bdropdb\b|pg_restore +.*--clean' <<<"$t" \
    && frenar "borra una base de datos." ;; esac

  # ── Producción: variables, servicios, infraestructura ─────────────────────
  grep -qiE 'railway +(variables +(--set|set)|down|delete|service +delete|volume +delete)' <<<"$t" \
    && frenar "toca producción en Railway (variables, borrar servicio o volumen)."
  grep -qiE 'gh +repo +delete|gh +release +delete|gh +secret +(set|delete)' <<<"$t" \
    && frenar "borra o cambia algo del repositorio en GitHub."
  grep -qiE 'wrangler +(delete|pages +project +delete)|vercel +remove|fly +apps +destroy' <<<"$t" \
    && frenar "borra un despliegue."

  # ── Credenciales ──────────────────────────────────────────────────────────
  grep -qiE 'security +(delete-|dump-)|rm +.*\.ssh/|rm +.*\.config/claude-gadgets/token|claude +setup-token' <<<"$t" \
    && frenar "toca credenciales (llavero, claves SSH o el token)."
}

while IFS= read -r tramo; do
  tramo=$(sed -E 's/^ +| +$//g' <<<"$tramo")
  [ -n "$tramo" ] && revisar_tramo "$tramo"
done < <(sed -E 's/&&|\|\||;|\|/\n/g' <<<"$plano")

exit 0
