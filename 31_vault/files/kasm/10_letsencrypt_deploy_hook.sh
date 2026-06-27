#!/bin/bash
# Hook ejecutado por certbot tras cada renovación exitosa.
# Copia los nuevos certs a Kasm y reinicia el contenedor.

set -e

KASM_DIR="/opt/kasm"
KASM_CERT_DIR=$(find "${KASM_DIR}/data/opt/kasm" -name "kasm_nginx.crt" 2>/dev/null | head -1 | xargs dirname)

cp "${RENEWED_LINEAGE}/fullchain.pem" "${KASM_CERT_DIR}/kasm_nginx.crt"
cp "${RENEWED_LINEAGE}/privkey.pem"   "${KASM_CERT_DIR}/kasm_nginx.key"
chmod 644 "${KASM_CERT_DIR}/kasm_nginx.crt"
chmod 600 "${KASM_CERT_DIR}/kasm_nginx.key"

cd "${KASM_DIR}" && docker compose restart kasm

echo "Certificado renovado y Kasm reiniciado para ${RENEWED_DOMAINS}"