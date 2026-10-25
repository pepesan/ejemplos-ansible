# Plan de pruebas E2E — máquina real de Contabo

## Punto de reanudación — LXC local, 24 de octubre de 2026

Este bloque es el estado canónico para continuar las pruebas. No contiene IP,
contraseñas ni API keys. El plan de Contabo empieza en la sección siguiente y
sigue pendiente salvo donde se indique expresamente.

### Roles

| Rol | Estado | Evidencia / siguiente comprobación |
|---|---|---|
| `kasm_docker_image` | **VALIDADO** | `present`/`absent` probados con `hello-world:latest`; segundo `present` real con Go DinD 1.3 descargó la imagen de 9,73 GB mediante el rol. |
| `kasm_workspace` | **VALIDADO** | Creación y `state=absent` + `clean_all=true` reales; catálogo, sesiones, perfiles e imágenes quedaron a cero. Go DinD 1.3 quedó registrado mediante el rol con 2 CPU, 4 GB y el enmascarado de `/dev/dri/renderD128`. |
| `docker` | **VALIDADO E2E (25-oct-2026)** | Instalado desde cero con el rol en Ubuntu 26.04 limpio: Docker 29.9.2, `alumno` en el grupo `docker`. Segunda pasada completa: `changed=0`. |
| `linux_user` | **PENDIENTE E2E actual** | Crear, reejecutar y comprobar usuario/grupos/SSH en una máquina limpia. |
| `student` | **VALIDADO parcial (25-oct-2026)** | Pasó `failed=0` e idempotente (`changed=0`); `alumno` con sudo y clave SSH. Caveat: el usuario `alumno` ya existía (lo crea el script de la skill LXC), así que no se probó la creación desde cero. |
| `kasm` | **VALIDADO E2E (25-oct-2026)** | Servidor `1.19.0-ls154` instalado con el rol sin TLS: 8 contenedores internos sanos, HTTPS responde 200, swap de 4 GB activo. Segunda pasada: `changed=0`. El servidor 1.20 no existe (ver `roles/PLAN.md`): el tag `1.20.0-ls148` de los defaults era inválido y se corrigió. |
| `kasm_credentials` | **VALIDADO E2E (25-oct-2026)** | Generó fila nueva en el CSV `datos-acceso-inventory-lxc.csv` (ignorado por git) y las credenciales son las de Kasm; segunda pasada sin cambios. Pendiente: probar regeneración forzada. |
| `kasm_user` | **PENDIENTE E2E actual** | Crear/reutilizar usuarios y validar acceso real. |
| `kasm_group` | **VALIDADO parcial (25-oct-2026)** | Grupo `All Users` en BD con `idle_disconnect=20`, `keepalive_expiration=3600` (`pause`) y `max_kasms_per_user=5`; segunda pasada `changed=0`. Falta comprobar el efecto real en una sesión. |
| `kasm_session` | **PENDIENTE** | Las sesiones de Terminal/Desktop se lanzaron por API, no mediante este rol. Probar crear, consultar y destruir. |
| `kasm_uninstall` | **PENDIENTE destructivo** | Ejecutar al final de la campaña sobre un nodo desechable y verificar limpieza completa. |

Los roles Galaxy `geerlingguy.docker`, `geerlingguy.swap` y
`geerlingguy.certbot` son dependencias; se validan dentro del E2E de los roles
propios, no como entregables independientes.

#### Molecule (25-oct-2026)

Ejecutado en una VM LXC desechable (`moleculelxc`, ya borrada) con
`molecule test` y el driver Docker, porque los escenarios cargan módulos y
`sysctl` en el kernel compartido y no son seguros en la estación de trabajo.

| Rol | Resultado | Notas |
|---|---|---|
| `docker` | **PASA** | `converge` (`changed=9`), `idempotence` (`changed=0`) y `verify` ("All assertions passed"). Hizo falta añadir `molecule/default/prepare.yml` (caché de apt y `kmod`) y tener `br_netfilter` y `overlay` cargados en el host del escenario. |
| `kasm_workspace` | **PASA (trivial)** | El escenario solo ejecuta 2 tareas; la validación real es el E2E contra el nodo. |
| `kasm` | **NO EJECUTABLE en contenedor** | Falla en `swapon /swapfile` (un contenedor no puede activar swap) y depende de Docker-in-Docker real; el propio `molecule.yml` lo declara solo estructural. Cubierto por el E2E sobre la VM. |

Requisitos del entorno Molecule: colecciones `community.docker`,
`community.general` y `ansible.posix`, y un venv con `molecule`,
`molecule-plugins[docker]` y `docker`.

### Playbooks de `31_vault`

