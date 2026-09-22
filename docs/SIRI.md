# "Oye Siri, preguntale a Claude"

El iPhone entra por SSH a la Mac, corre `claude-siri "<lo que dijiste>"` y Siri te lee la respuesta.

## 1. En la Mac: activar SSH (una vez)

*Configuración del Sistema → General → Compartir → **Sesión remota*** (Remote Login): activado.
En "Permitir acceso a", dejá sólo tu usuario.

Para probarlo desde la misma Mac: `ssh $(whoami)@localhost claude-siri "hola"`.

### Login de Claude por SSH (una vez)

Por SSH el llavero de macOS está bloqueado, y Claude Code no encuentra tu sesión ("not logged in"). Generá un token largo y guardalo donde lo busca `claude-siri`:

```bash
claude setup-token                      # te da un token sk-ant-oat…
mkdir -p ~/.config/claude-gadgets
pbpaste > ~/.config/claude-gadgets/token   # con el token copiado
chmod 600 ~/.config/claude-gadgets/token
```

El token es como una contraseña: no lo compartas ni lo subas a ningún repo.

## 2. Desde afuera de casa: Tailscale (opcional, recomendado)

1. Instalá Tailscale en la Mac (`brew install --cask tailscale`) y en el iPhone (App Store).
2. Iniciá sesión con la misma cuenta en los dos.
3. Anotá el nombre de la Mac en Tailscale, por ejemplo `mi-mac`, o su IP `100.x.y.z`.

Así el Atajo anda desde cualquier red, sin abrir puertos. Si sólo lo vas a usar en tu wifi, alcanza con la IP local de la Mac.

> Para que conteste, la Mac tiene que estar prendida y sin dormir. En *Configuración → Batería/Energía*, activá "Evitar reposo automático con la pantalla apagada" si hace falta.

## 3. En el iPhone: el Atajo

App **Atajos** → **+** → nombralo **Preguntale a Claude** (esa frase es la que le decís a Siri).

1. Acción **Dictar texto** (idioma: Español).
2. Acción **Ejecutar script por SSH**:
   - Anfitrión: `mi-mac` (Tailscale) o la IP de la Mac
   - Puerto: `22`
   - Usuario: tu usuario de la Mac, exacto (lo ves con `whoami`; un error de tipeo da "Error de autenticación de clave SSH")
   - Autenticación: **Clave SSH**. Tocá "Clave SSH" → *Generar* → *Compartir clave pública*, y pegá esa línea en la Mac, en `~/.ssh/authorized_keys` (ver abajo).
   - Script: `~/.local/bin/claude-siri` (sólo eso, sin comillas ni variables)
   - Entrada: **Texto dictado**. La pregunta le llega a `claude-siri` por la entrada, así no se rompe con comillas o apóstrofes.
3. Acción **Leer texto** con el *Resultado del shell*, para que Siri lo diga en voz alta (o **Mostrar resultado** para verlo en pantalla).

> Error común: escribir `" + Texto dictado "` a mano en el script. Claude recibe ese texto literal y contesta cualquier cosa.

Agregar la clave en la Mac:

```bash
mkdir -p ~/.ssh && chmod 700 ~/.ssh
pbpaste >> ~/.ssh/authorized_keys   # con la clave pública copiada
chmod 600 ~/.ssh/authorized_keys
```

## 4. Probar

"Oye Siri, preguntale a Claude" → "¿qué cambió hoy en mi-proyecto?"

`claude-siri` usa Sonnet (rápido) y sólo herramientas de lectura y web: no puede modificar archivos ni correr comandos. Tarda unos 5 a 15 segundos. Para cambiar la carpeta o el modelo, editá `CLAUDE_SIRI_DIR` y `CLAUDE_SIRI_MODELO` en `~/.config/claude-gadgets/config`.

## Seguridad

- La clave SSH del iPhone da acceso a tu usuario de la Mac. Si perdés el teléfono, borrala de `~/.ssh/authorized_keys`.
- Con Tailscale, la Mac no queda expuesta a internet; sólo la ven tus dispositivos.
