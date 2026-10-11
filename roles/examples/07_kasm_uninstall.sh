#!/bin/bash
# Removes an existing Kasm install (container, persisted data) so the next
# run of 01/02/03_install_*.sh is a genuine fresh install. Real TLS certs
# are kept by default — see kasm-uninstall.yml to also force a new one.
#
# Usage: ./07_kasm_uninstall.sh [inventory]   (default: ./inventory)

set -e

INVENTORY="${1:-inventory}"

ansible-playbook -i "${INVENTORY}" kasm-uninstall.yml
