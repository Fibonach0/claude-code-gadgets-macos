#!/bin/bash
# Freno de mano: revisa cada comando ANTES de que se ejecute y frena los que no
# tienen vuelta atrás (borrar datos, pisar producción, reescribir la historia
# de git). No pregunta: los frena y le explica a Claude por qué.
#
# Se engancha como hook PreToolUse con matcher "Bash". Si el comando no está en
# la lista, el hook no dice nada y todo sigue igual.
#
# Cómo evita los falsos positivos: el comando se parte en tramos (&&, ||, ;, |)
# y en cada tramo mira QUIÉN ENCABEZA. Así "git commit -m 'drop table'" o un
# texto que menciona `rm -rf` no se confunden con la cosa real: sólo frena si el
# programa peligroso es el que realmente se está por ejecutar.
#
# Para desactivarlo un rato: FRENO=0 en ~/.config/claude-gadgets/config
export LANG=${LANG:-es_AR.UTF-8}
[ -f ~/.config/claude-gadgets/config ] && . ~/.config/claude-gadgets/config
[ "${FRENO:-1}" = 0 ] && exit 0

est=~/.claude/estado; mkdir -p "$est"
permiso="$est/freno-permiso"; ultimo="$est/freno-ultimo.json"
memoria="$est/freno-memoria.json"        # cuántas veces autorizaste cada cosa
excepciones=~/.config/claude-gadgets/freno-excepciones

entrada=$(cat)
cmd=$(jq -r '.tool_input.command // empty' <<<"$entrada")
[ -z "$cmd" ] && exit 0
plano=$(tr '\n' ' ' <<<"$cmd")

# ── LO QUE YA DIJISTE QUE SÍ ────────────────────────────────────────────────
#
# Un freno que pregunta siempre lo mismo se termina apagando entero, y ahí deja
# de proteger de lo que importa. Por eso aprende: lo que autorizaste varias
# veces se puede volver excepción fija, y el freno se queda para lo raro.
#
# Las excepciones son patrones que vos aprobaste a mano (claude-permitir
# --siempre). Una línea por patrón, y las líneas con # son comentarios.
exceptuado() {
  [ -f "$excepciones" ] || return 1
  local patron
  while IFS= read -r patron; do
    [ -z "$patron" ] && continue
    case "$patron" in \#*) continue ;; esac
    if grep -qiE -- "$patron" <<<"$plano"; then
      printf '%s | excepción «%s» :: %s\n' "$(date '+%d/%m %H:%M')" "$patron" \
        "$(cut -c1-100 <<<"$plano")" >> "$est/freno.log"
      return 0
    fi
  done < "$excepciones"
  return 1
}

# Si el usuario autorizó este comando desde el teléfono (claude-permitir),
# pasa una sola vez y dentro de los 10 minutos.
autorizado() {
  [ -f "$permiso" ] || return 1
  local guardado vence
  guardado=$(sed -n 1p "$permiso"); vence=$(sed -n 2p "$permiso")
  [ "$guardado" = "$(shasum <<<"$plano" | cut -d' ' -f1)" ] || return 1
  [ "$(date +%s)" -le "${vence:-0}" ] || return 1
  rm -f "$permiso"; return 0
}

frenar() {  # motivo
  exceptuado && exit 0
  autorizado && exit 0
  jq -n --arg r "$1" '{
    hookSpecificOutput: {
      hookEventName: "PreToolUse",
      permissionDecision: "deny",
      permissionDecisionReason: ("FRENO DE MANO: " + $r + " Si de verdad hace falta, pedíselo al usuario y que lo corra él.")
    }}'
  printf '%s | %s :: %s\n' "$(date '+%d/%m %H:%M')" "$1" "$(cut -c1-120 <<<"$plano")" >> "$est/freno.log"
  # Queda anotado para que claude-permitir pueda autorizarlo desde el celular.
  jq -n --arg c "$plano" --arg m "$1" --arg h "$(shasum <<<"$plano" | cut -d' ' -f1)" \
     '{comando:$c, motivo:$m, sha:$h, ts:(now|floor)}' > "$ultimo"
  # Aviso al celular (opcional): va sólo el motivo y el arranque del comando.
  if [ -n "$NTFY_TOPIC" ]; then
    curl -s -m 5 -H "Title: Claude frenado" -H "Priority: default" \
      -d "$1
