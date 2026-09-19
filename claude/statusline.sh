#!/bin/bash
# Statusline de Claude Code:
#   modelo · carpeta (rama*) · ctx 16% · 5h 2% · 7d 45% · $3.36
# Recibe por stdin el JSON de la sesión. De paso guarda el uso (límite de 5 h y
# semanal) en ~/.claude/estado/uso.json para el widget de la barra de menú.
input=$(cat)
est=~/.claude/estado; mkdir -p "$est"
printf '%s' "$input" > "$est/statusline-ultimo.json"   # para depurar campos

# Uso de la cuenta: sólo viene con login de claude.ai (Pro/Max), no con API key.
if jq -e '.rate_limits.five_hour or .rate_limits.seven_day' >/dev/null 2>&1 <<<"$input"; then
  jq '{rate_limits, ts:(now|floor)}' <<<"$input" > "$est/uso.json.tmp" && mv "$est/uso.json.tmp" "$est/uso.json"
fi

modelo=$(jq -r '.model.display_name // .model.id // "?"' <<<"$input")
dir=$(jq -r '.workspace.current_dir // .cwd // ""' <<<"$input")
costo=$(jq -r '.cost.total_cost_usd // empty' <<<"$input")
pct=$(jq -r '.context_window.used_percentage // empty' <<<"$input")
p5=$(jq -r '.rate_limits.five_hour.used_percentage // empty' <<<"$input")
p7=$(jq -r '.rate_limits.seven_day.used_percentage // empty' <<<"$input")

rama=""
if [ -n "$dir" ] && git -C "$dir" rev-parse --git-dir >/dev/null 2>&1; then
  rama=$(git -C "$dir" branch --show-current 2>/dev/null)
  [ -n "$(git -C "$dir" status --porcelain 2>/dev/null | head -1)" ] && rama="$rama*"
fi

gris=$'\e[2m'; rst=$'\e[0m'; verde=$'\e[32m'; amar=$'\e[33m'; rojo=$'\e[31m'
color() { local n=${1%.*}; [ "$n" -ge 80 ] && printf '%s' "$rojo" && return
          [ "$n" -ge 50 ] && printf '%s' "$amar" && return; printf '%s' "$verde"; }
sep=" ${gris}·${rst} "

out="${modelo}${sep}${dir/#$HOME/~}"
[ -n "$rama" ] && out="$out ${gris}(${rst}${rama}${gris})${rst}"
[ -n "$pct" ] && out="${out}${sep}ctx $(color "$pct")${pct%.*}%${rst}"
[ -n "$p5" ]  && out="${out}${sep}5h $(color "$p5")${p5%.*}%${rst}"
[ -n "$p7" ]  && out="${out}${sep}7d $(color "$p7")${p7%.*}%${rst}"
[ -n "$costo" ] && out="${out}${sep}\$$(printf '%.2f' "$costo")"
printf '%s' "$out"
