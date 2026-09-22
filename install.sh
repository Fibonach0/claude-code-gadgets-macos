#!/bin/bash
# Claude Code Gadgets — instalador para macOS.
#   ./install.sh                 instala todo
#   ./install.sh --con-permisos  además permite comandos de sólo lectura sin preguntar
#   ./install.sh --sin-barra     no instala SwiftBar ni el widget de la barra de menú
#   ./install.sh --sin-finder    no instala la acción rápida de Finder
# Se puede correr de nuevo sin problema: reemplaza lo suyo y no toca lo demás.
set -euo pipefail

AQUI="$(cd "$(dirname "$0")" && pwd)"
CLAUDE_DIR="$HOME/.claude"
GADGETS="$CLAUDE_DIR/gadgets"
SETTINGS="$CLAUDE_DIR/settings.json"
CONF_DIR="$HOME/.config/claude-gadgets"

CON_PERMISOS=0; SIN_BARRA=0; SIN_FINDER=0
for a in "$@"; do case "$a" in
  --con-permisos) CON_PERMISOS=1 ;;
  --sin-barra)    SIN_BARRA=1 ;;
  --sin-finder)   SIN_FINDER=1 ;;
  -h|--help) sed -n 2,7p "$0"; exit 0 ;;
  *) echo "Opción desconocida: $a"; exit 1 ;;
esac; done

ok()   { printf '  \033[32m✓\033[0m %s\n' "$*"; }
paso() { printf '\n\033[1m%s\033[0m\n' "$*"; }
ojo()  { printf '  \033[33m!\033[0m %s\n' "$*"; }

[ "$(uname)" = Darwin ] || { echo "Esto es sólo para macOS."; exit 1; }

# ── 1. Dependencias ──────────────────────────────────────────────────────────
paso "1. Dependencias"
command -v claude >/dev/null || [ -x "$HOME/.local/bin/claude" ] \
  || ojo "No encontré Claude Code. Instalalo primero: https://claude.com/claude-code"
if ! command -v brew >/dev/null; then
  ojo "Falta Homebrew (https://brew.sh). Sin él no puedo instalar SwiftBar."
  command -v jq >/dev/null || { echo "Tampoco hay jq. Instalá Homebrew y volvé a correr."; exit 1; }
else
  command -v jq >/dev/null || brew install jq
  if [ $SIN_BARRA = 0 ] && [ ! -d /Applications/SwiftBar.app ]; then
    brew install --cask swiftbar
  fi
fi
ok "jq $(jq --version)"

