#!/usr/bin/env bash
set -euo pipefail

# ---------------- Config por defecto ----------------
PROJECT=""                     # si vacío: se detecta
IMAGE_PREFIX=""                # si quieres filtrar por prefijo adicional (ej: jarvisweb_openai-)
REMOVE_IMAGES=true
REMOVE_VOLUMES=false           # por defecto conservamos volúmenes
DRY_RUN=false
VERBOSE=false

# ---------------- Parse args ----------------
usage() {
  cat <<EOF
Uso: $0 [opciones]
  -p, --project NOMBRE    Nombre del proyecto (si omites: autodetección)
  --prefix PREFIJO        Prefijo de imágenes (ej: jarvisweb_openai-)
  --no-images             No eliminar imágenes del proyecto
  --volumes               También eliminar volúmenes del proyecto
  --dry-run               Mostrar acciones sin ejecutarlas
  -v, --verbose           Salida detallada
  -h, --help
Ejemplos:
  $0 --project jarvisweb_openai --volumes
  $0 --dry-run --prefix jarvisweb_openai-
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    -p|--project) PROJECT="$2"; shift 2;;
    --prefix) IMAGE_PREFIX="$2"; shift 2;;
    --no-images) REMOVE_IMAGES=false; shift;;
    --volumes) REMOVE_VOLUMES=true; shift;;
    --dry-run) DRY_RUN=true; shift;;
    -v|--verbose) VERBOSE=true; shift;;
    -h|--help) usage; exit 0;;
    *) echo "Arg desconocido: $1"; usage; exit 1;;
  esac
done

log() { echo -e "[INFO ] $*"; }
warn(){ echo -e "[WARN ] $*" >&2; }
err() { echo -e "[ERROR] $*" >&2; }
vlog(){ $VERBOSE && echo "[DBG  ] $*"; }

need() { command -v "$1" >/dev/null 2>&1 || { err "Falta comando '$1'"; exit 1; }; }

need docker
need awk
need grep

# ---------------- Detectar proyecto si falta ----------------
if [[ -z "$PROJECT" ]]; then
  # Intenta: variable env, compose config, carpeta
  if docker compose config >/dev/null 2>&1; then
    PROJECT=$(docker compose ps --format json 2>/dev/null | jq -r '.[0].Project' 2>/dev/null || true)
  fi
  if [[ -z "$PROJECT" || "$PROJECT" == "null" ]]; then
    PROJECT=$(basename "$PWD" | tr '[:upper:]' '[:lower:]' | tr -c 'a-z0-9' '_')
    warn "No se detectó automáticamente via compose ps; usando carpeta: $PROJECT"
  fi
fi

log "Proyecto objetivo: $PROJECT"
[[ -n "$IMAGE_PREFIX" ]] && log "Prefijo imágenes: $IMAGE_PREFIX"

# ---------------- Recolectar contenedores ----------------
CONTAINERS=$(docker ps -a --filter "label=com.docker.compose.project=$PROJECT" --format '{{.ID}} {{.Names}}')
if [[ -z "$CONTAINERS" ]]; then
  warn "No hay contenedores asociados al proyecto."
else
  log "Contenedores encontrados:"
  echo "$CONTAINERS" | awk '{print "  - "$2" ("$1")"}'
fi

# ---------------- Recolectar redes ----------------
NETWORKS=$(docker network ls --filter "label=com.docker.compose.project=$PROJECT" --format '{{.ID}} {{.Name}}')
if [[ -z "$NETWORKS" ]]; then
  # fallback por nombre
  NETWORKS=$(docker network ls --format '{{.ID}} {{.Name}}' | grep -i "$PROJECT" || true)
fi
[[ -n "$NETWORKS" ]] && log "Redes detectadas:" && echo "$NETWORKS" | awk '{print "  - "$2" ("$1")"}'

# ---------------- Recolectar volúmenes ----------------
VOLUMES=""
if $REMOVE_VOLUMES; then
  VOLUMES=$(docker volume ls --filter "label=com.docker.compose.project=$PROJECT" --format '{{.Name}}')
  if [[ -z "$VOLUMES" ]]; then
    VOLUMES=$(docker volume ls --format '{{.Name}}' | grep -i "$PROJECT" || true)
  fi
  [[ -n "$VOLUMES" ]] && log "Volúmenes candidatos:" && echo "$VOLUMES" | sed 's/^/  - /'
fi

# ---------------- Recolectar imágenes ----------------
IMAGES=""
if $REMOVE_IMAGES; then
  # 1. Imágenes usadas por contenedores del proyecto
  IMAGES_FROM_CONTAINERS=$(docker ps -a --filter "label=com.docker.compose.project=$PROJECT" --format '{{.Image}}' | sort -u)
  # 2. Filtrar por prefijo opcional
  if [[ -n "$IMAGE_PREFIX" ]]; then
    EXTRA_IMAGES=$(docker images --format '{{.Repository}}:{{.Tag}}' | grep -i "^$IMAGE_PREFIX" || true)
    IMAGES=$(printf "%s\n%s\n" "$IMAGES_FROM_CONTAINERS" "$EXTRA_IMAGES" | sed '/^$/d' | sort -u)
  else
    IMAGES=$IMAGES_FROM_CONTAINERS
  fi
  [[ -n "$IMAGES" ]] && log "Imágenes candidatas:" && echo "$IMAGES" | sed 's/^/  - /'
fi

# ---------------- Confirmación (si no dry-run) ----------------
if ! $DRY_RUN; then
  read -rp "¿Proceder con la limpieza de '$PROJECT'? (YES para continuar) " ANS
  [[ "$ANS" != "YES" ]] && { warn "Abortado"; exit 0; }
else
  warn "DRY-RUN activado: no se eliminará nada."
fi

do_cmd() {
  if $DRY_RUN; then
    echo "DRY: $*"
  else
    vlog "Ejecutando: $*"
    "$@"
  fi
}

# ---------------- Eliminaciones ----------------
# Contenedores
if [[ -n "$CONTAINERS" ]]; then
  log "Eliminando contenedores..."
  echo "$CONTAINERS" | awk '{print $1}' | while read -r CID; do
    do_cmd docker rm -f "$CID"
  done
fi

# Volúmenes
if $REMOVE_VOLUMES && [[ -n "$VOLUMES" ]]; then
  log "Eliminando volúmenes..."
  echo "$VOLUMES" | while read -r VOL; do
    do_cmd docker volume rm "$VOL"
  done
fi

# Redes
if [[ -n "$NETWORKS" ]]; then
  log "Eliminando redes..."
  echo "$NETWORKS" | awk '{print $2}' | while read -r NET; do
    do_cmd docker network rm "$NET"
  done
fi

# Imágenes (solo si no están usadas ya)
if $REMOVE_IMAGES && [[ -n "$IMAGES" ]]; then
  log "Eliminando imágenes..."
  echo "$IMAGES" | while read -r IMG; do
    do_cmd docker rmi -f "$IMG" || true
  done
fi

log "Limpieza finalizada para proyecto '$PROJECT'."
