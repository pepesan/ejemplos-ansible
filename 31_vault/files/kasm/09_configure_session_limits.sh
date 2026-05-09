#!/bin/bash

set -e

# ============================================
# CONFIGURACIÓN
# ============================================
KASM_URL="https://127.0.0.1:443"
# Segundos que Kasm espera sin keepalive antes de actuar (0 = sin límite)
KEEPALIVE_EXPIRATION_SECONDS=0
# Acción cuando expira el keepalive: pause | delete
KEEPALIVE_EXPIRATION_ACTION="pause"
# ============================================

# ============================================
# GENERAR CREDENCIALES API TEMPORALES (solo esta parte usa la BD)
# ============================================
API_KEY=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | head -c 12)
API_KEY_SECRET=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | head -c 32)
SALT=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9-' | head -c 36)
HASH=$(echo -n "${API_KEY_SECRET}${SALT}" | sha256sum | cut -d' ' -f1)

echo ">> Eliminando API key temporal anterior si existe..."
docker exec kasm docker exec kasm_db psql -U kasmapp -d kasm -c \
  "DELETE FROM api_configs WHERE name='session-limit-config';" 2>/dev/null || true

echo ">> Insertando API key temporal..."
docker exec kasm docker exec kasm_db psql -U kasmapp -d kasm -c "
  INSERT INTO api_configs (name, api_key, api_key_secret_hash, salt, enabled, read_only, created)
  VALUES ('session-limit-config', '${API_KEY}', '${HASH}', '${SALT}', true, false, now());
"

API_ID=$(docker exec kasm docker exec kasm_db psql -U kasmapp -d kasm -t -c \
  "SELECT api_id FROM api_configs WHERE name='session-limit-config';" | tr -d ' \n')

echo ">> Asignando permiso de administrador al API key..."
docker exec kasm docker exec kasm_db psql -U kasmapp -d kasm -c \
  "INSERT INTO group_permissions (permission_id, api_id) VALUES (200, '${API_ID}');"

sleep 2

# ============================================
# 1. ACTUALIZAR keepalive_expiration VÍA API
#    (el setting global que controla el timeout de 1 hora)
#    El nombre real es "keepalive_expiration", en segundos.
# ============================================
echo ""
echo ">> Obteniendo setting_id de keepalive_expiration vía API..."
SETTINGS_JSON=$(curl -sk -X POST "${KASM_URL}/api/public/get_settings" \
  -H "Content-Type: application/json" \
  -d "{\"api_key\": \"${API_KEY}\", \"api_key_secret\": \"${API_KEY_SECRET}\"}")

KEEPALIVE_SETTING_ID=$(echo "${SETTINGS_JSON}" | python3 -c "
import sys, json
data = json.load(sys.stdin)
for s in data.get('settings', []):
    if s.get('name') == 'keepalive_expiration':
        print(s.get('setting_id', ''))
        break
" 2>/dev/null)

if [ -z "${KEEPALIVE_SETTING_ID}" ]; then
  echo "ERROR: no se encontró keepalive_expiration en la API"
  exit 1
fi
echo "  setting_id: ${KEEPALIVE_SETTING_ID}"

echo ">> Actualizando keepalive_expiration = ${KEEPALIVE_EXPIRATION_SECONDS} vía API..."
RESP=$(curl -sk -X POST "${KASM_URL}/api/public/update_settings" \
  -H "Content-Type: application/json" \
  -d "{
    \"api_key\": \"${API_KEY}\",
    \"api_key_secret\": \"${API_KEY_SECRET}\",
    \"target_setting\": {
      \"setting_id\": \"${KEEPALIVE_SETTING_ID}\",
      \"value\": \"${KEEPALIVE_EXPIRATION_SECONDS}\"
    }
  }")

if echo "${RESP}" | grep -q "setting_id"; then
  echo "OK keepalive_expiration actualizado"
else
  echo "ERR respuesta API: ${RESP}"
fi

# ============================================
# 2. ACTUALIZAR keepalive_expiration_action EN group_settings
#    Este setting NO existe en la tabla global "settings", solo
#    en "group_settings". Los valores allí NO están encriptados,
#    por lo que la actualización directa en BD es la vía correcta.
# ============================================
echo ""
echo ">> Obteniendo group_id de 'All Users'..."
ALL_USERS_GROUP_ID=$(docker exec kasm docker exec kasm_db psql -U kasmapp -d kasm -t -c \
  "SELECT group_id FROM groups WHERE name = 'All Users';" | tr -d ' \n')

if [ -z "${ALL_USERS_GROUP_ID}" ]; then
  echo "ERROR: no se encontró el grupo 'All Users' en la BD"
  exit 1
fi
echo "  group_id: ${ALL_USERS_GROUP_ID}"

echo ">> Upsert de keepalive_expiration_action = ${KEEPALIVE_EXPIRATION_ACTION} en group_settings..."
docker exec kasm docker exec kasm_db psql -U kasmapp -d kasm -c "
  DO \$\$
  BEGIN
    IF EXISTS (
      SELECT 1 FROM group_settings
      WHERE group_id = '${ALL_USERS_GROUP_ID}' AND name = 'keepalive_expiration_action'
    ) THEN
      UPDATE group_settings
      SET value = '${KEEPALIVE_EXPIRATION_ACTION}'
      WHERE group_id = '${ALL_USERS_GROUP_ID}' AND name = 'keepalive_expiration_action';
      RAISE NOTICE 'UPDATE realizado';
    ELSE
      INSERT INTO group_settings (group_id, name, value, value_type, description)
      VALUES (
        '${ALL_USERS_GROUP_ID}',
        'keepalive_expiration_action',
        '${KEEPALIVE_EXPIRATION_ACTION}',
        'string',
        'Action to take when keepalive expires: pause or delete'
      );
      RAISE NOTICE 'INSERT realizado';
    END IF;
  END;
  \$\$;
"

# ============================================
# VERIFICACIÓN FINAL
# ============================================
echo ""
echo ">> Verificando keepalive_expiration vía API..."
VERIFY_JSON=$(curl -sk -X POST "${KASM_URL}/api/public/get_settings" \
  -H "Content-Type: application/json" \
  -d "{\"api_key\": \"${API_KEY}\", \"api_key_secret\": \"${API_KEY_SECRET}\"}")
echo "${VERIFY_JSON}" | python3 -c "
import sys, json
data = json.load(sys.stdin)
for s in data.get('settings', []):
    if s.get('name') == 'keepalive_expiration':
        print('  keepalive_expiration =', s.get('value'), 'segundos')
        break
" 2>/dev/null

echo ">> Verificando keepalive_expiration_action en group_settings..."
docker exec kasm docker exec kasm_db psql -U kasmapp -d kasm -c "
  SELECT name, value, value_type
  FROM group_settings
  WHERE group_id = '${ALL_USERS_GROUP_ID}' AND name = 'keepalive_expiration_action';
"

# ============================================
# LIMPIAR API KEY TEMPORAL
# ============================================
echo ""
echo ">> Limpiando API key temporal..."
docker exec kasm docker exec kasm_db psql -U kasmapp -d kasm -c \
  "DELETE FROM api_configs WHERE name='session-limit-config';"

echo ""
echo "=========================================="
echo "COMPLETADO"
echo "  keepalive_expiration        = ${KEEPALIVE_EXPIRATION_SECONDS}s (0=sin límite)"
echo "  keepalive_expiration_action = ${KEEPALIVE_EXPIRATION_ACTION}"
echo "=========================================="