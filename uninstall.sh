#!/bin/bash
# Desinstala Claude Code Gadgets. Deja SwiftBar, jq y tu config
# (~/.config/claude-gadgets) instalados; borralos a mano si querés.
set -euo pipefail
CLAUDE_DIR="$HOME/.claude"
SETTINGS="$CLAUDE_DIR/settings.json"

if [ -f "$SETTINGS" ]; then
  cp "$SETTINGS" "$SETTINGS.bak-$(date +%Y%m%d%H%M%S)"
  tmp=$(mktemp)
  jq '
    (if (.statusLine.command // "") == "~/.claude/statusline.sh" then del(.statusLine) else . end)
    | if .hooks then
        .hooks |= (with_entries(.value |= [ .[]
            | .hooks = [ .hooks[] | select((.command // "") | contains("hooks/avisar.sh") | not) ]
            | select(.hooks | length > 0) ])
          | with_entries(select(.value | length > 0)))
      else . end
    | if .hooks == {} then del(.hooks) else . end
  ' "$SETTINGS" > "$tmp" && mv "$tmp" "$SETTINGS"
  echo "✓ Saqué statusLine y hooks de settings.json (respaldo: settings.json.bak-*)"
  echo "  Los permisos de --con-permisos quedan; revisalos con /permissions si querés."
fi

rm -f "$CLAUDE_DIR/statusline.sh" "$CLAUDE_DIR/hooks/avisar.sh" "$HOME/.local/bin/claude-siri"
dir_plugins=$(defaults read com.ameba.SwiftBar PluginDirectory 2>/dev/null || true)
[ -n "$dir_plugins" ] && [ -L "$dir_plugins/claude.1m.sh" ] && rm -f "$dir_plugins/claude.1m.sh"
[ "$dir_plugins" = "$CLAUDE_DIR/gadgets/swiftbar" ] && defaults delete com.ameba.SwiftBar PluginDirectory 2>/dev/null || true
rm -rf "$CLAUDE_DIR/gadgets" "$HOME/Library/Services/Preguntarle a Claude.workflow"
/System/Library/CoreServices/pbs -update 2>/dev/null || true
echo "✓ Scripts, widget y acción de Finder borrados"
