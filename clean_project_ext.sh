#!/usr/bin/env bash
###############################################################################
# clean_project_ext.sh  --  Limpieza y reconstrucción focalizada por proyecto
# "Stark Edition" - versión extendida
#
# Objetivo:
#   - Limpiar contenedores, imágenes y volúmenes pertenecientes a un proyecto
#     (identificados por label de docker compose y/o prefijo de nombre).
#   - Opcionalmente normalizar finales de línea, escanear secretos,
#     lint de requirements, validar Dockerfiles, calcular hash del contexto,
#     reconstruir e iniciar servicios.
#
# Requisitos:
#   - bash, docker, docker compose
#   - sed, awk, grep, sha256sum (coreutils)
#
# Autor: Tu IA de confianza (Jarvis style) 🦾
###############################################################################

set -euo pipefail

SCRIPT_NAME="$(basename "$0")"
START_TS="$(date +%s)"

# -------- Colores --------
c_reset="\033[0m"
c_info="\033[1;36m"
c_warn="\033[1;33m"
c_err="\033[1;31m"
c_ok="\033[1;32m"
c_dim="\033[2m"

info() { echo -e "${c_info}[INFO]${c_reset} $*"; }
warn() { echo -e "${c_warn}[WARN]${c_reset} $*"; }
err()  { echo -e "${c_err}[ERR ]${c_reset} $*" >&2; }
ok()   { echo -e "${c_ok}[OK  ]${c_reset} $*"; }

# -------- Defaults / Flags --------
PROJECT=""
PREFIX=""
DO_VOLUMES=0
DO_FORCE=0
DO_DRYRUN=0
DO_BUILD=0
DO_NOCACHE=0
DO_UP=0
DO_NORMALIZE=0
DO_SCAN=0
DO_LINT_REQS=0
DO_VALIDATE=0
DO_HASH=0
DO_DEBUG=0
LOG_DIR=""
COMPOSE_FILE="docker-compose.yml"

print_help() {
  cat <<EOF
$SCRIPT_NAME  - Limpieza focalizada por proyecto (Stark Edition)

Uso:
  $SCRIPT_NAME -p <proyecto> --prefix <prefijo> [opciones]

Obligatorios:
  -p, --project NAME          Nombre del proyecto (label docker compose)
  --prefix PREF               Prefijo que usan las imágenes/contenedores

Opciones de limpieza:
  -v, --volumes               También eliminar volúmenes del proyecto
  -f, --force                 No pedir confirmación
  -n, --dry-run               Mostrar acciones sin ejecutar

Funciones extra ("Fase Stark"):
  --normalize-eol             Normaliza finales de línea (LF) en Dockerfiles y .sh
  --scan-secrets              Escanea posibles secretos expuestos en el repo
  --lint-reqs                 Lint básico de requirements.txt (duplicados, espacios)
  --validate-dockerfiles      Chequeos básicos de sintaxis (heredocs abiertos, FROM, etc.)
  --context-hash              Calcula hash SHA256 de archivos relevantes antes de build
  --debug                     set -x para depuración

Ciclo de rebuild:
  --build                     Ejecutar docker compose build (solo servicios afectados)
  --no-cache                  Con --build, fuerza --no-cache
  --up                        Ejecutar docker compose up -d después del build

Registro:
  --log-dir DIR               Directorio donde guardar log consolidado (timestamp)

Otros:
  -h, --help                  Mostrar ayuda y salir

Ejemplos:
  $SCRIPT_NAME -p jarvisweb_openai --prefix jarvisweb_openai-
  $SCRIPT_NAME -p jarvisweb_openai --prefix jarvisweb_openai- --volumes --force --build --no-cache --up
  $SCRIPT_NAME -p jarvisweb_openai --prefix jarvisweb_openai- --normalize-eol --scan-secrets --lint-reqs --validate-dockerfiles --context-hash --build --no-cache --up

EOF
}

# -------- Parseo de argumentos --------
while [[ $# -gt 0 ]]; do
  case "$1" in
    -p|--project) PROJECT="$2"; shift 2;;
    --prefix) PREFIX="$2"; shift 2;;
    -v|--volumes) DO_VOLUMES=1; shift;;
    -f|--force) DO_FORCE=1; shift;;
    -n|--dry-run|--dryrun) DO_DRYRUN=1; shift;;
    --build) DO_BUILD=1; shift;;
    --no-cache|--nocache) DO_NOCACHE=1; shift;;
    --up) DO_UP=1; shift;;
    --normalize-eol) DO_NORMALIZE=1; shift;;
    --scan-secrets) DO_SCAN=1; shift;;
    --lint-reqs) DO_LINT_REQS=1; shift;;
    --validate-dockerfiles) DO_VALIDATE=1; shift;;
    --context-hash) DO_HASH=1; shift;;
    --debug) DO_DEBUG=1; shift;;
    --log-dir) LOG_DIR="$2"; shift 2;;
    -h|--help) print_help; exit 0;;
    *) warn "Flag desconocido: $1"; shift;;
  esac
