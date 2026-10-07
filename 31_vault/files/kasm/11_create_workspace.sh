#!/bin/bash
# Crea (o reutiliza si ya existe) un workspace en Kasm, sin tocar el resto del
# despliegue (no reinstala Kasm, no toca swapfile/docker compose). Generalización
# parametrizada de 08_automatic_workspace_configure.sh para poder crear workspaces
# adicionales sobre una instancia de Kasm ya desplegada.

set -e

KASM_URL="https://127.0.0.1:443"
IMAGE_NAME="${KASM_IMAGE:?ERR: KASM_IMAGE es obligatorio (ej. usuario/imagen:1.0)}"
[[ "$IMAGE_NAME" != *:* ]] && IMAGE_NAME="${IMAGE_NAME}:latest"

WORKSPACE_NAME="${KASM_WORKSPACE_NAME:?ERR: KASM_WORKSPACE_NAME es obligatorio}"
WORKSPACE_DESC="${KASM_WORKSPACE_DESC:-$WORKSPACE_NAME}"

case "${KASM_PRIVILEGED:-false}" in
  true|True|TRUE|yes|1)  PRIVILEGED="True" ;;
  false|False|FALSE|no|0) PRIVILEGED="False" ;;
  *)
    echo "ERR valor inválido de KASM_PRIVILEGED: '${KASM_PRIVILEGED}' (usa true o false)" >&2
    exit 1
    ;;
esac

CORES="${KASM_CORES:-4}"
MEMORY_GB="${KASM_MEMORY_GB:-8}"
MEMORY=$(( MEMORY_GB * 1024 * 1024 * 1024 ))
GPU_COUNT="${KASM_GPU_COUNT:-0}"
SESSION_TIME_LIMIT="${KASM_SESSION_TIME_LIMIT:-}"
CATEGORY="${KASM_CATEGORY:-}"
ENABLED="${KASM_ENABLED:-true}"
case "$ENABLED" in
  true|True|TRUE|yes|1)  ENABLED_PY="True" ;;
  false|False|FALSE|no|0) ENABLED_PY="False" ;;
  *) echo "ERR valor inválido de KASM_ENABLED" >&2; exit 1 ;;
esac

# Ruta en el HOST (dentro del DinD de Kasm) que se monta como home del usuario y
# persiste entre sesiones. Debe contener {username} o {user_id}. Vacío = sin persistencia.
PERSISTENT_PROFILE_PATH="${KASM_PERSISTENT_PROFILE_PATH:-}"

# Session Staging (opcional): arranca de antemano N contenedores de este workspace
# para que estén listos antes de que el usuario se conecte, en vez de arrancar en
# frío en el momento de la petición. No hay endpoint público documentado para
# esto (es "AdminApi.create_staging_config", de la API de administración interna,
# no de la api_key pública) — se usa el mismo patrón de acceso directo a Postgres
# que para create/delete workspace.
STAGING_ENABLED="${KASM_STAGING_ENABLED:-false}"
STAGING_NUM_SESSIONS="${KASM_STAGING_NUM_SESSIONS:-1}"
STAGING_EXPIRATION_HOURS="${KASM_STAGING_EXPIRATION_HOURS:-24}"
STAGING_ZONE_NAME="${KASM_STAGING_ZONE_NAME:-default}"

echo ">> Esperando a que el servicio Kasm esté listo en ${KASM_URL}..."
until curl -sk --fail "${KASM_URL}" -o /dev/null; do
  echo "Esperando a Kasm..."
  sleep 5
done
echo ">> Kasm está listo. Procediendo..."

PSQL() {
  docker exec kasm docker exec kasm_db psql -U kasmapp -d kasm "$@"
}

