#!/bin/bash
# Borra uno o TODOS los workspaces (imágenes registradas en Kasm), usando acceso
# directo a Postgres (no existe un endpoint público /api/public/delete_image
# documentado ni confirmado en el código de Kasm 1.19.0 — el único "delete_image"
# encontrado es interno de la API de administración autenticada por sesión, no
# por api_key). Es el mismo patrón que ya usa 08_automatic_workspace_configure.sh
# para comprobar existencia.
#
# Modo de uso:
#   KASM_IMAGE=usuario/imagen:tag  bash 12_delete_workspace.sh   # borra solo esa imagen
#   KASM_CLEAN_ALL=true            bash 12_delete_workspace.sh   # borra TODOS los workspaces registrados
#
# Antes de borrar el registro del workspace, cierra (docker rm -f) cualquier sesión
# que esté abierta en ese momento usando esa imagen — si no, "docker rmi" falla por
# estar la imagen en uso y el contenedor queda huérfano, sin workspace al que pertenecer.
#
# Por defecto SÍ borra los directorios de perfil persistente de los usuarios que
# hayan usado cada workspace (IRREVERSIBLE, pierde los datos del escritorio/
# documentos de esos usuarios para esa imagen). Es el default a propósito: ese
# perfil se indexa por image_id, no por workspace, así que si se deja vivo puede
# arrastrar contenido de una versión anterior de la imagen a un workspace nuevo
# que reutilice el mismo image_id. Para conservarlos:
#   KASM_DELETE_PERSISTENT_DATA=false
#
# Además, siempre borra la imagen Docker de cada workspace en el DinD de Kasm y
# hace limpieza de layers huérfanos (docker image prune) al final, para liberar
# espacio en disco que Kasm ya no necesita tras retirar el/los workspace(s).

set -e

CLEAN_ALL="${KASM_CLEAN_ALL:-false}"
DELETE_PERSISTENT_DATA="${KASM_DELETE_PERSISTENT_DATA:-true}"

PSQL() {
  docker exec kasm docker exec kasm_db psql -U kasmapp -d kasm "$@"
}

