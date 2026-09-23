#!/bin/bash
# El guardián no debe esperar un cambio de bundle cuando lo que se mergeó NO
# toca el front: eso daba una falsa alarma ("sigue el bundle viejo") con
# cualquier PR de SQL o de backend. Pasó de verdad el 23/09.
#
# Corre contra un repo de mentira y una config y un estado propios: no toca
# nada tuyo.
set -u
G=${G:-$HOME/.claude/gadgets/bin/claude-guardia}
tmp=$(mktemp -d)
repo="$tmp/repo"
export CLAUDE_ESTADO="$tmp/estado"; mkdir -p "$CLAUDE_ESTADO"
export CLAUDE_GADGETS_CONF="$tmp/config"
trap 'rm -rf "$tmp"' EXIT

git init -q "$repo"
(cd "$repo" && git config user.email x@x && git config user.name x \
  && mkdir -p front/src backend && echo a > front/src/app.js && echo b > backend/api.py \
  && git add -A && git commit -qm base && git branch -M main \
  && git remote add origin "$repo" && git update-ref refs/remotes/origin/main HEAD)

cat > "$CLAUDE_GADGETS_CONF" <<CONF
GUARDIA=("prueba|$repo|http://127.0.0.1:9/|bundle")
GUARDIA_PATRON='^front/'
GUARDIA_ESPERA=15
CONF

esperando() { jq -r '.prueba.desde // ""' "$CLAUDE_ESTADO/guardia.json" 2>/dev/null; }
avanzar() {  # commit + mover origin/main, y correr el guardián
  (cd "$repo" && git commit -qam "$1" && git update-ref refs/remotes/origin/main HEAD)
  "$G" >/dev/null 2>&1
}

"$G" >/dev/null 2>&1        # primera pasada: sólo saca la foto
echo "0. primera pasada                  : $([ -z "$(esperando)" ] && echo "ok, no espera" || echo FALLA)"

(cd "$repo" && echo c >> backend/api.py)
avanzar "sólo backend"
echo "1. commit que NO toca el front     : $([ -z "$(esperando)" ] && echo "ok, no espera" || echo "FALLA: quedó esperando")"

(cd "$repo" && echo d >> front/src/app.js)
avanzar "toca el front"
echo "2. commit que SÍ toca el front     : $([ -n "$(esperando)" ] && echo "ok, espera el deploy" || echo "FALLA: no esperó")"