configure_staging() {
  local IMAGE_ID="$1"
  [ "$STAGING_ENABLED" != "true" ] && return 0

  echo ""
  echo ">> Configurando Session Staging (${STAGING_NUM_SESSIONS} sesión(es) precalentada(s))..."
  local ZONE_ID ZONE_PROXY_HOSTNAME
  ZONE_ID=$(PSQL -t -c "SELECT zone_id FROM zones WHERE zone_name = '${STAGING_ZONE_NAME}';" | tr -d ' \n')
  if [ -z "$ZONE_ID" ]; then
    echo "AVISO No existe la zona '${STAGING_ZONE_NAME}'. No se configura staging." >&2
    return 0
  fi

  ZONE_PROXY_HOSTNAME=$(PSQL -t -c "SELECT proxy_hostname FROM zones WHERE zone_id = '${ZONE_ID}';" | sed 's/^ *//;s/ *$//')
  if [ "$ZONE_PROXY_HOSTNAME" = '$request_host$' ]; then
    echo "AVISO La zona '${STAGING_ZONE_NAME}' sigue usando proxy_hostname=\$request_host\$." >&2
    echo "      Kasm documenta que las sesiones staged necesitan un dominio fijo configurado" >&2
    echo "      en la zona (no \$request_host\$). No se toca esa configuración global desde" >&2
    echo "      aquí automáticamente (afecta a todos los workspaces, no solo a este)." >&2
    echo "      Para habilitar staging, configura antes el dominio fijo en la zona desde el" >&2
    echo "      panel admin (Zones -> ${STAGING_ZONE_NAME} -> Hostname) o pide el cambio explícito." >&2
    echo "      Workspace creado, pero SIN staging." >&2
    return 0
  fi

  local EXPIRATION_SECONDS=$(( STAGING_EXPIRATION_HOURS * 3600 ))
  PSQL -c "
    INSERT INTO staging_configs (zone_id, image_id, num_sessions, expiration)
    VALUES ('${ZONE_ID}', '${IMAGE_ID}', ${STAGING_NUM_SESSIONS}, ${EXPIRATION_SECONDS})
    ON CONFLICT (zone_id, image_id) DO UPDATE SET
      num_sessions = EXCLUDED.num_sessions,
      expiration = EXCLUDED.expiration;
  "
  echo "OK Staging configurado: ${STAGING_NUM_SESSIONS} sesión(es) precalentada(s), expiración ${STAGING_EXPIRATION_HOURS}h."
}

echo ">> Comprobando si el workspace ya existe..."
EXISTING_IMAGE_ID=$(PSQL -t -c \
  "SELECT image_id FROM images WHERE name = '${IMAGE_NAME}';" | tr -d ' \n')

if [ -n "$EXISTING_IMAGE_ID" ]; then
  echo "OK El workspace con la imagen ${IMAGE_NAME} ya está configurado. Omitiendo creación."
  configure_staging "$EXISTING_IMAGE_ID"
  exit 0
fi

API_KEY=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | head -c 12)
API_KEY_SECRET=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | head -c 32)
SALT=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9-' | head -c 36)
HASH=$(echo -n "${API_KEY_SECRET}${SALT}" | sha256sum | cut -d' ' -f1)

echo ">> Eliminando API key anterior si existe..."
docker exec kasm docker exec kasm_db psql -U kasmapp -d kasm -c \
  "DELETE FROM api_configs WHERE name='auto-generated-create';"

echo ">> Insertando API key en la base de datos..."
docker exec kasm docker exec kasm_db psql -U kasmapp -d kasm -c "
  INSERT INTO api_configs (name, api_key, api_key_secret_hash, salt, enabled, read_only, created)
  VALUES ('auto-generated-create', '${API_KEY}', '${HASH}', '${SALT}', true, false, now());
"
API_ID=$(docker exec kasm docker exec kasm_db psql -U kasmapp -d kasm -t -c \
  "SELECT api_id FROM api_configs WHERE name='auto-generated-create';" | tr -d ' ')
docker exec kasm docker exec kasm_db psql -U kasmapp -d kasm -c "
  INSERT INTO group_permissions (permission_id, api_id) VALUES (200, '${API_ID}');
"

sleep 2

