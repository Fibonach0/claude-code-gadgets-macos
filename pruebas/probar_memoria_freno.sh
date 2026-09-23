#!/bin/bash
# El freno que aprende: autorizar tres veces sugiere fijarlo, --siempre lo fija,
# --olvidar lo saca. Todo contra archivos de prueba, sin tocar tu config real.
H=~/.claude/hooks/frenar.sh
P=~/.claude/gadgets/bin/claude-permitir
EXC=~/.config/claude-gadgets/freno-excepciones
MEM=~/.claude/estado/freno-memoria.json
cmd=$(grep '^MAL|railway' "$(dirname "$0")/casos.txt" | head -1); cmd=${cmd#*|}

# Respaldo de lo que exista, para dejar todo como estaba.
resp=$(mktemp -d)
[ -f "$EXC" ] && cp "$EXC" "$resp/exc"
[ -f "$MEM" ] && cp "$MEM" "$resp/mem"
restaurar() {
  [ -f "$resp/exc" ] && cp "$resp/exc" "$EXC" || rm -f "$EXC"
  [ -f "$resp/mem" ] && cp "$resp/mem" "$MEM" || rm -f "$MEM"
  rm -rf "$resp"
}
trap restaurar EXIT
rm -f "$EXC"; echo '{}' > "$MEM"

pedir() { jq -nc --arg c "$cmd" '{tool_name:"Bash",tool_input:{command:$c}}' | $H \
  | jq -r 'if .hookSpecificOutput.permissionDecision == "deny" then "FRENADO" else "PASA" end' 2>/dev/null | grep . || echo PASA; }

echo "1. de entrada                 : $(pedir)"
"$P" >/dev/null; "$P" >/dev/null
sugerencia=$("$P" | grep -c "claude-permitir --siempre")
echo "2. a la tercera lo sugiere    : $([ "$sugerencia" -ge 1 ] && echo SI || echo NO)"
"$P" --siempre >/dev/null
echo "3. con la excepción fija      : $(pedir)"
echo "4. la excepción quedó anotada : $("$P" --lista | head -1)"
"$P" --olvidar 1 >/dev/null
echo "5. después de olvidarla       : $(pedir)"