delete_one() {
  local IMAGE_NAME="$1"
  [[ "$IMAGE_NAME" != *:* ]] && IMAGE_NAME="${IMAGE_NAME}:latest"

  echo ""
  echo "======================================================================"
  echo ">> Workspace: ${IMAGE_NAME}"
  echo "======================================================================"

  local IMAGE_ID
  IMAGE_ID=$(PSQL -t -c "SELECT image_id FROM images WHERE name = '${IMAGE_NAME}';" | tr -d ' \n')

  if [ -z "$IMAGE_ID" ]; then
    echo "OK No existe ningún workspace con la imagen ${IMAGE_NAME}. Nada que borrar."
    return 0
  fi

  local PERSISTENT_PROFILE_PATH
  PERSISTENT_PROFILE_PATH=$(PSQL -t -c \
    "SELECT persistent_profile_path FROM images WHERE image_id = '${IMAGE_ID}';" | sed 's/^ *//;s/ *$//')

  echo "OK Workspace encontrado: image_id=${IMAGE_ID}"

  # Cerrar primero las sesiones abiertas de este workspace: si se borra la imagen
  # Docker mientras un contenedor de sesión sigue corriendo, "docker rmi" falla por
  # estar en uso, y el contenedor queda huérfano (sin fila en "images" a la que
  # apuntar). Se borran por "ancestor" (todo contenedor arrancado desde esta imagen),
  # no por user_id, para no depender de ninguna API key ni de qué usuario la abrió.
  echo ""
  echo ">> Comprobando sesiones activas de este workspace..."
  local SESSION_CONTAINERS
  SESSION_CONTAINERS=$(docker exec kasm docker ps -q --filter "ancestor=${IMAGE_NAME}")
  if [ -n "$SESSION_CONTAINERS" ]; then
    echo ">> Cerrando sesión(es) activa(s): $(echo "$SESSION_CONTAINERS" | tr '\n' ' ')"
    docker exec kasm docker rm -f $SESSION_CONTAINERS
    echo "OK Sesión(es) cerrada(s)."
  else
    echo "OK No hay sesiones activas de este workspace."
  fi
  # Limpiar también cualquier fila de "kasms" que quedara apuntando a esos
  # contenedores ya eliminados (evita el mismo patrón de filas huérfanas
  # "operational_status=running" sin contenedor real detrás, documentado en
  # PLAN.md para el caso de RestartPolicy unless-stopped tras un reinicio).
  PSQL -c "DELETE FROM kasms WHERE image_id = '${IMAGE_ID}';" >/dev/null

  # Los directorios de perfil persistido se buscan en disco (glob dentro del DinD),
  # no en la tabla "kasms": esa tabla solo tiene filas de sesiones ACTIVAS/recientes,
  # y pierde la fila en cuanto la sesión se destruye — así que una sesión ya cerrada
  # (lo normal al limpiar un workspace) sería invisible aunque su perfil siga en disco.
  local PERSISTED_DIRS=""
  if [ -n "$PERSISTENT_PROFILE_PATH" ]; then
    echo "   persistent_profile_path: ${PERSISTENT_PROFILE_PATH}"
    # OJO: el directorio real en disco usa el image_id CON guiones (formato uuid
    # canónico de Postgres, que es justo lo que ya trae $IMAGE_ID) — no quitarlos.
    local GLOB_PATH="${PERSISTENT_PROFILE_PATH/\{user_id\}/*}"
    GLOB_PATH="${GLOB_PATH/\{username\}/*}"
    GLOB_PATH="${GLOB_PATH/\{image_id\}/$IMAGE_ID}"
    echo ""
    echo ">> Directorios de perfil persistido encontrados en disco (${GLOB_PATH}):"
    PERSISTED_DIRS=$(docker exec kasm sh -c "ls -d ${GLOB_PATH} 2>/dev/null" || true)
    if [ -z "$PERSISTED_DIRS" ]; then
      echo "   (ninguno todavía)"
    else
      while read -r dir; do
        [ -z "$dir" ] && continue
        echo "   - ${dir}"
      done <<< "$PERSISTED_DIRS"
    fi
  else
    echo "   (este workspace no tenía persistencia activada)"
  fi

  echo ""
  echo ">> Borrando registro del workspace en la base de datos..."
  PSQL -c "DELETE FROM images WHERE image_id = '${IMAGE_ID}';"
  echo "OK Workspace '${IMAGE_NAME}' borrado del catálogo de Kasm."

  if [ "$DELETE_PERSISTENT_DATA" = "true" ] && [ -n "$PERSISTED_DIRS" ]; then
    echo ""
    echo ">> KASM_DELETE_PERSISTENT_DATA=true: borrando directorios de perfil persistente..."
    while read -r dir; do
      [ -z "$dir" ] && continue
      echo "   Borrando ${dir}..."
      docker exec kasm rm -rf "${dir}"
    done <<< "$PERSISTED_DIRS"
    echo "OK Directorios de perfil persistente borrados."
  elif [ "$DELETE_PERSISTENT_DATA" != "true" ] && [ -n "$PERSISTED_DIRS" ]; then
    echo ""
    echo "AVISO Los directorios de perfil persistente listados arriba NO se han borrado."
    echo "      Para borrarlos también: -e kasm_delete_persistent_data=true"
  fi

  echo ""
  echo ">> Borrando imagen Docker '${IMAGE_NAME}' del DinD de Kasm para liberar espacio..."
  if docker exec kasm docker rmi "${IMAGE_NAME}" 2>&1; then
    echo "OK Imagen '${IMAGE_NAME}' borrada."
  else
    echo "AVISO No se pudo borrar la imagen '${IMAGE_NAME}' (puede estar en uso por una sesión activa"
    echo "      o compartida con otro tag). El workspace ya está borrado del catálogo igualmente."
  fi
}

if [ "$CLEAN_ALL" = "true" ]; then
  echo ">> KASM_CLEAN_ALL=true: se van a borrar TODOS los workspaces registrados en Kasm."
  ALL_IMAGES=$(PSQL -t -c "SELECT name FROM images;" | sed 's/^ *//;s/ *$//' | grep -v '^$' || true)
  if [ -z "$ALL_IMAGES" ]; then
    echo "OK No hay ningún workspace registrado. Nada que borrar."
  else
    echo "Workspaces encontrados:"
    echo "$ALL_IMAGES" | sed 's/^/   - /'
    while read -r img; do
      [ -z "$img" ] && continue
      delete_one "$img"
    done <<< "$ALL_IMAGES"
  fi
else
  IMAGE_NAME="${KASM_IMAGE:?ERR: KASM_IMAGE es obligatorio (ej. usuario/imagen:1.0), o usa KASM_CLEAN_ALL=true}"
  delete_one "$IMAGE_NAME"
fi

echo ""
echo "======================================================================"
echo ">> Limpiando layers/imágenes huérfanas (dangling) que ya no usa ningún workspace/contenedor..."
docker exec kasm docker image prune -f || true
echo "OK Limpieza de espacio en disco completada."