| Playbook | Estado para la próxima sesión |
|---|---|
| `23_crear_workspace.yaml` | **VALIDADO (25-oct-2026, Contabo desde cero)** con `pepesan/mi-ubuntu-resolute-kasm-java-spring-boot-web-dev-dind:1.7` sobre servidor 1.19: `failed=0`, 1 fila en BD, 4 cores. **Idempotente**: repeticiones `changed=0`, también alternando con `25` (pull y creación con `changed_when`). Tag por defecto subido a 1.7. |
| `24_limpiar_workspace.yaml` | **VALIDADO históricamente en Contabo**. En esta sesión se validó el flujo equivalente del rol; **pendiente ejecutar el playbook con Vault** sobre Kasm 1.20. |
| `00_ping.yaml` | **VALIDADO (25-oct-2026, Contabo desde cero)**. |
| `01_docker_install.yaml` | **VALIDADO (25-oct-2026, Contabo desde cero)**: 1ª pasada `changed=7`, repetición `changed=0`. Corregido: ya no desinstala `docker-compose-plugin` en cada pasada (antes `changed=2` siempre). |
| `02_adduser_alumno.yaml` | **VALIDADO (25-oct-2026, Contabo desde cero)**: repetición `changed=0`. Corregido: sal fija de `password_hash` (antes `changed=1` siempre). |
| `20_deploy_kasm.yaml` | Pendiente E2E limpio con servidor Kasm 1.20, workspace, sesión y reinicio. |
| `21_undeploy_kasm.yaml` | Pendiente; ejecutar al final y comprobar contenedores, datos y API key. |
| `22_configure_letsencrypt.yaml` | Pendiente desde cero con DNS real y `certbot renew --dry-run`. |
| `25_instalar_solo_kasm_usuarios.yaml` | **VALIDADO (25-oct-2026, Contabo desde cero)** con Kasm 1.19.0-ls154, Let's Encrypt real (emisor YE2, DNS real), 8 contenedores sanos, HTTPS 200 y CSV de credenciales. **Idempotente**: repeticiones `changed=0`. Corregido: se eliminó `files/kasm/compose.yaml` (duplicado de `templates/compose.yaml.j2` que se pisaba con la copia), scripts con modo 0755 en el repo (con `mode: preserve` se pisaban con `23`), `changed_when`/`register` en instalador, nginx y certificado. |
| `30_reboot.yaml` | Pendiente después del despliegue; comprobar infraestructura y ausencia de sesiones huérfanas. |
| `99_fix_workspace_name.yaml` | Pendiente decidir si sigue siendo necesario o se elimina como migración antigua. |

También quedan sin revalidar en la campaña actual los playbooks auxiliares
`03_sdkman_install.yaml`, `04_01_xrdp_install_gnome.yaml`,
`04_02_xrdp_install_xfce.yaml`, `05_intellij_install.yaml`,
`06_chrome_chromedriver_install.yaml`, `07_system_update.yaml`,
`08_download_git.yaml`, los cuatro `09_install_vscode_*.yaml`,
`10_install_drupal.yaml`, `11_repair_docker.yaml`,
`12_copy_drupal_examples.yaml`, `13_clean_drupal_environment.yaml`,
`14_deploy_docker_compose_jupiter_notebook.yaml`,
`15_deploy_mongodb_tools.yaml`, `16_deploy_terraform_localstack.yaml`,
`17_deploy_mysql_client.yaml`, `18_delete_docker_container.yaml` y
`19_delete_jupyter_docker_container.yaml`. No bloquean la validación de Kasm;
probarlos en una campaña separada para no mezclar fallos.

### Imágenes Kasm 1.20

