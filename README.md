# Claude Code Gadgets para macOS

Accesorios para usar [Claude Code](https://claude.com/claude-code) en la Mac (y desde el iPhone).
Se instalan con un comando y se desinstalan con otro.

| Gadget | Qué hace |
|---|---|
| **Barra de menú** (SwiftBar) | `✳︎ 3% · 45%`: el % de uso de la **sesión** (ventana de 5 h) y de la **semana**, con barra, cuándo se renueva cada uno y las sesiones que te están esperando (🟠). Opcional: si tu servicio responde. |
| **Statusline** | Abajo de cada sesión: `modelo · carpeta (rama*) · ctx 25% · 5h 3% · 7d 45% · $1.23`. Verde, amarillo desde el 50 %, rojo desde el 80 %. |
| **Avisos** (hooks) | Notificación y sonido cuando Claude termina o te necesita, sólo si no estás mirando la Terminal. |
| **Finder** | Clic derecho sobre un archivo → *Acciones rápidas* → **Preguntarle a Claude**. Le preguntás algo y la respuesta se abre en TextEdit. Claude sólo puede leer. |
| **Siri / Atajos** | `claude-siri "pregunta"`: una respuesta corta para leer en voz alta. Con un Atajo del iPhone y SSH queda en "Oye Siri, consulta Claude" o en el botón de Acción. Ver [docs/SIRI.md](docs/SIRI.md). |
| **Permisos** (opcional) | Deja correr sin preguntar comandos de sólo lectura (`git status/log/diff`, `ls`, `gh pr view`, `railway logs`…). |

## Instalar

```bash
git clone <este repo> ~/claude-code-gadgets-macos
cd ~/claude-code-gadgets-macos
./install.sh                 # todo
./install.sh --con-permisos  # + permisos de sólo lectura
```

Otras opciones: `--sin-barra`, `--sin-finder`. Podés correrlo de nuevo cuando quieras: reemplaza lo suyo y no toca lo demás.

Requisitos: macOS, Claude Code con login de claude.ai (Pro/Max) y [Homebrew](https://brew.sh) (para `jq` y SwiftBar).

Después:
1. Abrí una sesión nueva de Claude Code. En la que ya tenías abierta, usá `/hooks` para recargar.
2. La primera vez que te llegue un aviso, macOS pide permiso para mostrar notificaciones de *Script Editor*: aceptalo.
3. El % aparece en la barra en cuanto corre cualquier sesión.

### Qué toca

- `~/.claude/statusline.sh` y `~/.claude/hooks/avisar.sh` (si ya tenías versiones distintas, las guarda como `.bak-*`).
- `~/.claude/settings.json`: agrega `statusLine` y hooks en `UserPromptSubmit`, `Notification`, `Stop` y `SessionEnd`. Antes deja un respaldo `settings.json.bak-*`. Todo lo demás queda como estaba.
- `~/.claude/gadgets/`: comandos y el plugin de SwiftBar. `~/.local/bin/claude-siri`.
- `~/Library/Services/Preguntarle a Claude.workflow`.
- `~/.config/claude-gadgets/config`: tu configuración (ver `config/config.ejemplo`).

## Desinstalar

```bash
./uninstall.sh
```

## Cómo funciona el % de uso

Claude Code le pasa a la statusline un JSON que trae `rate_limits.five_hour` y `rate_limits.seven_day` (`used_percentage` y `resets_at`). `statusline.sh` guarda eso en `~/.claude/estado/uso.json` y el plugin de SwiftBar lo lee cada minuto.

- El dato se actualiza **mientras usás Claude Code**: la barra muestra "dato de hace N min".
- Si la ventana ya se renovó desde el último dato, la barra muestra 0 %.
- El uso de claude.ai web o de la app no se ve hasta la próxima vez que corra Claude Code. El número exacto está en *Ver uso en claude.ai*, dentro del menú.
- Con API key (sin login de claude.ai) no hay límites, así que no se muestra nada.

## Configuración (`~/.config/claude-gadgets/config`)

```bash
HUB_URL="https://tu-servicio.ejemplo.com/"   # la barra muestra 🟢/🔴
HUB_NOMBRE="Hub"
LINKS=("Railway=https://railway.com/dashboard")
CLAUDE_SIRI_DIR="$HOME/proyectos"            # dónde trabaja claude-siri
CLAUDE_SIRI_MODELO="sonnet"
```

## Extras que vienen con Claude Code

- **Remote Control**: seguí desde la app de Claude en el iPhone una sesión que corre en la Mac (`/remote-control`, o `"remoteControlAtStartup": true` en settings).
- **Push al celular**: `/config` → notificaciones al móvil cuando Claude te necesita.
- **Dictado por voz**: `/config` → voz, o `"voice": {"enabled": true}` en settings.
- **`/schedule`**: agentes en la nube con horario fijo, aunque la Mac esté apagada.

## Estructura

```
install.sh / uninstall.sh
claude/statusline.sh          statusline + guarda el uso
claude/hooks/avisar.sh        avisos + estado de sesiones
swiftbar/claude.1m.sh         plugin de la barra (cada 1 min)
bin/claude-siri               pregunta corta para Siri/SSH
bin/claude-archivo            lo que corre la acción de Finder
bin/claude-limpiar-estado     borra sesiones colgadas del menú
finder/Preguntarle a Claude.workflow
config/                       ejemplo de config, hooks, permisos
docs/SIRI.md                  paso a paso del Atajo del iPhone
```
