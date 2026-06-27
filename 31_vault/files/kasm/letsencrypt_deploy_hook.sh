#!/bin/bash
# Hook ejecutado por certbot tras cada renovación exitosa.
# Copia los nuevos certs a Kasm y reinicia el contenedor.

set -e

KASM_DIR="/opt/kasm"
KASM_CERT_DIR="${KASM_DIR}/data/opt/kasm/current/certs"

cp "${RENEWED_LINEAGE}/fullchain.pem" "${KASM_CERT_DIR}/kasm.crt"
cp "${RENEWED_LINEAGE}/privkey.pem"   "${KASM_CERT_DIR}/kasm.key"
chmod 644 "${KASM_CERT_DIR}/kasm.crt"
chmod 600 "${KASM_CERT_DIR}/kasm.key"

cd "${KASM_DIR}" && docker compose restart kasm

echo "Certificado renovado y Kasm reiniciado para ${RENEWED_DOMAINS}"