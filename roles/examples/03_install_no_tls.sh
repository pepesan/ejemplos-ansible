#!/bin/bash
# Local/DNS-less install: disables real Let's Encrypt TLS, Kasm stays
# reachable over its self-signed certificate. Useful for
# inventory-prueba-kasm-local/-lxc style environments.
#
# Usage: ./03_install_no_tls.sh [inventory]   (default: ./inventory)

set -e

INVENTORY="${1:-inventory}"

ansible-playbook -i "${INVENTORY}" site-kasm.yml \
  -e kasm_base_domain=example.com \
  -e kasm_letsencrypt_enabled=false
