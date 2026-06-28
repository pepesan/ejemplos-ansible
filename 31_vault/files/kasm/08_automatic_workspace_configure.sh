#!/bin/bash

set -e

# ============================================
# CONFIGURACIÓN
# ============================================
KASM_URL="https://127.0.0.1:443"
IMAGE_NAME="${KASM_IMAGE:-pepesan/mi-ubuntu-noble-kasm:1.0}"

case "$IMAGE_NAME" in
  *kasm-go*)
    WORKSPACE_NAME="Ubuntu Noble Go"
    WORKSPACE_DESC="Ubuntu 26.04 con entorno de desarrollo Go"
    ;;
  *)
    WORKSPACE_NAME="Ubuntu Noble Custom"
    WORKSPACE_DESC="Ubuntu 26.04 con IntelliJ, ZAP, Firefox"
    ;;
esac
CORES=4
MEMORY=8589934592 # 8GB en bytes (8 * 1024 * 1024 * 1024)
# ============================================

# Esperar a que Kasm esté listo
echo ">> Esperando a que el servicio Kasm esté listo en ${KASM_URL}..."
until curl -sk --fail "${KASM_URL}" -o /dev/null; do
  echo "Esperando a Kasm..."
  sleep 5
done
echo ">> Kasm está listo. Procediendo..."

echo ">> Comprobando si el workspace ya existe..."
EXISTS=$(docker exec kasm docker exec kasm_db psql -U kasmapp -d kasm -t -c \
  "SELECT 1 FROM images WHERE name = '${IMAGE_NAME}';" | tr -d ' \n')

if [ "$EXISTS" = "1" ]; then
  echo "OK El workspace con la imagen ${IMAGE_NAME} ya está configurado. Omitiendo creación."
  exit 0
fi

# Generar API key y secret
API_KEY=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | head -c 12)
API_KEY_SECRET=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | head -c 32)
SALT=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9-' | head -c 36)
HASH=$(echo -n "${API_KEY_SECRET}${SALT}" | sha256sum | cut -d' ' -f1)

echo ">> Eliminando API key anterior si existe..."
docker exec kasm docker exec kasm_db psql -U kasmapp -d kasm -c \
  "DELETE FROM api_configs WHERE name='auto-generated';"

echo ">> Insertando API key en la base de datos..."
docker exec kasm docker exec kasm_db psql -U kasmapp -d kasm -c "
  INSERT INTO api_configs (name, api_key, api_key_secret_hash, salt, enabled, read_only, created)
  VALUES ('auto-generated', '${API_KEY}', '${HASH}', '${SALT}', true, false, now())
  RETURNING api_id;
"

echo ">> Obteniendo api_id..."
API_ID=$(docker exec kasm docker exec kasm_db psql -U kasmapp -d kasm -t -c \
  "SELECT api_id FROM api_configs WHERE name='auto-generated';" | tr -d ' ')

echo "OK api_id: ${API_ID}"

echo ">> Asignando permiso de administrador (200)..."
docker exec kasm docker exec kasm_db psql -U kasmapp -d kasm -c "
  INSERT INTO group_permissions (permission_id, api_id)
  VALUES (200, '${API_ID}');
"
echo "OK Permiso asignado"

sleep 2

echo ">> Creando workspace..."
PAYLOAD=$(python3 - <<PYEOF
import json
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
        "gpu_count": 0,
        "enabled": True,
        "docker_registry": "https://index.docker.io/v1/",
        "run_config": {
            "environment": {
                "KASM_SVC_SEND_CUT_TEXT": "-SendCutText 0",
                "KASM_SVC_ACCEPT_CUT_TEXT": "-AcceptCutText 0",
                "KASM_SVC_PRINTER": "0"
            },
            "first_launch": {
                "user": "root",
                "cmd": (
                    "chmod -R 000 /home/kasm-user/Desktop/Downloads /home/kasm-user/Desktop/Uploads"
                    " && chown -R root:root /home/kasm-user/Desktop/Downloads /home/kasm-user/Desktop/Uploads"
                    " && systemctl stop cups 2>/dev/null; systemctl disable cups 2>/dev/null"
                )
            }
        }
    }
}
print(json.dumps(payload))
PYEOF
)
RESPONSE=$(curl -sk -X POST "${KASM_URL}/api/public/create_image" \
  -H "Content-Type: application/json" \
  -d "${PAYLOAD}")

echo "Respuesta: ${RESPONSE}"

if echo $RESPONSE | grep -q "image_id"; then
  echo "OK Workspace creado correctamente"
else
  echo "ERROR al crear workspace"
fi

echo ">> Limpiando API key temporal..."
docker exec kasm docker exec kasm_db psql -U kasmapp -d kasm -c \
  "DELETE FROM api_configs WHERE name='auto-generated';"