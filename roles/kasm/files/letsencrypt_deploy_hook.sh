#!/bin/bash
# Hook run by certbot after every successful renewal.
# Copies the new certs into Kasm and restarts the container.

set -e

KASM_DIR="/opt/kasm"
KASM_CERT_DIR=$(find "${KASM_DIR}/data/opt/kasm" -name "kasm_nginx.crt" 2>/dev/null | head -1 | xargs dirname)

cp "${RENEWED_LINEAGE}/fullchain.pem" "${KASM_CERT_DIR}/kasm_nginx.crt"
cp "${RENEWED_LINEAGE}/privkey.pem"   "${KASM_CERT_DIR}/kasm_nginx.key"
chmod 644 "${KASM_CERT_DIR}/kasm_nginx.crt"
chmod 600 "${KASM_CERT_DIR}/kasm_nginx.key"

docker exec kasm docker restart kasm_proxy

echo "Certificate renewed and kasm_proxy restarted for ${RENEWED_DOMAINS}"