done

[[ -z "$PROJECT" || -z "$PREFIX" ]] && { err "Debes especificar --project y --prefix"; exit 1; }

if [[ $DO_DEBUG -eq 1 ]]; then
  set -x
fi

# -------- Logging a archivo si log-dir --------
if [[ -n "$LOG_DIR" ]]; then
  mkdir -p "$LOG_DIR"
  TS="$(date +%Y%m%d_%H%M%S)"
  LOG_FILE="$LOG_DIR/clean_${PROJECT}_${TS}.log"
  info "Redirigiendo salida a $LOG_FILE (además de consola)."
  exec > >(tee -a "$LOG_FILE") 2>&1
fi

info "Proyecto objetivo: $PROJECT"
info "Prefijo imágenes: $PREFIX"
[[ $DO_DRYRUN -eq 1 ]] && warn "DRY-RUN activado: no se eliminará nada."
[[ $DO_FORCE -eq 1 ]] && info "Force=ON (sin confirmación)."

# -------- Funciones utilitarias --------
confirm() {
  local prompt="$1"
  if [[ $DO_FORCE -eq 1 ]]; then
    return 0
  fi
  read -r -p "$prompt (YES para continuar) " ans
  [[ "$ans" == "YES" ]]
}

run() {
  # Ejecuta o muestra según dry-run
  if [[ $DO_DRYRUN -eq 1 ]]; then
    echo "DRY-RUN> $*"
  else
    eval "$@"
  fi
}

# -------- Extra: Normalize EOL --------
normalize_eol() {
  info "Normalizando finales de línea (LF) en Dockerfiles y scripts..."
  local targets
  targets=$(git ls-files '*Dockerfile*' '*.sh' 2>/dev/null || true)
  if [[ -z "$targets" ]]; then
    warn "No se encontraron Dockerfiles ni scripts versionados."
    return
  fi
  while IFS= read -r f; do
    if file "$f" | grep -qi "CRLF"; then
      run "sed -i 's/\r$//' '$f'"
      ok "$f -> LF"
    else
      echo -e "${c_dim}skip${c_reset} $f"
    fi
  done <<< "$targets"
}

# -------- Extra: Scan Secrets --------
scan_secrets() {
  info "Escaneando posibles secretos expuestos..."
  local patterns='(sk-[A-Za-z0-9_-]{20,})|(OPENAI_API_KEY\s*=)|(AKIA[0-9A-Z]{16})'
  if grep -RInE "$patterns" . --exclude-dir .git --exclude .env 2>/dev/null; then
     warn "⚠ Posibles secretos detectados arriba."
  else
     ok "No se detectaron firmas típicas de secretos."
  fi
}

# -------- Extra: Lint requirements --------
lint_requirements() {
  local req
  req=$(git ls-files '*requirements.txt' 2>/dev/null || true)
  if [[ -z "$req" ]]; then
    warn "No se encontraron requirements.txt versionados."
    return
  fi
  info "Lint de requirements:"
  while IFS= read -r f; do
    echo "  Archivo: $f"
    # Duplicados case-insensitive (ignorando comentarios y líneas vacías)
    local dups
    dups=$(awk 'NF && $1 !~ /^#/ {print tolower($0)}' "$f" | sort | uniq -d || true)
    if [[ -n "$dups" ]]; then
      warn "    Duplicados:\n$dups"
    fi
    # Espacios sospechosos
    grep -nE '==\s+' "$f" && warn "    Hay espacios tras '=='."
  done <<< "$req"
  ok "Lint requirements completado."
}

# -------- Extra: Validar Dockerfiles --------
validate_dockerfiles() {
  info "Validando Dockerfiles..."
  local dfs
  dfs=$(git ls-files '*Dockerfile*' 2>/dev/null || true)
  [[ -z "$dfs" ]] && { warn "No se hallaron Dockerfiles."; return; }
  local fail=0
  while IFS= read -r df; do
    echo "  Revisando $df"
    grep -q '^FROM ' "$df" || { warn "    Falta FROM"; fail=1; }
    # Heredoc abiertos (patrón simple)
    if grep -q '<<' "$df"; then
       # Cuenta aperturas y cierres simples
       local open close
       open=$(grep -o '<<' "$df" | wc -l | tr -d ' ')
       close=$(grep -E '^[A-Z0-9_]+$' "$df" | wc -l | tr -d ' ')
       # Esta heurística es simple; podemos mejorar si hace falta
       if (( open > close )); then
         warn "    Posible heredoc sin cerrar (open=$open close=$close)"
         fail=1
       fi
    fi
  done <<< "$dfs"
  (( fail == 0 )) && ok "Dockerfiles OK (heurística básica)." || warn "Validación detectó issues."
}

