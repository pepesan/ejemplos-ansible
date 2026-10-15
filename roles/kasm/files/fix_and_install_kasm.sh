#!/bin/bash

set -e

# ============================================
# CONFIG
# ============================================
ADMIN_PASSWORD="${KASM_ADMIN_PASSWORD:?KASM_ADMIN_PASSWORD is not set}"
USER_PASSWORD="${KASM_USER_PASSWORD:?KASM_USER_PASSWORD is not set}"
# ============================================

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

# Redirect output to a log file (reachable from the host at /opt/kasm/data/opt/kasm_deploy.log)
LOG_FILE="/opt/kasm_deploy.log"
exec 1> >(tee "${LOG_FILE}") 2>&1

# Our own marker, written once install.sh finishes successfully (see bottom of
# this script). Not relying on a Kasm-internal file here on purpose: the
# binary/path we used to check (bin/kasm_server) does not exist at all in
# Kasm 1.19.0 — it was a leftover assumption from an older Kasm release, and
# its absence silently made this check always false, triggering a full
# reinstall (new self-signed cert, new sidecar network, etc.) on every single
# run. Confirmed the hard way on Contabo E2E testing (2026-10-09).
MARKER_FILE="/opt/kasm_install_complete"
if [ -f "${MARKER_FILE}" ]; then
    echo -e "${GREEN}Kasm is already installed. Skipping installation.${NC}"
    exit 0
fi

echo -e "${YELLOW}>> Fixing a bug in install.sh...${NC}"
sed -i "s/'install-depends',/'install-depends'/" /kasm_release/install.sh
echo -e "${GREEN}OK Bug fixed${NC}"

echo -e "${YELLOW}>> Adding install-depends to the noninteractive profile...${NC}"
grep -q "install-depends" /kasm_release/profiles/noninteractive.yaml || \
    echo "install-depends: false" >> /kasm_release/profiles/noninteractive.yaml
echo -e "${GREEN}OK Profile updated${NC}"

# The core services Kasm cannot work without. Their absence after install.sh
# means the install did NOT complete, whatever the exit code said: install.sh
# aborts early when one of its Docker plugins (kasmweb/logger, kasmweb/sidecar)
# is not yet answering on its socket at the moment Docker tries to enable it
# ("dial unix .../kasmlogger.sock: connect: connection refused"). That is a
# timing race, not a persistent fault: the plugin is up a few seconds later.
core_services_up() {
  local c
  for c in kasm_db kasm_api kasm_manager; do
    docker ps --format '{{.Names}}' | grep -qx "$c" || return 1
  done
  return 0
}

# Enables any installed-but-disabled Docker plugin (the ones the race above
# leaves behind) so the next install.sh attempt does not depend on the race.
enable_disabled_plugins() {
  local p
  for p in $(docker plugin ls --format '{{.Name}} {{.Enabled}}' | awk '$2=="false"{print $1}'); do
    echo -e "${YELLOW}>> Enabling plugin ${p}...${NC}"
    docker plugin enable "$p" || true
  done
}

MAX_ATTEMPTS=3
ATTEMPT=1
while true; do
  echo -e "${YELLOW}>> Installing Kasm (attempt ${ATTEMPT}/${MAX_ATTEMPTS})...${NC}"
  # install.sh can exit non-zero on a kasm_manager healthcheck timeout even when
  # the installation actually completed fine. Capture the error and recover.
  set +e
  bash /kasm_release/install.sh \
    --install-profile noninteractive \
    --admin-password "${ADMIN_PASSWORD}" \
    --user-password "${USER_PASSWORD}"
  INSTALL_EXIT=$?
  set -e

  if [ $INSTALL_EXIT -ne 0 ]; then
    echo -e "${YELLOW}>> Installer exited with an error ($INSTALL_EXIT). Checking pending containers...${NC}"
    CREATED=$(docker ps -a --filter "status=created" --format "{{.Names}}")
    if [ -n "$CREATED" ]; then
      echo -e "${YELLOW}>> Starting containers in Created state: $CREATED${NC}"
      docker start $CREATED
      echo -e "${GREEN}OK Containers started${NC}"
    fi

    echo -e "${YELLOW}>> Waiting for services to become healthy (max 120s)...${NC}"
    TIMEOUT=120
    ELAPSED=0
    while [ $ELAPSED -lt $TIMEOUT ]; do
      UNHEALTHY=$(docker ps --filter "health=unhealthy" --format "{{.Names}}")
      STARTING=$(docker ps --filter "health=starting" --format "{{.Names}}")
      if [ -z "$UNHEALTHY" ] && [ -z "$STARTING" ]; then
        break
      fi
      sleep 5
      ELAPSED=$((ELAPSED + 5))
    done

    if [ $ELAPSED -ge $TIMEOUT ]; then
      echo -e "${YELLOW}WARNING: Timed out waiting. Services still unhealthy: ${UNHEALTHY}${NC}"
    fi
  fi

  # Success is decided by the services being there, not by the exit code.
  if core_services_up; then
    echo -e "${GREEN}OK Core services are up (kasm_db, kasm_api, kasm_manager)${NC}"
    break
  fi

  if [ $ATTEMPT -ge $MAX_ATTEMPTS ]; then
    echo -e "${RED}ERROR: Kasm is not installed after ${MAX_ATTEMPTS} attempts (core services missing). Not writing the install marker.${NC}"
    exit 1
  fi

  echo -e "${YELLOW}>> Core services missing after attempt ${ATTEMPT}; enabling disabled plugins and retrying...${NC}"
  enable_disabled_plugins
  ATTEMPT=$((ATTEMPT + 1))
  sleep 5
done

touch "${MARKER_FILE}"

echo ""
echo -e "${GREEN}==============================${NC}"
echo -e "${GREEN}  OK Kasm installed            ${NC}"
echo -e "${GREEN}==============================${NC}"
echo ""
echo -e "  URL:            ${GREEN}https://localhost:443${NC}"
echo -e "  Admin user:     ${GREEN}admin@kasm.local${NC}"
echo -e "  Admin password: ${GREEN}${ADMIN_PASSWORD}${NC}"
echo -e "  User user:      ${GREEN}user@kasm.local${NC}"
echo -e "  User password:  ${GREEN}${USER_PASSWORD}${NC}"
