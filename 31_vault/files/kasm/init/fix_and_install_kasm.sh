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

echo -e "${YELLOW}>> Corrigiendo bug en install.sh...${NC}"
sed -i "s/'install-depends',/'install-depends'/" /kasm_release/install.sh
echo -e "${GREEN}OK Bug corregido${NC}"

echo -e "${YELLOW}>> Añadiendo install-depends al perfil noninteractive...${NC}"
grep -q "install-depends" /kasm_release/profiles/noninteractive.yaml || \
    echo "install-depends: false" >> /kasm_release/profiles/noninteractive.yaml
echo -e "${GREEN}OK Perfil actualizado${NC}"

echo -e "${YELLOW}>> Instalando Kasm...${NC}"
bash /kasm_release/install.sh \
  --install-profile noninteractive \
  --admin-password "${ADMIN_PASSWORD}" \
  --user-password "${USER_PASSWORD}"

echo ""
echo -e "${GREEN}==============================${NC}"
echo -e "${GREEN}  OK Kasm instalado            ${NC}"
echo -e "${GREEN}==============================${NC}"
echo ""
echo -e "  URL:            ${GREEN}https://localhost:443${NC}"
echo -e "  Admin usuario:  ${GREEN}admin@kasm.local${NC}"
echo -e "  Admin password: ${GREEN}${ADMIN_PASSWORD}${NC}"
echo -e "  User password:  ${GREEN}${USER_PASSWORD}${NC}"