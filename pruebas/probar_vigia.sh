#!/bin/bash
# El vigía contra un repo de mentira con cada caso: cambios sin commitear desde
# hace rato, commits sin pushear, una rama vieja sin mergear y un worktree
# abierto. No toca tus repos ni tu configuración.
set -u
V=${V:-$HOME/.claude/gadgets/bin/claude-vigia}
tmp=$(mktemp -d); trap 'rm -rf "$tmp"' EXIT
export CLAUDE_ESTADO="$tmp/estado"; mkdir -p "$CLAUDE_ESTADO"
export CLAUDE_GADGETS_CONF="$tmp/config"

remoto="$tmp/remoto.git"; repo="$tmp/repo"
git init -q --bare "$remoto"
git clone -q "$remoto" "$repo" 2>/dev/null
cd "$repo"
git config user.email x@x; git config user.name x
echo uno > a.txt; git add -A; git commit -qm base; git branch -M main
git push -q -u origin main
git update-ref refs/remotes/origin/HEAD refs/remotes/origin/main

# 1. una rama vieja sin mergear (fechada hace 30 días)
git checkout -q -b vieja
echo dos > b.txt; git add -A
# macOS no entiende "30 days ago" como fecha de git: hay que darle ISO.
hace30=$(date -v-30d -u +%Y-%m-%dT%H:%M:%S)
GIT_AUTHOR_DATE="$hace30" GIT_COMMITTER_DATE="$hace30" git commit -qm "algo viejo"
git checkout -q main

# 2. commits sin pushear
echo tres > c.txt; git add -A; git commit -qm "sin pushear"

# 3. cambios sin commitear, tocados hace 6 horas
echo cuatro > d.txt
touch -t "$(date -v-6H +%Y%m%d%H%M)" d.txt

# 4. un worktree abierto
git worktree add -q "$tmp/wt" vieja

cat > "$CLAUDE_GADGETS_CONF" <<CONF
VIGIA_REPOS=("$repo")
VIGIA_HORAS=4
VIGIA_RAMAS=14
CONF

salida=$("$V")
printf '%s\n\n' "$salida"
ok=0; mal=0
mirar() {  # qué debería aparecer, texto a buscar
  if grep -qi "$2" <<<"$salida"; then ok=$((ok+1)); printf '  ok    %s\n' "$1"
  else mal=$((mal+1)); printf '  FALLA %s\n' "$1"; fi
}
mirar "avisa de archivos sin commitear" "sin commitear"
mirar "avisa de commits sin pushear"    "sin pushear"
mirar "avisa de la rama vieja"          "vieja"
mirar "avisa del worktree"              "worktree"
echo; echo "aciertos: $ok   errores: $mal"
