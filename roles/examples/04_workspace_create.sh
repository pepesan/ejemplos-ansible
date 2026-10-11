#!/bin/bash
# Creates a workspace using the default example image. Requires Kasm
# already installed (01/02/03 above).
#
# Usage: ./04_workspace_create.sh [inventory]   (default: ./inventory)

set -e

INVENTORY="${1:-inventory}"
IMAGE="pepesan/mi-ubuntu-resolute-kasm:1.0"

ansible-playbook -i "${INVENTORY}" kasm-workspace.yml \
  -e kasm_workspace_state=present \
  -e kasm_docker_image_name="${IMAGE}" \
  -e kasm_workspace_image="${IMAGE}" \
  -e '{"kasm_workspace_name": "Example workspace"}'
