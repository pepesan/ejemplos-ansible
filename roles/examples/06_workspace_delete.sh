#!/bin/bash
# Deletes a workspace (and its underlying Docker image). Closes any open
# session first; by default also deletes persistent profile data for that
# image — pass keep_profiles as a 3rd argument to keep it instead.
#
# Usage: ./06_workspace_delete.sh [inventory] <image> [keep_profiles]   (inventory default: ./inventory)

set -e

INVENTORY="${1:-inventory}"
IMAGE="${2:?Usage: $0 <inventory> <image> [keep_profiles]}"
KEEP_PROFILES="${3:-}"

DELETE_PERSISTENT_DATA=true
[ "${KEEP_PROFILES}" = "keep_profiles" ] && DELETE_PERSISTENT_DATA=false

ansible-playbook -i "${INVENTORY}" kasm-workspace.yml \
  -e kasm_workspace_state=absent \
  -e kasm_docker_image_name="${IMAGE}" \
  -e kasm_workspace_image="${IMAGE}" \
  -e kasm_workspace_delete_persistent_data="${DELETE_PERSISTENT_DATA}"
