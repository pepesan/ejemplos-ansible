#!/bin/bash
# Full install using a placeholder domain. kasm_base_domain has no sane
# default outside this project's own deployments on purpose — you must
# always pass a real one.
#
# Usage: ./01_install_default_domain.sh [inventory]   (default: ./inventory)

set -e

INVENTORY="${1:-inventory}"

ansible-playbook -i "${INVENTORY}" site-kasm.yml \
  -e kasm_base_domain=example.com
