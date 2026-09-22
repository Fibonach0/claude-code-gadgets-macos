#!/bin/bash
# Corre los casos de casos.txt contra el hook y dice si acertó.
S=$(dirname "$0")
ok=0; mal=0
while IFS='|' read -r esperado comando; do
  [ -z "$comando" ] && continue
  salida=$(jq -nc --arg c "$comando" '{tool_name:"Bash",tool_input:{command:$c}}' \
    | ~/.claude/hooks/frenar.sh | jq -r '.hookSpecificOutput.permissionDecision // "pasa"')
  if [ "$esperado" = MAL ]; then real=$([ "$salida" = deny ] && echo MAL || echo BIEN)
  else real=$([ "$salida" = deny ] && echo MAL || echo BIEN); fi
  if [ "$real" = "$esperado" ]; then ok=$((ok+1)); estado="ok  "
  else mal=$((mal+1)); estado="FALLA"; fi
  printf '  %s %-6s %s\n' "$estado" "$esperado" "$comando"
done < "$S/casos.txt"
echo
echo "aciertos: $ok   errores: $mal"