# -------- Extra: Context Hash --------
context_hash() {
  info "Calculando hash SHA256 de contexto relevante..."
  local files
  files=$(git ls-files \
      '*Dockerfile*' \
      '*.py' \
      '*requirements.txt' \
      'docker-compose.yml' 2>/dev/null || true)
  if [[ -z "$files" ]]; then
    warn "Sin archivos relevantes versionados."
    return
  fi
  # Concatenate and hash
  echo "$files" | sort | xargs cat | sha256sum | awk '{print "Context Hash:", $1}'
}

# -------- Obtener listas de recursos del proyecto --------
list_containers() {
  docker ps -a --filter "label=com.docker.compose.project=${PROJECT}" --format '{{.ID}} {{.Names}}'
}

list_images() {
  # Buscar imágenes con ese prefijo
  docker images --format '{{.Repository}}:{{.Tag}} {{.ID}}' | grep -E "^${PREFIX}" || true
}

list_volumes() {
  docker volume ls --format '{{.Name}}' | grep -E "^${PROJECT}" || true
}

# -------- Ejecución de extras previos --------
[[ $DO_NORMALIZE -eq 1 ]] && normalize_eol
[[ $DO_SCAN -eq 1 ]] && scan_secrets
[[ $DO_LINT_REQS -eq 1 ]] && lint_requirements
[[ $DO_VALIDATE -eq 1 ]] && validate_dockerfiles
[[ $DO_HASH -eq 1 ]] && context_hash

# -------- Limpieza principal --------
info "Analizando contenedores del proyecto..."
CONTAINERS="$(list_containers || true)"
if [[ -z "$CONTAINERS" ]]; then
  warn "No hay contenedores asociados al proyecto."
else
  echo "$CONTAINERS" | awk '{print "  - " $0}'
  if confirm "Proceder con eliminación de contenedores"; then
    while read -r cid cname; do
      run "docker rm -f $cid"
    done <<< "$CONTAINERS"
    ok "Contenedores eliminados."
  else
    warn "Salteando eliminación de contenedores."
  fi
fi

info "Analizando imágenes del proyecto (prefijo $PREFIX)..."
IMAGES="$(list_images || true)"
if [[ -z "$IMAGES" ]]; then
  warn "No hay imágenes con prefijo."
else
  echo "$IMAGES" | awk '{print "  - " $0}'
  if confirm "Proceder con eliminación de imágenes"; then
    echo "$IMAGES" | awk '{print $2}' | while read -r iid; do
      run "docker rmi -f $iid"
    done
    ok "Imágenes eliminadas."
  else
    warn "Salteando eliminación de imágenes."
  fi
fi

if [[ $DO_VOLUMES -eq 1 ]]; then
  info "Analizando volúmenes (prefijo ${PROJECT})..."
  VOLS="$(list_volumes || true)"
  if [[ -z "$VOLS" ]]; then
    warn "No se encontraron volúmenes."
  else
    echo "$VOLS" | awk '{print "  - " $0}'
    if confirm "Proceder con eliminación de volúmenes"; then
      while read -r v; do
        run "docker volume rm $v"
      done <<< "$VOLS"
      ok "Volúmenes eliminados."
    else
      warn "Salteando eliminación de volúmenes."
    fi
  fi
fi

# -------- Build --------
if [[ $DO_BUILD -eq 1 ]]; then
  info "Iniciando build docker compose..."
  local build_cmd="docker compose -f ${COMPOSE_FILE} build"
  [[ $DO_NOCACHE -eq 1 ]] && build_cmd+=" --no-cache"
  run "$build_cmd"
  ok "Build finalizado."
fi

# -------- Up --------
if [[ $DO_UP -eq 1 ]]; then
  info "Levantando servicios..."
  run "docker compose -f ${COMPOSE_FILE} up -d"
  ok "Servicios arriba."
fi

# -------- Resumen tiempo --------
END_TS="$(date +%s)"
ELAPSED=$(( END_TS - START_TS ))
ok "Proceso completado en ${ELAPSED}s."

exit 0
