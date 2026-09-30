#!/bin/bash

set -e

# ============================================
# CONFIGURACIÓN
# ============================================
KASM_URL="https://127.0.0.1:443"
# Segundos que Kasm espera sin keepalive antes de actuar. Por defecto 1 hora, tras
# la cual la sesión se pausa (ver KEEPALIVE_EXPIRATION_ACTION).
# NO usar 0 como "sin límite": Kasm no lo respeta y aplica igualmente el valor de
# fábrica (3600 s), comprobado en una sesión real (expiration_date = keepalive + 3600).
# Para mantener las sesiones más tiempo (ej. 7 días = 604800):
#   KASM_KEEPALIVE_SECONDS=604800 bash 09_configure_session_limits.sh
KEEPALIVE_EXPIRATION_SECONDS="${KASM_KEEPALIVE_SECONDS:-3600}"
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

# La API key temporal se borra siempre al salir, también si el script falla a medias
cleanup_api_key() {
  docker exec kasm docker exec kasm_db psql -U kasmapp -d kasm -c \
    "DELETE FROM api_configs WHERE name='session-limit-config';" >/dev/null 2>&1 || true
}
trap cleanup_api_key EXIT

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
# 1. AJUSTE GLOBAL keepalive_expiration (solo informativo)
#    La API pública update_setting rechaza cualquier payload probado ("Missing
#    required parameters") y el valor global está cifrado en la BD, así que no se
#    puede escribir desde aquí. El valor efectivo se fija a nivel del grupo
#    'All Users' (paso 2), que tiene prioridad sobre el global.
# ============================================
echo ""
echo ">> Leyendo keepalive_expiration global (valor de fábrica, no se modifica)..."
SETTINGS_JSON=$(curl -sk -X POST "${KASM_URL}/api/public/get_settings" \
  -H "Content-Type: application/json" \
  -d "{\"api_key\": \"${API_KEY}\", \"api_key_secret\": \"${API_KEY_SECRET}\"}")
echo "${SETTINGS_JSON}" | python3 -c "
import sys, json
data = json.load(sys.stdin)
for s in data.get('settings', []):
    if s.get('name') == 'keepalive_expiration':
        print('  global keepalive_expiration =', s.get('value'), 'segundos (no modificado)')
        break
" 2>/dev/null || echo "  (no se pudo leer el ajuste global)"

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

echo ">> Upsert de keepalive_expiration = ${KEEPALIVE_EXPIRATION_SECONDS} en group_settings..."
# El grupo 'All Users' trae de fábrica su propio override de keepalive_expiration
# (group_settings), que tiene prioridad sobre el valor global actualizado por la
# API en el paso 1. Si no se actualiza aquí también, el timeout real seguirá
# siendo el de fábrica (3600s) aunque la API confirme el cambio global.
docker exec kasm docker exec kasm_db psql -U kasmapp -d kasm -c "
  DO \$\$
  BEGIN
    IF EXISTS (
      SELECT 1 FROM group_settings
      WHERE group_id = '${ALL_USERS_GROUP_ID}' AND name = 'keepalive_expiration'
    ) THEN
      UPDATE group_settings
      SET value = '${KEEPALIVE_EXPIRATION_SECONDS}'
      WHERE group_id = '${ALL_USERS_GROUP_ID}' AND name = 'keepalive_expiration';
      RAISE NOTICE 'UPDATE keepalive_expiration (group) realizado';
    ELSE
      INSERT INTO group_settings (group_id, name, value, value_type, description)
      VALUES (
        '${ALL_USERS_GROUP_ID}',
        'keepalive_expiration',
        '${KEEPALIVE_EXPIRATION_SECONDS}',
        'int',
        'The number of seconds a Kasm will stay alive unless a keepalive request is sent from the client.'
      );
      RAISE NOTICE 'INSERT keepalive_expiration (group) realizado';
    END IF;
  END;
  \$\$;
"

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
        ('allow_kasm_clipboard_down', '${ALLOW_CLIPBOARD_DOWNSTREAM}', 'bool', 'Disallow copying text from inside Kasm to host'),
        ('allow_kasm_clipboard_up', '${ALLOW_CLIPBOARD_UPSTREAM}', 'bool', 'Disallow copying text from host to inside Kasm'),
        ('allow_kasm_clipboard_seamless', '${ALLOW_CLIPBOARD_SEAMLESS}', 'bool', 'Disallow seamless clipboard (Chromium)'),
        ('allow_kasm_downloads', '${ALLOW_FILE_DOWNLOAD}', 'bool', 'Disallow downloading files from Kasm to host'),
        ('allow_kasm_uploads', '${ALLOW_FILE_UPLOAD}', 'bool', 'Disallow uploading files from host to Kasm'),
        ('allow_kasm_printing', '${ALLOW_PRINTING}', 'bool', 'Disallow printing inside Kasm sessions')
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
# Comprobación dura: el valor leído de la BD debe ser el pedido, si no el script falla
APPLIED_KEEPALIVE=$(docker exec kasm docker exec kasm_db psql -U kasmapp -d kasm -t -c \
  "SELECT value FROM group_settings WHERE group_id = '${ALL_USERS_GROUP_ID}' AND name = 'keepalive_expiration';" | tr -d ' \n')
if [ "${APPLIED_KEEPALIVE}" != "${KEEPALIVE_EXPIRATION_SECONDS}" ]; then
  echo "ERROR: keepalive_expiration del grupo es '${APPLIED_KEEPALIVE}', se esperaba '${KEEPALIVE_EXPIRATION_SECONDS}'" >&2
  exit 1
fi

echo ">> Verificando keepalive_expiration y keepalive_expiration_action en group_settings..."
docker exec kasm docker exec kasm_db psql -U kasmapp -d kasm -c "
  SELECT name, value, value_type
  FROM group_settings
  WHERE group_id = '${ALL_USERS_GROUP_ID}' AND name IN ('keepalive_expiration', 'keepalive_expiration_action');
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
cleanup_api_key

echo ""
echo "=========================================="
echo "COMPLETADO"
echo "  keepalive_expiration        = ${KEEPALIVE_EXPIRATION_SECONDS}s (grupo All Users, leído de la BD)"
echo "  keepalive_expiration_action = ${KEEPALIVE_EXPIRATION_ACTION}"
echo "  allow_kasm_clipboard_down     = ${ALLOW_CLIPBOARD_DOWNSTREAM}"
echo "  allow_kasm_clipboard_up       = ${ALLOW_CLIPBOARD_UPSTREAM}"
echo "  allow_kasm_clipboard_seamless = ${ALLOW_CLIPBOARD_SEAMLESS}"
echo "  allow_kasm_downloads          = ${ALLOW_FILE_DOWNLOAD}"
echo "  allow_kasm_uploads            = ${ALLOW_FILE_UPLOAD}"
echo "  allow_printing                = ${ALLOW_PRINTING}"
echo "=========================================="