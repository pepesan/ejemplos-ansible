#!/bin/bash

set -e

# ============================================
# CONFIGURACIÓN
# ============================================
ADMIN_PASSWORD="${KASM_ADMIN_PASSWORD:-Admin1234}"
USER_PASSWORD="${KASM_USER_PASSWORD:-User1234}"
# ============================================

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Redirigir salida al log (accesible en el host en /opt/kasm/data/opt/kasm_deploy.log)
LOG_FILE="/opt/kasm_deploy.log"
exec 1> >(tee "${LOG_FILE}") 2>&1

# Comprobar si ya está instalado
if [ -f "/opt/kasm/bin/kasm_server" ] || [ -f "/opt/kasm/current/bin/kasm_server" ]; then
    echo -e "${GREEN}Kasm ya está instalado. Omitiendo la instalación.${NC}"
    exit 0
fi

echo -e "${YELLOW}>> Corrigiendo bug en install.sh...${NC}"
sed -i "s/'install-depends',/'install-depends'/" /kasm_release/install.sh
echo -e "${GREEN}OK Bug corregido${NC}"

echo -e "${YELLOW}>> Añadiendo install-depends al perfil noninteractive...${NC}"
grep -q "install-depends" /kasm_release/profiles/noninteractive.yaml || \
    echo "install-depends: false" >> /kasm_release/profiles/noninteractive.yaml
echo -e "${GREEN}OK Perfil actualizado${NC}"

echo -e "${YELLOW}>> Instalando Kasm...${NC}"
# El install.sh puede fallar por timeout de healthcheck de kasm_manager aunque
# la instalación haya completado correctamente. Se captura el error y se recupera.
set +e
bash /kasm_release/install.sh \
  --install-profile noninteractive \
  --admin-password "${ADMIN_PASSWORD}" \
  --user-password "${USER_PASSWORD}"
INSTALL_EXIT=$?
set -e

if [ $INSTALL_EXIT -ne 0 ]; then
  echo -e "${YELLOW}>> El instalador salió con error ($INSTALL_EXIT). Comprobando contenedores pendientes...${NC}"
  CREATED=$(docker ps -a --filter "status=created" --format "{{.Names}}")
  if [ -n "$CREATED" ]; then
    echo -e "${YELLOW}>> Arrancando contenedores en estado Created: $CREATED${NC}"
    docker start $CREATED
    echo -e "${GREEN}OK Contenedores arrancados${NC}"
  fi

  echo -e "${YELLOW}>> Esperando a que los servicios estén healthy (máx 120s)...${NC}"
  TIMEOUT=120
  ELAPSED=0
  while [ $ELAPSED -lt $TIMEOUT ]; do
    UNHEALTHY=$(docker ps --filter "health=unhealthy" --format "{{.Names}}")
    STARTING=$(docker ps --filter "health=starting" --format "{{.Names}}")
    if [ -z "$UNHEALTHY" ] && [ -z "$STARTING" ]; then
      echo -e "${GREEN}OK Todos los servicios están healthy${NC}"
      break
    fi
    sleep 5
    ELAPSED=$((ELAPSED + 5))
  done

  if [ $ELAPSED -ge $TIMEOUT ]; then
    echo -e "${YELLOW}AVISO: Tiempo de espera agotado. Servicios con problemas: ${UNHEALTHY}${NC}"
  fi
fi

echo ""
echo -e "${GREEN}==============================${NC}"
echo -e "${GREEN}  OK Kasm instalado            ${NC}"
echo -e "${GREEN}==============================${NC}"
echo ""
echo -e "  URL:            ${GREEN}https://localhost:443${NC}"
echo -e "  Admin usuario:  ${GREEN}admin@kasm.local${NC}"
echo -e "  Admin password: ${GREEN}${ADMIN_PASSWORD}${NC}"
echo -e "  User password:  ${GREEN}${USER_PASSWORD}${NC}"