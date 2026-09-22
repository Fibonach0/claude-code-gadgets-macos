#!/bin/bash
# Prueba el circuito: frenado → claude-permitir → pasa una vez → vuelve a frenar.
H=~/.claude/hooks/frenar.sh
P=~/.claude/gadgets/bin/claude-permitir
cmd=$(grep '^MAL|railway' "$(dirname "$0")/casos.txt" | head -1); cmd=${cmd#*|}
pedir() { jq -nc --arg c "$cmd" '{tool_name:"Bash",tool_input:{command:$c}}' | $H \
  | jq -r 'if .hookSpecificOutput.permissionDecision == "deny" then "FRENADO" else "PASA" end' 2>/dev/null | grep . || echo PASA; }

printf '1. sin autorizar      : %s\n' "$(pedir)"
"$P" >/dev/null && printf '2. autorizado         : %s\n' "$(pedir)"
printf '3. la vez siguiente   : %s\n' "$(pedir)"
"$P" >/dev/null; "$P" --cancelar >/dev/null
printf '4. autorizo y cancelo : %s\n' "$(pedir)"
echo; echo "--ver:"; "$P" --ver