echo ">> Creando workspace '${WORKSPACE_NAME}' (imagen ${IMAGE_NAME}, cores=${CORES}, memoria=${MEMORY_GB}GB, privileged=${PRIVILEGED})..."
PAYLOAD=$(PERSISTENT_PROFILE_PATH="${PERSISTENT_PROFILE_PATH}" \
  SESSION_TIME_LIMIT="${SESSION_TIME_LIMIT}" \
  CATEGORY="${CATEGORY}" \
  python3 - <<PYEOF
import json, os
payload = {
    "api_key": "${API_KEY}",
    "api_key_secret": "${API_KEY_SECRET}",
    "target_image": {
        "name": "${IMAGE_NAME}",
        "friendly_name": "${WORKSPACE_NAME}",
        "description": "${WORKSPACE_DESC}",
        "image_type": "Container",
        "cores": ${CORES},
        "memory": ${MEMORY},
        "gpu_count": ${GPU_COUNT},
        "enabled": ${ENABLED_PY},
        "docker_registry": "https://index.docker.io/v1/",
        "run_config": json.dumps({
            "privileged": ${PRIVILEGED},
            "environment": {
                "KASM_SVC_SEND_CUT_TEXT": "-SendCutText 0",
                "KASM_SVC_ACCEPT_CUT_TEXT": "-AcceptCutText 0",
                "KASM_SVC_PRINTER": "0"
            }
        }),
        "exec_config": json.dumps({
            "first_launch": {
                "user": "root",
                "cmd": (
                    "chmod -R 000 /home/kasm-user/Desktop/Downloads /home/kasm-user/Desktop/Uploads"
                    " && chown -R root:root /home/kasm-user/Desktop/Downloads /home/kasm-user/Desktop/Uploads"
                    " && systemctl stop cups 2>/dev/null; systemctl disable cups 2>/dev/null"
                )
            }
        })
    }
}

persistent_profile_path = os.environ.get("PERSISTENT_PROFILE_PATH", "").strip()
if persistent_profile_path:
    payload["target_image"]["persistent_profile_path"] = persistent_profile_path

session_time_limit = os.environ.get("SESSION_TIME_LIMIT", "").strip()
if session_time_limit:
    payload["target_image"]["session_time_limit"] = int(session_time_limit)

category = os.environ.get("CATEGORY", "").strip()
if category:
    payload["target_image"]["categories"] = [category]
    payload["target_image"]["default_category"] = category

print(json.dumps(payload))
PYEOF
)
RESPONSE=$(curl -sk -X POST "${KASM_URL}/api/public/create_image" \
  -H "Content-Type: application/json" \
  -d "${PAYLOAD}") || RESPONSE="curl falló (código $?)"

echo "Respuesta: ${RESPONSE}"

CREATE_OK=true
if echo "$RESPONSE" | grep -q "image_id"; then
  echo "OK Workspace '${WORKSPACE_NAME}' creado correctamente"
  NEW_IMAGE_ID=$(echo "$RESPONSE" | python3 -c 'import sys,json; print(json.load(sys.stdin)["image"]["image_id"])' 2>/dev/null || true)
  if [ -n "$NEW_IMAGE_ID" ]; then
    # La API devuelve el image_id sin guiones; las columnas uuid de Postgres lo
    # aceptan igual (Postgres normaliza el formato), no hace falta reformatear.
    configure_staging "$NEW_IMAGE_ID"
  fi
else
  ERROR_DETAIL=$(echo "$RESPONSE" | python3 -c '
import sys, json
raw = sys.stdin.read().strip()
try:
    data = json.loads(raw)
    print(data.get("error_message") or data.get("message") or raw)
except Exception:
    print(raw or "respuesta vacía")
')
  echo "ERROR al crear workspace '${WORKSPACE_NAME}' (imagen ${IMAGE_NAME}): ${ERROR_DETAIL}" >&2
  CREATE_OK=false
fi

echo ">> Limpiando API key temporal..."
docker exec kasm docker exec kasm_db psql -U kasmapp -d kasm -c \
  "DELETE FROM api_configs WHERE name='auto-generated-create';"

if [ "$CREATE_OK" != "true" ]; then
  exit 1
fi
