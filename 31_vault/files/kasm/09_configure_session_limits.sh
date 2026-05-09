#!/bin/bash

set -e

# ============================================
# CONFIGURACIÓN
# ============================================
KASM_URL="https://127.0.0.1:443"
# 0 = sin límite, o número de minutos
SESSION_EXPIRATION_MINUTES=0        # Tiempo máximo de sesión (0 = sin límite)
INACTIVE_SESSION_MINUTES=0          # Tiempo de inactividad (0 = sin límite)
KEEPALIVE_EXPIRATION_MINUTES=0      # Tiempo keepalive (0 = sin límite)
KEEPALIVE_EXPIRATION_ACTION="pause" # Acción al expirar keepalive: pause | delete
# ============================================

# ============================================
# GENERAR CREDENCIALES API TEMPORALES
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
# MOSTRAR CONFIGURACIÓN ACTUAL
# ============================================
echo ""
echo "=========================================="
echo "CONFIGURACIÓN ACTUAL DE SESIONES EN LA BASE DE DATOS"
echo "=========================================="
docker exec kasm docker exec kasm_db psql -U kasmapp -d kasm -x -c "
  SELECT *
  FROM configs
  WHERE name ILIKE '%session%'
     OR name ILIKE '%expir%'
     OR name ILIKE '%timeout%'
     OR name ILIKE '%keepalive%'
     OR name ILIKE '%idle%'
     OR name ILIKE '%inactive%';
" 2>/dev/null || echo "(No se encontraron entradas con esos nombres)"

# ============================================
# ACTUALIZAR VÍA API REST
# ============================================
echo ""
echo ">> Consultando configuración actual vía API..."
SETTINGS=$(curl -sk -X POST "${KASM_URL}/api/public/get_settings" \
  -H "Content-Type: application/json" \
  -d "{\"api_key\": \"${API_KEY}\", \"api_key_secret\": \"${API_KEY_SECRET}\"}")
echo "Settings actuales: ${SETTINGS}" | head -c 500
echo ""

echo ">> Actualizando expiración de sesión (session_expiration_minutes = ${SESSION_EXPIRATION_MINUTES})..."
RESP=$(curl -sk -X POST "${KASM_URL}/api/public/update_settings" \
  -H "Content-Type: application/json" \
  -d "{
    \"api_key\": \"${API_KEY}\",
    \"api_key_secret\": \"${API_KEY_SECRET}\",
    \"target_setting\": {
      \"session_expiration_minutes\": ${SESSION_EXPIRATION_MINUTES}
    }
  }")
echo "Respuesta session_expiration: ${RESP}"

echo ">> Actualizando timeout de sesión inactiva (inactive_session_time_limit = ${INACTIVE_SESSION_MINUTES})..."
RESP=$(curl -sk -X POST "${KASM_URL}/api/public/update_settings" \
  -H "Content-Type: application/json" \
  -d "{
    \"api_key\": \"${API_KEY}\",
    \"api_key_secret\": \"${API_KEY_SECRET}\",
    \"target_setting\": {
      \"inactive_session_time_limit\": ${INACTIVE_SESSION_MINUTES}
    }
  }")
echo "Respuesta inactive_session: ${RESP}"

echo ">> Actualizando keepalive (keepalive_expiration_minutes = ${KEEPALIVE_EXPIRATION_MINUTES})..."
RESP=$(curl -sk -X POST "${KASM_URL}/api/public/update_settings" \
  -H "Content-Type: application/json" \
  -d "{
    \"api_key\": \"${API_KEY}\",
    \"api_key_secret\": \"${API_KEY_SECRET}\",
    \"target_setting\": {
      \"keepalive_expiration_minutes\": ${KEEPALIVE_EXPIRATION_MINUTES}
    }
  }")
echo "Respuesta keepalive: ${RESP}"

echo ">> Actualizando acción al expirar keepalive (keepalive_expiration_action = ${KEEPALIVE_EXPIRATION_ACTION})..."
RESP=$(curl -sk -X POST "${KASM_URL}/api/public/update_settings" \
  -H "Content-Type: application/json" \
  -d "{
    \"api_key\": \"${API_KEY}\",
    \"api_key_secret\": \"${API_KEY_SECRET}\",
    \"target_setting\": {
      \"keepalive_expiration_action\": \"${KEEPALIVE_EXPIRATION_ACTION}\"
    }
  }")
echo "Respuesta keepalive_action: ${RESP}"

# ============================================
# ACTUALIZACIÓN DIRECTA EN BASE DE DATOS (fallback)
# Si la API no existe/falla, actualiza directamente
# ============================================
echo ""
echo ">> Actualizando directamente en base de datos (por si acaso)..."

docker exec kasm docker exec kasm_db psql -U kasmapp -d kasm -c "
  UPDATE configs
  SET value = '${SESSION_EXPIRATION_MINUTES}'
  WHERE name = 'session_expiration_minutes';
" 2>/dev/null && echo "OK session_expiration_minutes" || echo "SKIP (columna no encontrada)"

docker exec kasm docker exec kasm_db psql -U kasmapp -d kasm -c "
  UPDATE configs
  SET value = '${INACTIVE_SESSION_MINUTES}'
  WHERE name = 'inactive_session_time_limit';
" 2>/dev/null && echo "OK inactive_session_time_limit" || echo "SKIP (columna no encontrada)"

docker exec kasm docker exec kasm_db psql -U kasmapp -d kasm -c "
  UPDATE configs
  SET value = '${KEEPALIVE_EXPIRATION_MINUTES}'
  WHERE name = 'keepalive_expiration_minutes';
" 2>/dev/null && echo "OK keepalive_expiration_minutes" || echo "SKIP (columna no encontrada)"

docker exec kasm docker exec kasm_db psql -U kasmapp -d kasm -c "
  UPDATE configs
  SET value = '${KEEPALIVE_EXPIRATION_ACTION}'
  WHERE name = 'keepalive_expiration_action';
" 2>/dev/null && echo "OK keepalive_expiration_action" || echo "SKIP (columna no encontrada)"

# ============================================
# MOSTRAR TABLAS DISPONIBLES (diagnóstico)
# ============================================
echo ""
echo "=========================================="
echo "TABLAS DISPONIBLES EN LA BD (diagnóstico)"
echo "=========================================="
docker exec kasm docker exec kasm_db psql -U kasmapp -d kasm -c \
  "\dt" 2>/dev/null | grep -i -E "config|setting|session|expire" || echo "(ninguna tabla relevante encontrada)"

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
echo "  session_expiration_minutes  = ${SESSION_EXPIRATION_MINUTES} (0=sin límite)"
echo "  inactive_session_time_limit = ${INACTIVE_SESSION_MINUTES} (0=sin límite)"
echo "  keepalive_expiration_minutes= ${KEEPALIVE_EXPIRATION_MINUTES} (0=sin límite)"
echo "  keepalive_expiration_action = ${KEEPALIVE_EXPIRATION_ACTION} (pause=suspender, delete=borrar)"
echo ""
echo "NOTA: Si la API no actualizó los valores, revisa la salida de diagnóstico"
echo "      para ver los nombres exactos de las columnas en tu versión de Kasm."
echo "=========================================="
