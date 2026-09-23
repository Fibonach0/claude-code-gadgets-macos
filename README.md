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
| **Guardián de deploys** | `claude-guardia`: cuando mergeás a main, espera a que el cambio llegue de verdad a producción. Si el sitio sigue sirviendo el bundle viejo (build roto que no bloquea el merge) o el servicio no vuelve, te avisa. |
| **Buzón** | `claude-buzon`: dejás una foto, PDF o Excel en una carpeta de iCloud Drive (también desde el iPhone) y aparece al lado una ficha en `.md` con los datos. |
| **Estado** | `claude-estado`: en una pantalla, servicios arriba o abajo, qué se mergeó hoy, PRs abiertos, deploys en curso y tu cupo de Claude. Va bien como Atajo del iPhone. |
| **Freno de mano** | Hook `PreToolUse` que frena lo irreversible antes de que pase: push forzado, `rm -rf` con comodín, DROP/TRUNCATE, variables de producción, borrar repos o credenciales. |
| **Guardián de jobs** | `claude-jobs`: revisa en los logs si los trabajos programados de tu servidor corrieron a la hora que tenían, y avisa sólo si falta alguno. |
| **Build de prueba** | `claude-prebuild`: compila el front en un volumen sensible a mayúsculas (como Linux) y caza los imports que en la Mac pasan. Un hook lo exige antes de mergear un PR que toca el front. |
| **Anotar por voz** | `claude-anotar "…"`: guarda un pendiente con fecha y proyecto (lo clasifica solo). Va bien como Atajo del iPhone. |
| **Autorizar desde el celular** | `claude-permitir`: deja pasar, una vez y por 10 minutos, el último comando que frenó el freno de mano. Y **aprende**: a la tercera vez te ofrece dejarlo fijo (`--siempre`), así el freno queda para lo raro. |
| **Parte de la mañana** | `claude-brief`: cuatro o cinco frases habladas — cupo, qué se rompió mientras dormías, pendientes y agenda. Se cocina temprano en la Mac y el iPhone sólo lo lee. |
| **Parte de horas** | `claude-horas`: cuánto le dedicaste a cada proyecto, por día o por mes, con `--csv` para la planilla. Sale de tus propias sesiones. |
| **Buscador** | `claude-buscar "el WAF que bloqueaba"`: busca en todo lo que ya trabajaste y te contesta, diciendo de qué día y proyecto lo sacó. |
| **Panel** | `claude-panel`: una página local con tiempo por día y por proyecto, pedidos y costo estimado. |
| **Aviso de límite** | `claude-limite`: cuando el cupo semanal pasa 60/80/90%, avisa una vez y sugiere bajar de modelo. |
| **Cola de pedidos** | `claude-cola "…"`: dejás encargues (también desde el iPhone) y la Mac los toma de a uno. Modo lectura por defecto. |
| **Diario** | `claude-diario`: cada noche escribe qué hiciste ese día, por proyecto. |
| **Limpiador** | `claude-limpiar`: qué ocupa disco de lo que deja Claude Code, y cómo liberarlo sin perder la memoria útil. |
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
CLAUDE_SIRI_EXTRA=("$HOME/otra-carpeta")     # carpetas extra que puede leer

# Guardián de deploys: nombre|repo|destino|modo   (modo: bundle | salud)
GUARDIA=("hub|$HOME/proyectos/hub|https://hub.ejemplo.com/|bundle"
         "bot|$HOME/proyectos/bot|https://bot.ejemplo.com/|salud")
GUARDIA_ESPERA=15                            # minutos antes de dar el deploy por perdido
GUARDIA_PATRON="^front/"                     # en modo bundle, qué rutas obligan a esperar

BUZON="$HOME/Library/Mobile Documents/com~apple~CloudDocs/Para Claude"
NTFY_TOPIC=""                                # opcional: avisos al celular por ntfy.sh
FRENO=1                                      # 0 apaga el freno de mano

# Guardián de trabajos programados (usa el conector de Railway vía Claude)
JOBS_SERVICIO="el servicio web del proyecto tal"
JOBS=("backup_diario|03:00|guarda el dump" "aviso_precios|08:15|")
JOBS_HORA=10

# Build de prueba antes de mergear front
PREBUILD_DIR="$HOME/proyectos/hub/front"
PREBUILD_PATRON="^front/"                    # qué rutas del PR lo exigen

# Pendientes dictados
PENDIENTES="$HOME/Documents/Pendientes.md"
ANOTAR_PISTAS="el hub es tal repo; el bot es tal otro"

# Parte hablado de la mañana
BRIEF_HORA=7          # se arma 7:30
BRIEF_AGENDA=1        # incluye la agenda (conector de Google Calendar)
BRIEF_VOZ="Paulina"   # voz de macOS para --decir

# Tus números y la cola
LIMITE_AVISOS="60 80 90"          # en qué % del cupo semanal avisar
COLA_DIR="$HOME/proyectos"        # dónde trabaja la cola
COLA_MODO=seguro                  # "trabajar" la deja editar archivos
DIARIO_DIR="$HOME/Documents/Diario"
LIMPIAR_DIAS=90                   # qué es "viejo" para el limpiador
```

Los que corren solos, una vez cada uno:

```bash
claude-guardia --instalar    # deploys, cada 2 minutos
claude-buzon --instalar      # la carpeta mágica
claude-jobs --instalar       # los trabajos programados, una vez por día
claude-brief --instalar      # el parte hablado, temprano
claude-limite --instalar     # mira el cupo cada media hora
claude-diario --instalar     # escribe el diario a las 20:00
claude-cola --instalar       # toma un pedido de la cola cada 5 minutos
```

> `NTFY_TOPIC` manda los avisos a ntfy.sh, un servicio público: cualquiera que
> adivine el nombre del tema los ve. Usá un nombre largo y al azar, y no pongas
> ahí nada sensible. Vacío = sólo avisos en la Mac.

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
claude/hooks/frenar.sh        freno de mano (PreToolUse)
claude/hooks/prebuild-check.sh  exige build verde antes de mergear front
swiftbar/claude.1m.sh         plugin de la barra (cada 1 min)
bin/claude-siri               pregunta corta para Siri/SSH
bin/claude-archivo            lo que corre la acción de Finder
bin/claude-limpiar-estado     borra sesiones colgadas del menú
bin/claude-guardia            guardián de deploys (launchd, cada 2 min)
bin/claude-buzon              carpeta mágica en iCloud Drive (launchd)
bin/claude-estado             estado de todo en una pantalla
bin/claude-jobs               ¿corrieron los trabajos programados?
bin/claude-prebuild           build en volumen sensible a mayúsculas
bin/claude-anotar             pendientes dictados
bin/claude-permitir           autoriza el último comando frenado (y aprende)
bin/claude-brief              el parte de la mañana, para escuchar
bin/tx.py                     lee tus sesiones (lo usan horas, panel, diario, buscar)
bin/claude-horas              parte de horas por proyecto
bin/claude-buscar             busca en tus sesiones viejas y responde
bin/claude-panel              página local con tus números
bin/claude-limite             aviso cuando el cupo semanal se acaba
bin/claude-cola               cola de pedidos, de a uno
bin/claude-diario             el diario de trabajo de cada día
bin/claude-limpiar            informe de disco y limpieza
finder/Preguntarle a Claude.workflow
config/                       ejemplo de config, hooks, permisos
pruebas/                      24 casos del freno, el circuito de autorización
                              y los 5 casos del hook de build
docs/SIRI.md                  paso a paso del Atajo del iPhone
```
