#!/bin/bash
# Prueba el hook que exige build de prueba antes de mergear.
H=~/.claude/hooks/prebuild-check.sh
M=~/.claude/estado/prebuild.json
repo=$HOME/proyectos/cantapp
cp "$M" /tmp/prebuild.bak

probar() {
  jq -nc --arg c "gh pr merge $1 --squash" --arg d "$repo" \
     '{tool_name:"Bash",tool_input:{command:$c},cwd:$d}' \
    | $H | jq -r '.hookSpecificOutput.permissionDecisionReason' 2>/dev/null | cut -c1-100 | grep . || echo "PASA"
}

# ¿Qué PR abierto toca el front?
pr_front=""; pr_otro=""
for n in $(gh pr list -R Fibonach0/cantapp --state all --limit 8 --json number --jq '.[].number'); do
  if gh pr diff -R Fibonach0/cantapp "$n" --name-only 2>/dev/null | grep -qE '^front/'; then
    [ -z "$pr_front" ] && pr_front=$n
  else
    [ -z "$pr_otro" ] && pr_otro=$n
  fi
done
echo "PR que toca el front: ${pr_front:-ninguno} · PR que no lo toca: ${pr_otro:-ninguno}"
echo

[ -n "$pr_otro" ] && echo "1. PR sin front (debe pasar):        $(probar "$pr_otro")"
if [ -n "$pr_front" ]; then
  echo "2. build verde y fresco (debe pasar): $(probar "$pr_front")"
  jq '.ok = false' "$M" > /tmp/m && mv /tmp/m "$M"
  echo "3. último build FALLADO (debe frenar): $(probar "$pr_front")"
  jq '.ok = true | .ts = 1000000000' "$M" > /tmp/m && mv /tmp/m "$M"
  echo "4. build viejo (debe frenar):         $(probar "$pr_front")"
  rm -f "$M"
  echo "5. sin build nunca (debe frenar):     $(probar "$pr_front")"
fi
cp /tmp/prebuild.bak "$M"