# ── 2. Scripts ───────────────────────────────────────────────────────────────
paso "2. Scripts"
mkdir -p "$GADGETS/bin" "$GADGETS/swiftbar" "$CLAUDE_DIR/hooks" "$CLAUDE_DIR/estado"
respaldar() {  # guarda una copia si existe y es distinto
  if [ -f "$2" ] && ! cmp -s "$1" "$2"; then cp "$2" "$2.bak-$(date +%Y%m%d%H%M%S)"; ojo "Respaldé tu $(basename "$2") anterior"; fi
}
respaldar "$AQUI/claude/statusline.sh" "$CLAUDE_DIR/statusline.sh"
install -m 755 "$AQUI/claude/statusline.sh" "$CLAUDE_DIR/statusline.sh"
respaldar "$AQUI/claude/hooks/avisar.sh" "$CLAUDE_DIR/hooks/avisar.sh"
install -m 755 "$AQUI/claude/hooks/avisar.sh" "$CLAUDE_DIR/hooks/avisar.sh"
install -m 755 "$AQUI/claude/hooks/frenar.sh" "$CLAUDE_DIR/hooks/frenar.sh"
install -m 755 "$AQUI/claude/hooks/prebuild-check.sh" "$CLAUDE_DIR/hooks/prebuild-check.sh"
for f in "$AQUI"/bin/*; do install -m 755 "$f" "$GADGETS/bin/"; done
mkdir -p "$HOME/.local/bin"
for c in claude-siri claude-estado claude-guardia claude-buzon claude-anotar claude-permitir claude-jobs claude-prebuild; do
  ln -sf "$GADGETS/bin/$c" "$HOME/.local/bin/$c"
done
ok "statusline, hooks y comandos en $GADGETS/bin (claude-siri en ~/.local/bin)"

mkdir -p "$CONF_DIR"
if [ ! -f "$CONF_DIR/config" ]; then cp "$AQUI/config/config.ejemplo" "$CONF_DIR/config"; ok "Config creada: $CONF_DIR/config"
else ok "Config existente respetada: $CONF_DIR/config"; fi

# ── 3. settings.json ─────────────────────────────────────────────────────────
paso "3. Configuración de Claude Code"
[ -f "$SETTINGS" ] || echo '{}' > "$SETTINGS"
jq empty "$SETTINGS" 2>/dev/null || { echo "Tu $SETTINGS no es JSON válido; arreglalo y reintentá."; exit 1; }
cp "$SETTINGS" "$SETTINGS.bak-$(date +%Y%m%d%H%M%S)"
permisos='[]'; [ $CON_PERMISOS = 1 ] && permisos=$(cat "$AQUI/config/permisos-lectura.json")
tmp=$(mktemp)
jq --argjson eventos "$(cat "$AQUI/config/hooks.json")" --argjson permisos "$permisos" '
  .statusLine = {type:"command", command:"~/.claude/statusline.sh", padding:0}
  | .hooks = (.hooks // {})
  | .hooks.PreToolUse = (
      [ (.hooks.PreToolUse // [])[]
        | .hooks = [ .hooks[] | select((.command // "") | test("hooks/(frenar|prebuild-check)\\.sh") | not) ]
        | select(.hooks | length > 0) ]
      + [ {matcher:"Bash", hooks:[
            {type:"command", command:"~/.claude/hooks/frenar.sh", timeout:10},
            {type:"command", command:"~/.claude/hooks/prebuild-check.sh", if:"Bash(gh pr merge:*)", timeout:60}]} ])
  | reduce ($eventos | to_entries[]) as $e (.;
      .hooks[$e.key] = (
        [ (.hooks[$e.key] // [])[]
          | .hooks = [ .hooks[] | select((.command // "") | contains("hooks/avisar.sh") | not) ]
          | select(.hooks | length > 0) ]
        + [ {hooks:[{type:"command", command:("~/.claude/hooks/avisar.sh " + $e.value), timeout:5}]} ]
      ))
  | if ($permisos | length) > 0
    then .permissions.allow = ((.permissions.allow // []) + $permisos | unique) else . end
' "$SETTINGS" > "$tmp" && mv "$tmp" "$SETTINGS"
ok "statusLine y hooks (avisos + freno de mano en PreToolUse) en settings.json"
[ $CON_PERMISOS = 1 ] && ok "Permisos de sólo lectura agregados ($(jq length "$AQUI/config/permisos-lectura.json"))"
ok "Respaldo: $SETTINGS.bak-*"

# ── 4. Barra de menú ─────────────────────────────────────────────────────────
if [ $SIN_BARRA = 0 ]; then
  paso "4. Barra de menú (SwiftBar)"
  install -m 755 "$AQUI/swiftbar/claude.1m.sh" "$GADGETS/swiftbar/claude.1m.sh"
  dir_plugins=$(defaults read com.ameba.SwiftBar PluginDirectory 2>/dev/null || true)
  if [ -z "$dir_plugins" ]; then
    defaults write com.ameba.SwiftBar PluginDirectory "$GADGETS/swiftbar"
    dir_plugins="$GADGETS/swiftbar"
    ok "Carpeta de plugins de SwiftBar: $dir_plugins"
  elif [ "$dir_plugins" != "$GADGETS/swiftbar" ]; then
    mkdir -p "$dir_plugins"
    ln -sf "$GADGETS/swiftbar/claude.1m.sh" "$dir_plugins/claude.1m.sh"
    ok "Plugin enlazado en tu carpeta de SwiftBar: $dir_plugins"
    otros=$(ls "$dir_plugins"/claude.*.sh 2>/dev/null | grep -v '/claude.1m.sh$' || true)
    [ -n "$otros" ] && ojo "Hay otro plugin de Claude que va a duplicar el ícono: $otros (borralo si sobra)"
  fi
  defaults write com.ameba.SwiftBar SUHasLaunchedBefore -bool true 2>/dev/null || true
  if [ -d /Applications/SwiftBar.app ]; then
    open -g -a SwiftBar && ok "SwiftBar abierto: vas a ver ✳︎ con el % de sesión · semana"
  fi
fi

# ── 5. Finder ────────────────────────────────────────────────────────────────
if [ $SIN_FINDER = 0 ]; then
  paso "5. Acción rápida de Finder"
  mkdir -p "$HOME/Library/Services"
  rm -rf "$HOME/Library/Services/Preguntarle a Claude.workflow"
  cp -R "$AQUI/finder/Preguntarle a Claude.workflow" "$HOME/Library/Services/"
  /System/Library/CoreServices/pbs -update 2>/dev/null || true
  ok "Clic derecho sobre un archivo → Acciones rápidas → Preguntarle a Claude"
fi

# ── Listo ────────────────────────────────────────────────────────────────────
paso "Listo ✳︎"
cat <<EOF
  • Abrí una sesión nueva de Claude Code para ver la statusline y los hooks
    (en una sesión abierta: /hooks para recargar).
  • El % de uso aparece en la barra apenas corra una sesión (hace falta login
    con cuenta de claude.ai; con API key no hay límites que mostrar).
  • Siri desde el iPhone: seguí docs/SIRI.md (Remote Login + Tailscale + Atajo).
  • Opcional: editá $CONF_DIR/config para vigilar tu servicio.
  • Guardián de deploys y buzón (opcionales, se prenden a mano):
      claude-guardia --instalar     (antes: definí GUARDIA en la config)
      claude-buzon --instalar       (crea la carpeta en iCloud Drive)
  • Estado de todo en una pantalla: claude-estado
  • Para desinstalar: ./uninstall.sh
EOF
