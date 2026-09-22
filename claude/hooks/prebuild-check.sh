#!/bin/bash
# Antes de mergear un PR que toca el front, exige un build de prueba verde en el
# volumen sensible a mayúsculas (claude-prebuild). Así no se repite el caso de
# un import con el case equivocado: compila en la Mac, rompe en Linux, el merge
# pasa igual y producción queda vieja en silencio.
#
# Se engancha como hook PreToolUse con   "if": "Bash(gh pr merge:*)"
#
# Config en ~/.config/claude-gadgets/config:
#   PREBUILD_PATRON="^front/"   # qué rutas del PR cuentan como front
#   PREBUILD_CHECK=0            # lo desactiva
export PATH="$HOME/.local/bin:/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin"
export LANG=${LANG:-es_AR.UTF-8}
[ -f ~/.config/claude-gadgets/config ] && . ~/.config/claude-gadgets/config
[ "${PREBUILD_CHECK:-1}" = 0 ] && exit 0

entrada=$(cat)
cmd=$(jq -r '.tool_input.command // empty' <<<"$entrada")
pr=$(grep -oE 'gh +pr +merge +[0-9]+' <<<"$cmd" | grep -oE '[0-9]+$')
[ -z "$pr" ] && exit 0                      # merge sin número: no me meto
cwd=$(jq -r '.cwd // empty' <<<"$entrada"); cd "${cwd:-.}" 2>/dev/null || exit 0

archivos=$(gh pr diff "$pr" --name-only 2>/dev/null) || exit 0
grep -qE "${PREBUILD_PATRON:-^front/}" <<<"$archivos" || exit 0   # no toca el front

marca=~/.claude/estado/prebuild.json
frenar() {
  jq -n --arg r "$1" '{hookSpecificOutput: {hookEventName:"PreToolUse", permissionDecision:"deny",
    permissionDecisionReason: ("ANTES DE MERGEAR: " + $r)}}'
  exit 0
}
[ -f "$marca" ] || frenar "el PR #$pr toca el front y todavía no corriste el build de prueba. Corré claude-prebuild (tarda ~40 s): compila en un volumen sensible a mayúsculas, como Linux, y caza los imports que en la Mac pasan."

ok=$(jq -r '.ok' "$marca"); ts=$(jq -r '.ts' "$marca"); cuando=$(jq -r '.cuando' "$marca")
[ "$ok" = true ] || frenar "el último build de prueba ($cuando) FALLÓ. Arreglá eso antes de mergear: lo que falla ahí es lo que va a fallar en producción."

# El build tiene que ser posterior al último commit de la rama del PR.
rama=$(gh pr view "$pr" --json headRefName --jq .headRefName 2>/dev/null)
ultimo=$(git log -1 --format=%ct "origin/$rama" 2>/dev/null || echo 0)
if [ "$ts" -lt "$ultimo" ]; then
  frenar "el build de prueba ($cuando) es anterior al último commit de $rama. Volvé a correr claude-prebuild así prueba lo que estás por mergear."
fi
exit 0
