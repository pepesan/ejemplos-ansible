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
# Por defecto NO borra los directorios de perfil persistente de los usuarios que
# hayan usado cada workspace — solo los lista. Para borrarlos también (IRREVERSIBLE,
# pierde los datos del escritorio/documentos de esos usuarios para esa imagen):
#   KASM_DELETE_PERSISTENT_DATA=true
#
# Además, siempre borra la imagen Docker de cada workspace en el DinD de Kasm y
# hace limpieza de layers huérfanos (docker image prune) al final, para liberar
# espacio en disco que Kasm ya no necesita tras retirar el/los workspace(s).

set -e

CLEAN_ALL="${KASM_CLEAN_ALL:-false}"
DELETE_PERSISTENT_DATA="${KASM_DELETE_PERSISTENT_DATA:-false}"

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
  local USER_IDS=""
  if [ -n "$PERSISTENT_PROFILE_PATH" ]; then
    echo "   persistent_profile_path: ${PERSISTENT_PROFILE_PATH}"
    echo ""
    echo ">> Usuarios que han usado este workspace (tendrán un directorio de perfil persistido):"
    USER_IDS=$(PSQL -t -c "SELECT DISTINCT user_id FROM kasms WHERE image_id = '${IMAGE_ID}';" | tr -d ' ' | grep -v '^$' || true)
    if [ -z "$USER_IDS" ]; then
      echo "   (ninguno todavía)"
    else
      while read -r uid; do
        [ -z "$uid" ] && continue
        local uname
        uname=$(PSQL -t -c "SELECT username FROM users WHERE user_id = '${uid}';" | tr -d ' ')
        local REAL_PATH="${PERSISTENT_PROFILE_PATH/\{user_id\}/$uid}"
        REAL_PATH="${REAL_PATH/\{username\}/$uname}"
        REAL_PATH="${REAL_PATH/\{image_id\}/$(echo "$IMAGE_ID" | tr -d '-')}"
        echo "   - ${uname} (${uid}) -> ${REAL_PATH}"
      done <<< "$USER_IDS"
    fi
  else
    echo "   (este workspace no tenía persistencia activada)"
  fi

  echo ""
  echo ">> Borrando registro del workspace en la base de datos..."
  PSQL -c "DELETE FROM images WHERE image_id = '${IMAGE_ID}';"
  echo "OK Workspace '${IMAGE_NAME}' borrado del catálogo de Kasm."

  if [ "$DELETE_PERSISTENT_DATA" = "true" ] && [ -n "$PERSISTENT_PROFILE_PATH" ] && [ -n "$USER_IDS" ]; then
    echo ""
    echo ">> KASM_DELETE_PERSISTENT_DATA=true: borrando directorios de perfil persistente..."
    while read -r uid; do
      [ -z "$uid" ] && continue
      local uname
      uname=$(PSQL -t -c "SELECT username FROM users WHERE user_id = '${uid}';" | tr -d ' ' 2>/dev/null || true)
      local REAL_PATH="${PERSISTENT_PROFILE_PATH/\{user_id\}/$uid}"
      REAL_PATH="${REAL_PATH/\{username\}/$uname}"
      REAL_PATH="${REAL_PATH/\{image_id\}/$(echo "$IMAGE_ID" | tr -d '-')}"
      echo "   Borrando ${REAL_PATH}..."
      docker exec kasm rm -rf "${REAL_PATH}"
    done <<< "$USER_IDS"
    echo "OK Directorios de perfil persistente borrados."
  elif [ "$DELETE_PERSISTENT_DATA" != "true" ] && [ -n "$PERSISTENT_PROFILE_PATH" ]; then
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
