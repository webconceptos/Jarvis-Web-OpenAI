#!/usr/bin/env bash
#
# ============================================================
#  🧨  NoUsar.sh  (Usar solo en caso de emergencia técnica)
#  Limpia TODO lo relacionado a este proyecto docker-compose:
#    - Para el proyecto actual (según COMPOSE_PROJECT_NAME o carpeta)
#    - Contenedores detenidos
#    - Imágenes huérfanas (solo las del proyecto)
#    - Volúmenes del proyecto (incluye cache Whisper)
#    - Redes del proyecto
#    - Reconstruye desde cero
#
#  Opciones:
#     --keep-cache   -> NO borra el volumen de caché (whisper_cache)
#     --no-build     -> No reconstruye (solo limpia)
#     --pull         -> Hace pull de imágenes base antes del build
#     --force        -> No pide confirmación interactiva
#
#  Ejemplo:
#     bash NoUsar.sh --keep-cache --pull
#
# ============================================================

set -euo pipefail

# --------- Config ----------
COMPOSE_FILE="docker-compose.yml"
CACHE_VOLUME_NAME="whisper_cache"   # Nombre lógico declarado en compose
PROJECT_NAME="${COMPOSE_PROJECT_NAME:-$(basename "$PWD")}"

KEEP_CACHE=0
DO_BUILD=1
DO_PULL=0
FORCE=0

# --------- ultra debug ------
echo "BASH_VERSION=$BASH_VERSION"
echo "Invocado como: $0 $*"
docker version || { echo "Docker no responde"; exit 1; }
docker compose version || echo "⚠ compose plugin no verificado"


# --------- Colores ----------
RED='\033[0;31m'; YEL='\033[0;33m'; GRN='\033[0;32m'; CYA='\033[0;36m'; NC='\033[0m'

# --------- Parse args ----------
for arg in "$@"; do
  case "$arg" in
    --keep-cache) KEEP_CACHE=1 ;;
    --no-build)   DO_BUILD=0 ;;
    --pull)       DO_PULL=1 ;;
    --force)      FORCE=1 ;;
    -h|--help)
      sed -n '2,40p' "$0"
      exit 0
    ;;
    *)
      echo -e "${RED}Argumento desconocido:${NC} $arg"; exit 1 ;;
  esac
done

echo -e "${CYA}Proyecto detectado:${NC} ${PROJECT_NAME}"
echo -e "${YEL}Este script borrará contenedores, imágenes y volúmenes del proyecto.${NC}"
if [[ $KEEP_CACHE -eq 0 ]]; then
  echo -e "${RED}⚠ Se eliminará también el volumen de caché (${CACHE_VOLUME_NAME}).${NC}"
else
  echo -e "${YEL}⚠ Caché Whisper (${CACHE_VOLUME_NAME}) se conservará.${NC}"
fi

if [[ $FORCE -eq 0 ]]; then
  read -rp "¿Continuar? (escribe 'YES' en mayúsculas): " CONFIRM
  [[ "$CONFIRM" == "YES" ]] || { echo "Abortado."; exit 1; }
fi

echo -e "${GRN}▶ Apagando y eliminando contenedores del proyecto...${NC}"
docker compose -f "$COMPOSE_FILE" down --remove-orphans || true

echo -e "${GRN}▶ Eliminando imágenes del proyecto...${NC}"
# Filtra imágenes cuyo nombre contiene el nombre del proyecto
IMAGES=$(docker images --format '{{.Repository}}:{{.Tag}} {{.ID}}' | grep -i "${PROJECT_NAME}" | awk '{print $2}')
if [[ -n "${IMAGES}" ]]; then
  while read -r IMGID; do
    [[ -z "$IMGID" ]] && continue
    echo "  - Eliminando imagen $IMGID"
    docker rmi -f "$IMGID" || true
  done <<< "$IMAGES"
else
  echo "  (No se encontraron imágenes asociadas)"
fi

echo -e "${GRN}▶ Eliminando contenedores detenidos huérfanos...${NC}"
docker container prune -f >/dev/null || true

echo -e "${GRN}▶ Eliminando redes del proyecto...${NC}"
docker network ls --format '{{.Name}}' | grep -i "${PROJECT_NAME}" | while read -r NET; do
  echo "  - Red: $NET"
  docker network rm "$NET" || true
done

if [[ $KEEP_CACHE -eq 0 ]]; then
  echo -e "${GRN}▶ Eliminando volúmenes del proyecto (incluye caché)...${NC}"
  # Lista volúmenes cuyo nombre contenga el nombre del proyecto
  docker volume ls --format '{{.Name}}' | grep -i "${PROJECT_NAME}" | while read -r VOL; do
    echo "  - Volumen: $VOL"
    docker volume rm "$VOL" || true
  done
else
  echo -e "${GRN}▶ Eliminando volúmenes excepto caché...${NC}"
  docker volume ls --format '{{.Name}}' | grep -i "${PROJECT_NAME}" | while read -r VOL; do
    if [[ "$VOL" == *"${CACHE_VOLUME_NAME}"* ]]; then
      echo "  - Conservando ${VOL}"
      continue
    fi
    echo "  - Volumen: $VOL"
    docker volume rm "$VOL" || true
  done
fi

echo -e "${GRN}▶ Limpiando imágenes colgantes (dangling)...${NC}"
docker image prune -f >/dev/null || true

if [[ $DO_PULL -eq 1 ]]; then
  echo -e "${GRN}▶ docker compose pull (imágenes base)...${NC}"
  docker compose -f "$COMPOSE_FILE" pull || true
fi

if [[ $DO_BUILD -eq 1 ]]; then
  echo -e "${GRN}▶ Reconstruyendo imágenes (build limpio)...${NC}"
  docker compose -f "$COMPOSE_FILE" build --no-cache
fi

echo -e "${GRN}▶ Levantando servicios...${NC}"
docker compose -f "$COMPOSE_FILE" up -d

echo -e "${CYA}==============================================${NC}"
echo -e "${GRN}🚀 Listo. Revisión rápida:${NC}"
docker compose ps
echo -e "${CYA}==============================================${NC}"
echo -e "${YEL}Nota:${NC} Si eliminaste la caché Whisper, la primera transcripción descargará el modelo."
echo -e "${YEL}Usa:${NC}  curl -f http://localhost:8000/health  (si tienes health endpoint)"
