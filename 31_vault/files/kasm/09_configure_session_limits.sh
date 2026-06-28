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

# Configuración de seguridad (bastionado)
ALLOW_CLIPBOARD_DOWNSTREAM="false"
ALLOW_CLIPBOARD_UPSTREAM="false"
ALLOW_CLIPBOARD_SEAMLESS="false"
ALLOW_FILE_DOWNLOAD="false"
ALLOW_FILE_UPLOAD="false"
ALLOW_PRINTING="false"
# ============================================

# Esperar a que Kasm esté listo
echo ">> Esperando a que el servicio Kasm esté listo en ${KASM_URL}..."
until curl -sk --fail "${KASM_URL}" -o /dev/null; do
  echo "Esperando a Kasm..."
  sleep 5
done
echo ">> Kasm está listo. Procediendo con la configuración..."

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
      RAISE NOTICE 'UPDATE keepalive_expiration_action realizado';
    ELSE
      INSERT INTO group_settings (group_id, name, value, value_type, description)
      VALUES (
        '${ALL_USERS_GROUP_ID}',
        'keepalive_expiration_action',
        '${KEEPALIVE_EXPIRATION_ACTION}',
        'string',
        'Action to take when keepalive expires: pause or delete'
      );
      RAISE NOTICE 'INSERT keepalive_expiration_action realizado';
    END IF;
  END;
  \$\$;
"

echo ">> Upsert de directivas de seguridad (bastionado) en group_settings..."
docker exec kasm docker exec kasm_db psql -U kasmapp -d kasm -c "
  DO \$\$
  DECLARE
    v_group_id UUID := '${ALL_USERS_GROUP_ID}';
    v_settings RECORD;
  BEGIN
    FOR v_settings IN 
      SELECT * FROM (VALUES
        ('allow_kasm_clipboard_down', '${ALLOW_CLIPBOARD_DOWNSTREAM}', 'boolean', 'Disallow copying text from inside Kasm to host'),
        ('allow_kasm_clipboard_up', '${ALLOW_CLIPBOARD_UPSTREAM}', 'boolean', 'Disallow copying text from host to inside Kasm'),
        ('allow_kasm_clipboard_seamless', '${ALLOW_CLIPBOARD_SEAMLESS}', 'boolean', 'Disallow seamless clipboard (Chromium)'),
        ('allow_kasm_downloads', '${ALLOW_FILE_DOWNLOAD}', 'boolean', 'Disallow downloading files from Kasm to host'),
        ('allow_kasm_uploads', '${ALLOW_FILE_UPLOAD}', 'boolean', 'Disallow uploading files from host to Kasm'),
        ('allow_kasm_printing', '${ALLOW_PRINTING}', 'boolean', 'Disallow printing inside Kasm sessions')
      ) AS t(name, value, value_type, description)
    LOOP
      IF EXISTS (
        SELECT 1 FROM group_settings
        WHERE group_id = v_group_id AND name = v_settings.name
      ) THEN
        UPDATE group_settings
        SET value = v_settings.value
        WHERE group_id = v_group_id AND name = v_settings.name;
      ELSE
        INSERT INTO group_settings (group_id, name, value, value_type, description)
        VALUES (v_group_id, v_settings.name, v_settings.value, v_settings.value_type, v_settings.description);
      END IF;
    END LOOP;
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

echo ">> Verificando configuraciones de seguridad (bastionado) en group_settings..."
docker exec kasm docker exec kasm_db psql -U kasmapp -d kasm -c "
  SELECT name, value, value_type
  FROM group_settings
  WHERE group_id = '${ALL_USERS_GROUP_ID}'
    AND name IN ('allow_kasm_clipboard_down', 'allow_kasm_clipboard_up', 'allow_kasm_clipboard_seamless', 'allow_kasm_downloads', 'allow_kasm_uploads', 'allow_kasm_printing');
"

# ============================================
# 3. DESACTIVAR PRUNING AGRESIVO DE IMÁGENES
#    En modo Aggressive el agente borra imágenes que no tienen sesión activa,
#    lo que impide que las imágenes personalizadas queden disponibles.
# ============================================
echo ""
echo ">> Desactivando pruning agresivo de imágenes en todos los servidores..."
docker exec kasm docker exec kasm_db psql -U kasmapp -d kasm -c \
  "UPDATE servers SET prune_images_mode = 'No Prune';"
echo "OK prune_images_mode = No Prune"

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
echo "  allow_kasm_clipboard_down     = ${ALLOW_CLIPBOARD_DOWNSTREAM}"
echo "  allow_kasm_clipboard_up       = ${ALLOW_CLIPBOARD_UPSTREAM}"
echo "  allow_kasm_clipboard_seamless = ${ALLOW_CLIPBOARD_SEAMLESS}"
echo "  allow_kasm_downloads          = ${ALLOW_FILE_DOWNLOAD}"
echo "  allow_kasm_uploads            = ${ALLOW_FILE_UPLOAD}"
echo "  allow_printing                = ${ALLOW_PRINTING}"
echo "=========================================="