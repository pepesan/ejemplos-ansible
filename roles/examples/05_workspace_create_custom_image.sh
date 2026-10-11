#!/bin/bash
# Creates a workspace from your own image, with explicit sizing. Note:
# values with spaces must go through the JSON -e form (a plain
# "-e var=value with spaces" truncates at the first space in Ansible).
#
# Usage: ./05_workspace_create_custom_image.sh [inventory] <image> <name>   (inventory default: ./inventory)

set -e

INVENTORY="${1:-inventory}"
IMAGE="${2:?Usage: $0 <inventory> <image> <name>}"
NAME="${3:?Usage: $0 <inventory> <image> <name>}"

ansible-playbook -i "${INVENTORY}" kasm-workspace.yml \
  -e kasm_workspace_state=present \
  -e kasm_docker_image_name="${IMAGE}" \
  -e kasm_workspace_image="${IMAGE}" \
  -e "{\"kasm_workspace_name\": \"${NAME}\"}" \
  -e kasm_workspace_cores=2 \
  -e kasm_workspace_memory_gb=4
