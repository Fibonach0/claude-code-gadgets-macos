#!/bin/bash
# Detector de credenciales: frena que una clave termine adentro de un repo.
#
# Dos momentos, porque son dos errores distintos:
#   1. cuando se va a ESCRIBIR un archivo que está dentro de un repo git, mira
#      el contenido que se está por guardar;
#   2. cuando se va a COMMITEAR, mira lo que ya está en el stage — ahí caen las
#      claves que escribiste vos a mano, que el paso 1 nunca vio.
#
# Fuera de un repo no dice nada: un token guardado en ~/.config es justamente
# donde tiene que estar.
#
# Se engancha como hook PreToolUse con matcher "Write|Edit|Bash".
# Para desactivarlo: SECRETOS=0 en ~/.config/claude-gadgets/config
export LANG=${LANG:-es_AR.UTF-8}
[ -f ~/.config/claude-gadgets/config ] && . ~/.config/claude-gadgets/config
[ "${SECRETOS:-1}" = 0 ] && exit 0

entrada=$(cat)
herramienta=$(jq -r '.tool_name // empty' <<<"$entrada")

# Los patrones son de formato, no de nombre: lo que se busca es la PINTA de una
# credencial. Un nombre de variable no alcanza —"API_KEY=tu-clave-acá" es un
# ejemplo, no un secreto— y por eso cada patrón exige el cuerpo largo y al azar.
patrones=(
  'sk-ant-[A-Za-z0-9_-]{24,}'                 # Anthropic
  'sk-[A-Za-z0-9]{32,}'                       # OpenAI y parecidos
  'AKIA[0-9A-Z]{16}'                          # AWS
  'ghp_[A-Za-z0-9]{28,}|github_pat_[A-Za-z0-9_]{40,}'
  'xox[baprs]-[A-Za-z0-9-]{20,}'              # Slack
  'AIza[0-9A-Za-z_-]{30,}'                    # Google
  'sb_secret_[A-Za-z0-9_-]{20,}'              # Supabase (la de servicio)
  'eyJ[A-Za-z0-9_-]{15,}\.eyJ[A-Za-z0-9_-]{15,}\.[A-Za-z0-9_-]{10,}'   # JWT firmado
  '-----BEGIN [A-Z ]*PRIVATE KEY-----'
  '(postgres|postgresql|mysql|mongodb(\+srv)?)://[^:/@ ]+:[^@ ]{8,}@'   # URL con clave
)

frenar() {  # qué se encontró, dónde
  jq -n --arg q "$1" --arg d "$2" '{
    hookSpecificOutput: {
      hookEventName: "PreToolUse",
      permissionDecision: "deny",
      permissionDecisionReason: ("CREDENCIAL A LA VISTA: parece " + $q + " en " + $d +
        ". Un secreto adentro de un repo queda en el historial de git para siempre, " +
        "aunque después se borre. Guardalo en una variable de entorno o en " +
        "~/.config, y dejá en el archivo sólo el nombre de la variable. " +
        "Si es un ejemplo inventado, acortalo o escribilo como <TU_CLAVE>.")
    }}'
  mkdir -p ~/.claude/estado
  printf '%s | %s :: %s\n' "$(date '+%d/%m %H:%M')" "$1" "$2" >> ~/.claude/estado/secretos.log
  exit 0
}

nombre_de() {  # qué clase de credencial es, para que el aviso diga algo
  case "$1" in
    sk-ant-*)  echo "una clave de Anthropic" ;;
    sk-*)      echo "una clave de API" ;;
    AKIA*)     echo "una clave de AWS" ;;
    ghp_*|github_pat_*) echo "un token de GitHub" ;;
    xox*)      echo "un token de Slack" ;;
    AIza*)     echo "una clave de Google" ;;
    sb_secret_*) echo "la clave de servicio de Supabase" ;;
    eyJ*)      echo "un JWT firmado" ;;
    -----BEGIN*) echo "una clave privada" ;;
    *://*)     echo "una URL de base de datos con contraseña" ;;
    *)         echo "una credencial" ;;
  esac
}

buscar() {  # texto, dónde; frena si aparece algo
  local texto=$1 donde=$2 p hallazgo
  for p in "${patrones[@]}"; do
    # El "--" es obligatorio: un patrón que empieza con guiones (la clave
    # privada) se toma como opción de grep y el hook se vuelve ciego a él.
    hallazgo=$(grep -oE -- "$p" <<<"$texto" | head -1)
    [ -n "$hallazgo" ] && frenar "$(nombre_de "$hallazgo")" "$donde"
  done
}

en_repo() { git -C "$(dirname "$1")" rev-parse --is-inside-work-tree >/dev/null 2>&1; }

case "$herramienta" in
  Write|Edit|NotebookEdit)
    ruta=$(jq -r '.tool_input.file_path // empty' <<<"$entrada")
    [ -z "$ruta" ] && exit 0
    case "$ruta" in
      *.env.example|*.example|*/pruebas/*|*/test*|*secretos.sh) exit 0 ;;   # ejemplos y pruebas
    esac
    en_repo "$ruta" || exit 0        # fuera de un repo, es tu casa
    contenido=$(jq -r '[.tool_input.content, .tool_input.new_string] | map(select(.)) | join("\n")' <<<"$entrada")
    buscar "$contenido" "$(basename "$ruta")"
    ;;
  Bash)
    cmd=$(jq -r '.tool_input.command // empty' <<<"$entrada")
    grep -qE '(^|[;&|] *)git +(-C +[^ ]+ +)?commit' <<<"$cmd" || exit 0
    dir=$(jq -r '.cwd // empty' <<<"$entrada"); cd "${dir:-.}" 2>/dev/null || exit 0
    # Lo que está por entrar al commit, no el archivo entero.
    staged=$(git diff --cached --no-color 2>/dev/null | grep '^+' | head -4000)
    [ -z "$staged" ] && exit 0
    buscar "$staged" "lo que está por commitearse"
    ;;
esac
exit 0