$(cut -c1-60 <<<"$plano")
Para dejarlo pasar: atajo Permitir (vale 10 min)." "https://ntfy.sh/$NTFY_TOPIC" >/dev/null &
  fi
  exit 0
}

revisar_tramo() {
  local t="$1"
  # Quién encabeza el tramo, salteando VAR=valor, sudo, env, time.
  local jefe
  jefe=$(awk '{for(i=1;i<=NF;i++){ if($i ~ /=/ || $i=="sudo" || $i=="env" || $i=="time" || $i=="command") continue; print $i; exit }}' <<<"$t" | sed 's|.*/||')

  case "$jefe" in
    git)
      grep -qiE 'git +push.*(--force([^-]|$)|--force-with-lease|-f( |$))' <<<"$t" \
        && frenar "es un push forzado: pisa lo que ya está en el remoto y puede borrar trabajo de otros."
      grep -qiE 'git +push[^|;&]*:( *[a-z]|$)|git +push[^|;&]* --delete' <<<"$t" \
        && frenar "borra una rama del remoto."
      grep -qiE 'git +push[^|;&]* (origin +)?\+' <<<"$t" \
        && frenar "es un push forzado (con +rama), pisa el remoto."
      ;;
    rm)
      if grep -qE '^rm +(-[a-zA-Z]* )*-[a-zA-Z]*([rR][a-zA-Z]*f|f[a-zA-Z]*[rR])' <<<"$t"; then
        grep -qE 'rm .*(/ |/$|~/? |\$HOME/? |\*)' <<<"$t" \
          && frenar "borra en masa (rm -rf con comodín, el home o la raíz)."
      fi
      grep -qiE '^rm +.*(\.ssh/|claude-gadgets/token)' <<<"$t" \
        && frenar "borra credenciales (claves SSH o el token de Claude)."
      ;;
    psql|mysql|sqlite3|dropdb|pg_restore|pgcli|mongo|redis-cli)
      [ "$jefe" = dropdb ] && frenar "borra una base de datos entera."
      grep -qiE 'drop +(table|database|schema)|truncate +table|delete +from [a-z_.]+ *(;|.$)' <<<"$t" \
        && frenar "borra o vacía datos de una base."
      grep -qiE 'pg_restore.*--clean' <<<"$t" && frenar "restaura pisando la base existente."
      ;;
    supabase)
      grep -qiE 'db +(reset|remote +reset)|projects +delete|branches +delete' <<<"$t" \
        && frenar "resetea o borra algo de Supabase."
      ;;
    railway)
      grep -qiE '(variables +(--set|set)|down|delete|service +delete|volume +delete)' <<<"$t" \
        && frenar "toca producción en Railway (variables, borrar servicio o volumen)."
      ;;
    gh)
      grep -qiE 'repo +delete|release +delete|secret +(set|delete)|api +.*-X *(DELETE|PUT)' <<<"$t" \
        && frenar "borra o cambia algo del repositorio en GitHub."
      ;;
    wrangler|vercel|fly|flyctl|heroku|aws|gcloud)
      grep -qiE '(delete|destroy|remove|rm) ' <<<"$t" \
        && frenar "borra infraestructura o un despliegue."
      ;;
    security)
      grep -qiE '^security +(delete-|dump-)' <<<"$t" \
        && frenar "toca el llavero de macOS."
      ;;
    claude)
      grep -qiE '^claude +setup-token' <<<"$t" \
        && frenar "genera un token nuevo: eso lo tiene que hacer el usuario, en su terminal."
      ;;
    launchctl)
      grep -qiE 'bootout +system|disable +system' <<<"$t" && frenar "apaga servicios del sistema."
      ;;
  esac
}

while IFS= read -r tramo; do
  tramo=$(sed -E 's/^ +| +$//g' <<<"$tramo")
  # El "cd algo && …" se mira por lo que viene después del cd.
  tramo=$(sed -E 's/^cd +[^ ]+ +//' <<<"$tramo")
  [ -n "$tramo" ] && revisar_tramo "$tramo"
done < <(sed -E 's/&&|\|\||;|\|/\n/g' <<<"$plano")

exit 0
