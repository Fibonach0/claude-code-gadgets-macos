#!/bin/bash
# Qué frena el detector de credenciales y qué deja pasar.
#
# Los casos viven en casos-secretos.txt (formato: MAL|archivo|texto) para no
# tener que escribir claves de mentira en la línea de comandos, donde el propio
# hook las vería pasar.
set -u
H=${H:-$HOME/.claude/hooks/secretos.sh}
casos=$(cd "$(dirname "$0")" && pwd)/casos-secretos.txt   # absoluto: después se hace cd
tmp=$(mktemp -d); trap 'rm -rf "$tmp"' EXIT
git init -q "$tmp/repo"; mkdir -p "$tmp/afuera"

# Las credenciales de prueba se arman acá, al azar, y mueren con el mktemp: el
# repositorio nunca guarda algo con pinta de clave (el escáner de GitHub frena
# un push que las tenga escritas, y tiene razón).
azar() { LC_ALL=C tr -dc 'A-Za-z0-9' < /dev/urandom | head -c "$1"; }
ANTHROPIC="sk-ant-api03-$(azar 40)"
AWS="AKIA$(LC_ALL=C tr -dc 'A-Z0-9' < /dev/urandom | head -c 16)"
GITHUB="ghp_$(azar 36)"
SLACK="xoxb-$(azar 12)-$(azar 12)-$(azar 24)"
GOOGLE="AIza$(azar 35)"
SUPABASE="sb_secret_$(azar 24)"
JWT="eyJ$(azar 24).eyJ$(azar 32).$(azar 43)"
CLAVE="$(azar 16)"
armar() {  # reemplaza las marcas por las claves de esta corrida
  sed -e "s|%ANTHROPIC%|$ANTHROPIC|g" -e "s|%AWS%|$AWS|g" -e "s|%GITHUB%|$GITHUB|g" \
      -e "s|%SLACK%|$SLACK|g" -e "s|%GOOGLE%|$GOOGLE|g" -e "s|%SUPABASE%|$SUPABASE|g" \
      -e "s|%JWT%|$JWT|g" -e "s|%CLAVE%|$CLAVE|g"
}

ok=0; mal=0
while IFS='|' read -r esperado archivo texto; do
  [ -z "${esperado:-}" ] && continue
  case "$esperado" in \#*|COMMIT) continue ;; esac   # COMMIT se prueba aparte, abajo
  ruta="$tmp/$archivo"
  mkdir -p "$(dirname "$ruta")"
  texto=$(armar <<<"$texto")
  salida=$(jq -nc --arg f "$ruta" --arg c "$texto" \
     '{tool_name:"Write", tool_input:{file_path:$f, content:$c}}' \
    | "$H" | jq -r '.hookSpecificOutput.permissionDecision // "pasa"' 2>/dev/null)
  real=$([ "$salida" = deny ] && echo MAL || echo BIEN)
  if [ "$real" = "$esperado" ]; then ok=$((ok+1)); e="ok   "
  else mal=$((mal+1)); e="FALLA"; fi
  printf '  %s %-5s %-28s %s\n' "$e" "$esperado" "$archivo" "$(cut -c1-46 <<<"$texto")"
done < "$casos"

# Y el segundo momento: algo ya puesto en el stage, a punto de commitearse.
cd "$tmp/repo"
grep '^COMMIT|' "$casos" | head -1 | cut -d'|' -f3 | armar > config.py
git add config.py
salida=$(jq -nc --arg d "$tmp/repo" '{tool_name:"Bash", tool_input:{command:"git commit -m test"}, cwd:$d}' \
  | "$H" | jq -r '.hookSpecificOutput.permissionDecision // "pasa"' 2>/dev/null)
if [ "$salida" = deny ]; then ok=$((ok+1)); echo "  ok    MAL   git commit con la clave en el stage"
else mal=$((mal+1)); echo "  FALLA MAL   git commit con la clave en el stage"; fi

echo; echo "aciertos: $ok   errores: $mal"
