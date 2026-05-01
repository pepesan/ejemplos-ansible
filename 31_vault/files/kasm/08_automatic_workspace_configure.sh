#!/bin/bash

set -e

# ============================================
# CONFIGURACIÓN
# ============================================
KASM_URL="https://127.0.0.1:443"
IMAGE_NAME="pepesan/mi-ubuntu-noble-kasm:1.0"
WORKSPACE_NAME="Ubuntu Noble Custom"
WORKSPACE_DESC="Ubuntu 24.04 con IntelliJ, ZAP, Firefox"
CORES=4
MEMORY=8589934592 # 8GB en bytes (8 * 1024 * 1024 * 1024)
# ============================================

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
RESPONSE=$(curl -sk -X POST "${KASM_URL}/api/public/create_image" \
  -H "Content-Type: application/json" \
  -d "{
    \"api_key\": \"${API_KEY}\",
    \"api_key_secret\": \"${API_KEY_SECRET}\",
    \"target_image\": {
      \"name\": \"${IMAGE_NAME}\",
      \"friendly_name\": \"${WORKSPACE_NAME}\",
      \"description\": \"${WORKSPACE_DESC}\",
      \"image_type\": \"Container\",
      \"cores\": ${CORES},
      \"memory\": ${MEMORY},
      \"gpu_count\": 0,
      \"enabled\": true
    }
  }")

echo "Respuesta: ${RESPONSE}"

if echo $RESPONSE | grep -q "image_id"; then
  echo "OK Workspace creado correctamente"
else
  echo "ERROR al crear workspace"
fi