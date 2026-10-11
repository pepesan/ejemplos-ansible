#!/bin/bash
# Full install with your own domain and Let's Encrypt email. Requires
# <node_name>.<kasm_base_domain> to already resolve to this host and port 80
# free for the HTTP-01 challenge.
#
# Usage: ./02_install_custom_domain.sh [inventory] <base_domain> <email>   (inventory default: ./inventory)

set -e

INVENTORY="${1:-inventory}"
BASE_DOMAIN="${2:?Usage: $0 <inventory> <base_domain> <email>}"
EMAIL="${3:?Usage: $0 <inventory> <base_domain> <email>}"

ansible-playbook -i "${INVENTORY}" site-kasm.yml \
  -e kasm_base_domain="${BASE_DOMAIN}" \
  -e letsencrypt_email="${EMAIL}"