| Imagen | Estado | Evidencia / bloqueo |
|---|---|---|
| `pepesan/mi-ubuntu-resolute-kasm-terminal:1.1` | **VALIDADA** | Terminal visible; herramientas base presentes; Docker ausente como corresponde a la variante estándar. |
| `pepesan/mi-ubuntu-resolute-kasm-terminal-dind:1.2` | **VALIDADA**; reemplazada por 1.3 | La 1.2 validó terminal visible, `dockerd` operativo y `hello-world`. |
| `pepesan/mi-ubuntu-resolute-kasm-terminal-dind:1.3` | **VALIDADA (manual, 25-oct-2026)** | Registrada mediante roles (2 CPU/4 GB, privilegiado, `/dev/null` sobre `/dev/dri/renderD128`); sesión probada a mano por el usuario: el script `~/launch_docker_twitch.sh` funciona. Sin icono: no hay escritorio. |
| `pepesan/mi-ubuntu-resolute-kasm-dind:1.2` | **VALIDADA**; reemplazada por 1.3 | La 1.2 validó XFCE, `docker ps` y `hello-world`. No llevaba script ni icono de docker-twitch. |
| `pepesan/mi-ubuntu-resolute-kasm-dind:1.3` | **VALIDADA (manual, 25-oct-2026)** | Registrada mediante roles (2 CPU/4 GB, privilegiado); sesión probada a mano por el usuario: el script y el lanzador `.desktop` de docker-twitch funcionan. |
| `pepesan/mi-ubuntu-resolute-kasm-go-dind:1.3` | **VALIDADA (manual, 25-oct-2026)**; reemplazada por 1.4 | Registrada mediante roles (2 CPU/4 GB, ajuste DinD/GPU); probada a mano: "funciona". No llevaba script ni icono de docker-twitch. |
| `pepesan/mi-ubuntu-resolute-kasm-go-dind:1.4` | **VALIDADA (manual, 25-oct-2026)** | Registrada mediante roles (2 CPU/4 GB, privilegiado); sesión probada a mano por el usuario: el script y el lanzador `.desktop` de docker-twitch funcionan. |
| `pepesan/mi-ubuntu-resolute-kasm-go:1.3` | **VALIDADA (manual, 25-oct-2026)** | Registrada mediante roles (2 CPU/4 GB, sin privilegiado ni ajuste `/dev/dri`); sesión lanzada por API y probada a mano por el usuario: "funciona". Sin evidencia por ítem (`go version`, GoLand, VS Code, ausencia de Docker). |
| `pepesan/mi-ubuntu-resolute-kasm-python:1.2` | **VALIDADA (manual, 25-oct-2026)** | Registrada mediante roles (2 CPU/4 GB, sin privilegiado); sesión lanzada por API y probada a mano por el usuario: "funciona". Sin evidencia por ítem (Python, PyCharm, VS Code, ausencia de Docker). La primera petición de sesión tras la descarga dio `No resources are available` (agente sincronizando); el reintento funcionó. |
| `pepesan/mi-ubuntu-resolute-kasm-python-dind:1.4` | **VALIDADA (manual, 25-oct-2026)** | Registrada mediante roles (2 CPU/4 GB, privilegiado, `/dev/null` sobre `/dev/dri/renderD128`); sesión lanzada por API y probada a mano por el usuario: "funciona". Sin evidencia por ítem (Python, PyCharm, VS Code, Docker interno). |
| `pepesan/mi-ubuntu-resolute-kasm-java-spring-boot-web-dev-dind:1.7` | **VALIDADA (manual, 25-oct-2026)** | Registrada mediante roles (4 CPU/8 GB, privilegiado, `/dev/null` sobre `/dev/dri/renderD128`) en la VM nueva de 150 GiB; sesión lanzada por API y probada a mano por el usuario: "funciona". Sin evidencia por ítem (JDK, Maven, Gradle, IDE, Docker). La primera petición de sesión dio `No resources are available`; el reintento funcionó. |
| `pepesan/mi-ubuntu-resolute-kasm-java-ciberseguridad-dind:1.3` | **REEMPLAZADA por 1.4** | La 1.3 no tenía script, icono ni lanzador de docker-twitch (regla: toda imagen DinD de escritorio los lleva). |
| `pepesan/mi-ubuntu-resolute-kasm-java-ciberseguridad-dind:1.4` | **VALIDADA (manual, 25-oct-2026)** | Registrada mediante roles (4 CPU/8 GB, privilegiado, `/dev/null` sobre `/dev/dri/renderD128`); incluye script, icono y lanzador de docker-twitch; sesión probada a mano por el usuario: "funciona bien". Sin evidencia por ítem. |
| `pepesan/mi-ubuntu-resolute-dind:1.3` | **PUBLICADA; PENDIENTE clasificar** | Añade script, icono y lanzador de docker-twitch. Confirmar si debe publicarse como workspace de usuario o si es una imagen base/técnica. La 1.2 no los llevaba. |

Las imágenes Noble/Kasm 1.16 quedan fuera de esta campaña de compatibilidad
1.20. Para no llenar el disco: probar una imagen, guardar evidencia y ejecutar
la limpieza mediante `kasm_workspace state=absent` antes de descargar la
siguiente. El disco del nodo ya no limita (150 GiB), pero se mantiene la
limpieza entre pruebas para no mezclar estado.

Checkpoint de nodo (25-oct-2026): la VM `kasmlxc` se borró y se recreó con el
script de la skill `lxc-vm-manager` (`--vm --cpu 6 --ram 16GiB --disk 150GiB`,
pool `poolmedia`). Ubuntu 26.04 limpio, 6 CPU, 16 GiB de RAM y **143 GB libres**
al crearla. La IP cambia en cada recreación; usuarios `alumno` (sudo sin
contraseña) y `root` con la clave SSH del operador. Kasm se reinstaló con
`./03_install_no_tls.sh inventory-lxc` (`site-kasm.yml`): 133 GB libres después.

### Orden recomendado al retomar

1. ~~Terminar Go DinD 1.3~~ — hecho (validada manualmente).
2. Limpiarla con los roles y confirmar espacio libre.
3. ~~Probar Go estándar 1.3~~ — hecho (validada manualmente).
4. ~~Probar Python estándar 1.2 y Python DinD 1.4~~ — hechas (validadas manualmente).
5. Disco ya ampliado: reinstalar Kasm con el rol `kasm` en la VM nueva (cubre el E2E de `docker`/`kasm`) y probar las dos imágenes Java.
6. En un nodo limpio, ejecutar `25`, `23`, `24`, reinicio (`30`) y finalmente
   `21`; después realizar el E2E completo de `20` y `22`.


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
