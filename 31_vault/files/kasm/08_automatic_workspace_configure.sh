#!/bin/bash

set -e

# ============================================
# CONFIGURACIÓN
# ============================================
KASM_URL="https://127.0.0.1:443"
IMAGE_NAME="${KASM_IMAGE:-pepesan/mi-ubuntu-resolute-kasm:1.0}"
[[ "$IMAGE_NAME" != *:* ]] && IMAGE_NAME="${IMAGE_NAME}:latest"
IMAGE_NAME="${IMAGE_NAME/:latest/:1.0}"

case "$IMAGE_NAME" in
  *resolute*)
    DISTRO_NAME="Ubuntu Resolute"
    DISTRO_DESC="Ubuntu 26.04"
    ;;
  *)
    DISTRO_NAME="Ubuntu Noble"
    DISTRO_DESC="Ubuntu 24.04"
    ;;
esac

# Nombre del repositorio sin tag (ej. pepesan/mi-ubuntu-resolute-kasm-python-dind)
IMAGE_REPO="${IMAGE_NAME%%:*}"

# Las variantes DinD (dockerd interno) terminan en "-dind"
DIND_SUFFIX=""
DIND_DESC=""
if [[ "$IMAGE_REPO" == *-dind ]]; then
  DIND_SUFFIX=" DinD"
  DIND_DESC=" y Docker-in-Docker"
fi

# Los patrones más específicos van primero (java-ciberseguridad y java-spring-boot
# antes que el caso genérico). Se evalúa contra el repositorio, sin el tag.
case "$IMAGE_REPO" in
  *kasm-java-ciberseguridad*)
    WORKSPACE_NAME="${DISTRO_NAME} Java Ciberseguridad${DIND_SUFFIX}"
    WORKSPACE_DESC="${DISTRO_DESC} con entorno Java para ciberseguridad (SDKMAN, Maven, Gradle, JDKs LTS)${DIND_DESC}"
    ;;
  *kasm-java-spring-boot*)
    WORKSPACE_NAME="${DISTRO_NAME} Java Spring Boot${DIND_SUFFIX}"
    WORKSPACE_DESC="${DISTRO_DESC} con entorno Java Spring Boot web (SDKMAN, Maven, Gradle, JDKs LTS)${DIND_DESC}"
    ;;
  *kasm-java*)
    WORKSPACE_NAME="${DISTRO_NAME} Java${DIND_SUFFIX}"
    WORKSPACE_DESC="${DISTRO_DESC} con entorno de desarrollo Java${DIND_DESC}"
    ;;
  *kasm-go*)
    WORKSPACE_NAME="${DISTRO_NAME} Go${DIND_SUFFIX}"
    WORKSPACE_DESC="${DISTRO_DESC} con entorno de desarrollo Go (GoLand, MariaDB)${DIND_DESC}"
    ;;
  *kasm-python*)
    WORKSPACE_NAME="${DISTRO_NAME} Python${DIND_SUFFIX}"
    WORKSPACE_DESC="${DISTRO_DESC} con entorno de desarrollo Python (PyCharm, MariaDB)${DIND_DESC}"
    ;;
  *kasm-desktop)
    WORKSPACE_NAME="${DISTRO_NAME} Desktop"
    WORKSPACE_DESC="${DISTRO_DESC} escritorio base"
    ;;
  *kasm-dind)
    WORKSPACE_NAME="${DISTRO_NAME} DinD"
    WORKSPACE_DESC="${DISTRO_DESC} con IntelliJ, ZAP, Firefox y Docker-in-Docker"
    ;;
  *)
    WORKSPACE_NAME="${DISTRO_NAME} Custom"
    WORKSPACE_DESC="${DISTRO_DESC} con IntelliJ, ZAP, Firefox"
    ;;
esac

# Nombre y descripción explícitos del workspace (opcionales). Si no se indican,
# se usan los deducidos arriba a partir del nombre de la imagen.
#   KASM_WORKSPACE_NAME="Mi workspace" KASM_WORKSPACE_DESC="Descripción"
WORKSPACE_NAME="${KASM_WORKSPACE_NAME:-$WORKSPACE_NAME}"
WORKSPACE_DESC="${KASM_WORKSPACE_DESC:-$WORKSPACE_DESC}"

# Modo privilegiado del contenedor de sesión.
# Por defecto activado: lo necesitan las imágenes DinD para arrancar su dockerd interno.
# Desactivar con: KASM_PRIVILEGED=false
case "${KASM_PRIVILEGED:-true}" in
  true|True|TRUE|yes|1)  PRIVILEGED="True" ;;
  false|False|FALSE|no|0) PRIVILEGED="False" ;;
  *)
    echo "ERR valor inválido de KASM_PRIVILEGED: '${KASM_PRIVILEGED}' (usa true o false)" >&2
    exit 1
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

echo ">> Creando workspace (privileged=${PRIVILEGED})..."
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
print(json.dumps(payload))
PYEOF
)
RESPONSE=$(curl -sk -X POST "${KASM_URL}/api/public/create_image" \
  -H "Content-Type: application/json" \
  -d "${PAYLOAD}") || RESPONSE="curl falló (código $?)"

echo "Respuesta: ${RESPONSE}"

CREATE_OK=true
if echo "$RESPONSE" | grep -q "image_id"; then
  echo "OK Workspace creado correctamente"
else
  # Motivo concreto: la API de Kasm devuelve {"error_message": "..."}; si la
  # respuesta no es JSON (curl falló, proxy caído...) se muestra tal cual.
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

# La API key temporal se limpia siempre, también si la creación falló
echo ">> Limpiando API key temporal..."
docker exec kasm docker exec kasm_db psql -U kasmapp -d kasm -c \
  "DELETE FROM api_configs WHERE name='auto-generated';"

if [ "$CREATE_OK" != "true" ]; then
  exit 1
fi