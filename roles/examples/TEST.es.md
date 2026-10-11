# Plan de pruebas E2E — máquina real de Contabo

Valida los roles de este directorio contra la máquina real ya existente en
producción, que ya sirve a alumnos vía `31_vault`, en vez de solo contra
VMs/contenedores desechables. Es un host real con DNS público apuntando —
tratarlo con el mismo cuidado que un despliegue en producción.

**Inventario**: `inventory-prueba-kasm-contabo` (copiado de
`31_vault/inventory-prueba-kasm-contabo`; coincide con el patrón
`inventory-*` del `.gitignore`, así que nunca se commitea).
`node_name=kasmcontabo`, `ansible_user=root`. **Nunca escribir la IP real
en ningún fichero tracked por git.**

**Dominio**: `kasm_base_domain=kasm.cursosdedesarrollo.com` (ya es el valor
por defecto en `../../31_vault/group_vars/all/vars.yml`). Con
`node_name=kasmcontabo`, `kasm_domain` resuelve a
`kasmcontabo.kasm.cursosdedesarrollo.com` — coincide con la URL real ya
operativa, `https://kasmcontabo.kasm.cursosdedesarrollo.com/`.

Antes de ejecutar nada: esta máquina ya tiene Kasm instalado y en uso real
— confirmar si se ejecuta contra esta instancia ya viva (reinstalar) o se
reserva antes una ventana de mantenimiento, ya que `kasm` no es puramente
aditivo sobre una instalación ya existente del mismo host.

## 1. Instalar dependencias de Galaxy (una sola vez)

```bash
ansible-galaxy role install -r roles/requirements.yml
```

## 2. Instalación completa (Docker, usuario alumno, Kasm con TLS real, ajustes de grupo)

```bash
cd roles/examples
ansible-playbook -i inventory-prueba-kasm-contabo site-kasm.yml \
  -e kasm_base_domain=kasm.cursosdedesarrollo.com \
  -e letsencrypt_email=pepesan@gmail.com \
  2>&1 | tee /tmp/e2e-contabo-install.log
```

Seguir el progreso en vivo desde otra terminal con
`tail -f /tmp/e2e-contabo-install.log`.

## 3. Verificar HTTPS real

```bash
curl -sk -o /dev/null -w "%{http_code}\n" https://kasmcontabo.kasm.cursosdedesarrollo.com/
```

Se espera `200` o `302`. Confirmar que el certificado es real (no autofirmado):

```bash
openssl s_client -connect kasmcontabo.kasm.cursosdedesarrollo.com:443 \
  -servername kasmcontabo.kasm.cursosdedesarrollo.com </dev/null 2>/dev/null \
  | openssl x509 -noout -issuer
```

## 4. Segunda pasada (comprobación de idempotencia)

Reejecutar exactamente el mismo comando del paso 2. Nada debería reportar
`changed`, salvo quizá la task del CSV de credenciales si su contenido
difiere de verdad.

```bash
ansible-playbook -i inventory-prueba-kasm-contabo site-kasm.yml \
  -e kasm_base_domain=kasm.cursosdedesarrollo.com \
  -e letsencrypt_email=pepesan@gmail.com \
  2>&1 | tee /tmp/e2e-contabo-install-2.log
```

## 5. Crear un workspace de prueba

```bash
ansible-playbook -i inventory-prueba-kasm-contabo kasm-workspace.yml \
  -e kasm_workspace_state=present \
  -e kasm_docker_image_name=pepesan/mi-ubuntu-resolute-kasm:1.0 \
  -e kasm_workspace_image=pepesan/mi-ubuntu-resolute-kasm:1.0 \
  -e '{"kasm_workspace_name": "E2E test workspace"}' \
  2>&1 | tee /tmp/e2e-contabo-workspace.log
```

Confirmar desde el panel admin que la sesión llega a `running`.

## 6. Borrar el workspace de prueba (limpieza)

```bash
ansible-playbook -i inventory-prueba-kasm-contabo kasm-workspace.yml \
  -e kasm_workspace_state=absent \
  -e kasm_docker_image_name=pepesan/mi-ubuntu-resolute-kasm:1.0 \
  -e kasm_workspace_image=pepesan/mi-ubuntu-resolute-kasm:1.0 \
  2>&1 | tee /tmp/e2e-contabo-workspace-delete.log
```

## Reportar resultados

Marcar cada paso simplemente como validado o no, con su log como
evidencia — sin el matiz de "validado, pendiente de confirmación humana",
solo un pass/fail plano por paso.
