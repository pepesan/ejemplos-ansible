# examples/

Playbooks y scripts ejecutables que componen los roles de este directorio,
para que no tengas que reconstruir desde cero el orden de los roles ni los
nombres de las variables.

Esta página es la guía práctica: **instalar Kasm, crear workspaces,
mantener una sesión caliente, ajustar sesiones, borrar, desinstalar**, cada
paso con comandos para copiar y pegar. La referencia de cada variable está
en el README de cada rol (enlazados al final).

- [1. Antes de empezar](#1-antes-de-empezar)
- [2. Inicio rápido](#2-inicio-rápido)
- [3. Qué hay en este directorio](#3-qué-hay-en-este-directorio)
- [4. Instalar Kasm](#4-instalar-kasm-site-kasmyml)
- [5. Credenciales y ficheros que se generan](#5-credenciales-y-ficheros-que-se-generan)
- [6. Workspaces](#6-workspaces-kasm-workspaceyml)
- [7. Sesión caliente para un usuario (autostart)](#7-sesión-caliente-para-un-usuario-autostart)
- [8. Política de sesión y endurecimiento](#8-política-de-sesión-y-endurecimiento-kasm_group)
- [9. Borrar workspaces](#9-borrar-workspaces)
- [10. Desinstalar Kasm](#10-desinstalar-kasm-kasm-uninstallyml)
- [11. Comprobar el resultado (solo lectura)](#11-comprobar-el-resultado-solo-lectura)
- [12. Resolución de problemas](#12-resolución-de-problemas)
- [13. Referencia por rol](#13-referencia-por-rol)

## 1. Antes de empezar

**Nodo de control** (tu máquina): Ansible con `ansible-playbook` y acceso
SSH como `root` al servidor destino (Ubuntu 22.04+/24.04+).

**Dependencias de Galaxy** (Docker, swap, certbot — fijadas en
`../requirements.yml`). Instálalas una vez:

```bash
cd roles/examples
ansible-galaxy role install -r ../requirements.yml
ansible-galaxy collection install -r ../requirements.yml
```

El `ansible.cfg` de este directorio configura `roles_path` para encontrar
los roles hermanos y las dependencias de Galaxy automáticamente — no hace
falta exportar `ANSIBLE_ROLES_PATH` a mano si lanzas desde aquí.

**Inventario.** Un host por servidor Kasm. `node_name` decide el nombre
DNS: el servidor queda accesible en `<node_name>.<kasm_base_domain>`.

```ini
[ubuntu]
203.0.113.10 node_name=kasmdemo

[ubuntu:vars]
ansible_user=root
ansible_become=false
```

Con `kasm_base_domain=kasm.example.com`, ese host queda en
`https://kasmdemo.kasm.example.com`. El fichero `inventory` de este
directorio es un marcador (`X.X.X.X`); guarda los inventarios reales en
ficheros `inventory-*`, que están ignorados por git a propósito (una IP
real es un secreto).

**DNS.** Para TLS real (Let's Encrypt), `<node_name>.<kasm_base_domain>`
debe resolver ya al servidor y el puerto 80 debe estar libre para el reto
HTTP-01.

## 2. Inicio rápido

```bash
cd roles/examples
INV=inventory-mi-servidor

# 1. Instalar Kasm (Docker, usuario "alumno", Kasm con TLS, política de grupo)
ansible-playbook -i $INV site-kasm.yml \
  -e kasm_base_domain=kasm.example.com \
  -e letsencrypt_email=tu@example.com \
  2>&1 | tee /tmp/kasm-install.log

# 2. Registrar un workspace
ansible-playbook -i $INV kasm-workspace.yml \
  -e kasm_workspace_state=present \
  -e kasm_docker_image_name=pepesan/mi-ubuntu-resolute-kasm-terminal-dind:1.1 \
  -e kasm_workspace_image=pepesan/mi-ubuntu-resolute-kasm-terminal-dind:1.1 \
  -e '{"kasm_workspace_name": "Terminal DinD"}' \
  -e kasm_workspace_privileged=true \
  2>&1 | tee /tmp/kasm-workspace.log

# 3. Las credenciales están en ./datos-acceso-<fecha>.csv
```

> Envía siempre la salida de los playbooks a un log con `tee` (como arriba)
> para poder hacer `tail -f` desde otra terminal. Una primera instalación
> tarda varios minutos; lo lento es el propio instalador de Kasm.

## 3. Qué hay en este directorio

### Playbooks

| Fichero | Qué hace |
|---|---|
| `site-kasm.yml` | Instalación completa: `docker` → `student` → `kasm_credentials` → `kasm` → `kasm_group` |
| `kasm-workspace.yml` | Crea o borra **un** workspace (`kasm_docker_image` → `kasm_workspace`, al revés para borrar) |
| `kasm-uninstall.yml` | Elimina una instalación de Kasm existente (`kasm_uninstall`) para que el siguiente `site-kasm.yml` sea una instalación realmente nueva |

### Scripts (envoltorios finos de los playbooks)

| Script | Qué muestra |
|---|---|
| `01_install_default_domain.sh` | Instalación completa con un dominio placeholder (`kasm_base_domain` no tiene valor por defecto sensato fuera de este proyecto a propósito — pasa siempre uno real) |
| `02_install_custom_domain.sh` | Instalación completa con tu propio dominio y email de Let's Encrypt |
| `03_install_no_tls.sh` | Instalación local/sin DNS, `kasm_letsencrypt_enabled=false` |
| `04_workspace_create.sh` | Crea un workspace con la imagen de ejemplo por defecto |
| `05_workspace_create_custom_image.sh` | Crea un workspace con tu propia imagen, cores/memoria explícitos y un nombre con espacios (forma JSON de `-e`) |
| `06_workspace_delete.sh` | Borra un workspace (y su imagen Docker), opcionalmente conservando los perfiles persistentes |
| `07_kasm_uninstall.sh` | Elimina una instalación de Kasm existente |

Todos los scripts toman la ruta del inventario como primer argumento
opcional, con valor por defecto `./inventory` si se omite:

```bash
./02_install_custom_domain.sh                                   # ./inventory
./02_install_custom_domain.sh inventory-mi-servidor kasm.example.com tu@example.com
./05_workspace_create_custom_image.sh inventory-mi-servidor user/imagen:1.0 "Mi workspace"
./06_workspace_delete.sh inventory-mi-servidor user/imagen:1.0 keep_profiles
./07_kasm_uninstall.sh inventory-mi-servidor
```

Los scripts no hacen `tee` a un log ni exponen todas las variables. Para
cualquier otra cosa, llama directamente a los playbooks, como en el resto
de esta página.

## 4. Instalar Kasm (`site-kasm.yml`)

### Qué hace, por orden

| Rol | Qué hace |
|---|---|
| `docker` | Docker CE + plugin Compose, módulos `overlay`/`br_netfilter`, sysctl de `ip_forward` y bridge, `python3-docker` |
| `student` | Usuario Linux `alumno` (bash, grupos `docker`,`sudo`) con contraseña aleatoria de 20 caracteres |
| `kasm_credentials` | Genera/lee las contraseñas de admin y usuario de Kasm y actualiza el CSV de acceso (solo corre en tu máquina) |
| `kasm` | 4 GB de swap, certbot + certificado, arreglo de AppArmor userns, `/opt/kasm/compose.yaml`, contenedor Kasm, instalador de Kasm, poda de imágenes desactivada, snippet que bloquea impresión, HTTPS con Let's Encrypt |
| `kasm_group` | Política de sesión por grupo (keepalive y endurecimiento) para el grupo "All Users" |

Es **idempotente**: una segunda ejecución no reinstala Kasm (hay un
marcador `/opt/kasm_install_complete` bajo `/opt/kasm/data`).

### Ejemplos

Dominio real con Let's Encrypt (el caso habitual):

```bash
ansible-playbook -i inventory-mi-servidor site-kasm.yml \
  -e kasm_base_domain=kasm.example.com \
  -e letsencrypt_email=tu@example.com \
  2>&1 | tee /tmp/kasm-install.log
```

Lo mismo con el script envoltorio:

```bash
./02_install_custom_domain.sh inventory-mi-servidor kasm.example.com tu@example.com
```

Local / sin DNS (Kasm conserva su certificado autofirmado):

```bash
ansible-playbook -i inventory-local site-kasm.yml \
  -e kasm_base_domain=example.com \
  -e kasm_letsencrypt_enabled=false
# o: ./03_install_no_tls.sh inventory-local
```

Más swap, y un prefijo de cohorte para el CSV de acceso (cursos en paralelo
no mezclan filas):

```bash
ansible-playbook -i inventory-mi-servidor site-kasm.yml \
  -e kasm_base_domain=kasm.example.com \
  -e letsencrypt_email=tu@example.com \
  -e kasm_swap_file_size_mb=8192 \
  -e kasm_proyecto_formativo=curso-docker
```

Elegir las contraseñas en vez de generarlas:

```bash
ansible-playbook -i inventory-mi-servidor site-kasm.yml \
  -e kasm_base_domain=kasm.example.com \
  -e kasm_admin_password='Cambiame-Admin-1' \
  -e kasm_user_password='Cambiame-User-1'
```

Instalar varios servidores de una vez: una línea por host en el
inventario, cada uno con su `node_name`. Cada uno tiene su fila en el CSV.

### Variables más usadas

| Variable | Por defecto | Rol | Significado |
|---|---|---|---|
| `kasm_base_domain` | `example.com` | `kasm` | Dominio base; el host es `<node_name>.<kasm_base_domain>` |
| `letsencrypt_email` | `admin@<kasm_base_domain>` | `kasm` | Email para certbot |
| `kasm_letsencrypt_enabled` | `true` | `kasm` | `false` conserva el certificado autofirmado |
| `kasm_version` / `kasm_image_tag` | `1.19.0` / `1.19.0-ls148` | `kasm` | Versión de Kasm y tag de la imagen linuxserver |
| `kasm_swap_file_size_mb` | `4096` | `kasm` | Tamaño del swap |
| `kasm_proyecto_formativo` | `""` | `kasm_credentials` | Prefijo del CSV de acceso |
| `kasm_admin_password` / `kasm_user_password` | aleatoria | `kasm_credentials` | Sustituyen a las contraseñas generadas |
| `kasm_group_keepalive_seconds` | `3600` | `kasm_group` | Segundos antes de que una sesión inactiva actúe |

## 5. Credenciales y ficheros que se generan

Todos se crean en **tu máquina**, en este directorio, y están ignorados por
git. No los commitees nunca.

| Fichero | Qué contiene |
|---|---|
| `.credenciales/<ip>-alumno.pass` | Contraseña del usuario Linux `alumno` |
| `.credenciales/<ip>-kasm-admin.pass` | Contraseña de `admin@kasm.local` |
| `.credenciales/<ip>-kasm-user.pass` | Contraseña de `user@kasm.local` |
| `datos-acceso-<fecha>.csv` | Una fila por servidor: IP, URL de Kasm y las tres credenciales. Con `kasm_proyecto_formativo=x`: `datos-acceso-x-<fecha>.csv` |
| `kasm-api-key-<ip>.json` | Copia de la API key persistente (se crea con el primer workspace) |

Las contraseñas se generan **una vez** y se releen en ejecuciones
posteriores. Para obtener contraseñas nuevas, borra `.credenciales/` antes
de lanzar `site-kasm.yml`. La desinstalación no la toca.

La API key en sí vive en el servidor, en `/opt/kasm/.kasm_api_key.json`
(modo 600), y se crea la primera vez que se registra un workspace.

## 6. Workspaces (`kasm-workspace.yml`)

Un workspace es una imagen Docker registrada en Kasm. `kasm-workspace.yml`
descarga la imagen en el Docker anidado de Kasm (el "DinD") y la registra.
Kasm debe estar ya instalado.

La imagen se pasa siempre **dos veces**: `kasm_docker_image_name` (qué
descargar) y `kasm_workspace_image` (qué registrar). Es la misma cadena.

Los nombres con espacios deben ir en la forma JSON de `-e` — un
`-e var=a b` normal se trunca en el primer espacio.

### Mínimo

```bash
ansible-playbook -i inventory-mi-servidor kasm-workspace.yml \
  -e kasm_workspace_state=present \
  -e kasm_docker_image_name=pepesan/mi-ubuntu-resolute-kasm:1.0 \
  -e kasm_workspace_image=pepesan/mi-ubuntu-resolute-kasm:1.0 \
  -e '{"kasm_workspace_name": "Ubuntu Resolute"}'
# o: ./04_workspace_create.sh inventory-mi-servidor
```

### Las imágenes DinD (Docker dentro de la sesión) necesitan `privileged`

Las imágenes que ejecutan su propio demonio Docker no pueden arrancarlo sin
privilegios. Sin `kasm_workspace_privileged=true` la sesión arranca pero
Docker dentro de ella no funciona.

```bash
# Java / Spring Boot dev + DinD (imagen de 18 GB: la descarga tarda minutos)
ansible-playbook -i inventory-mi-servidor kasm-workspace.yml \
  -e kasm_workspace_state=present \
  -e kasm_docker_image_name=pepesan/mi-ubuntu-resolute-kasm-java-spring-boot-web-dev-dind:1.6 \
  -e kasm_workspace_image=pepesan/mi-ubuntu-resolute-kasm-java-spring-boot-web-dev-dind:1.6 \
  -e '{"kasm_workspace_name": "Java Spring Boot Dev DinD"}' \
  -e kasm_workspace_privileged=true \
  -e kasm_workspace_cores=4 \
  -e kasm_workspace_memory_gb=8 \
  2>&1 | tee /tmp/kasm-workspace-java.log
```

```bash
# Terminal + DinD
ansible-playbook -i inventory-mi-servidor kasm-workspace.yml \
  -e kasm_workspace_state=present \
  -e kasm_docker_image_name=pepesan/mi-ubuntu-resolute-kasm-terminal-dind:1.1 \
  -e kasm_workspace_image=pepesan/mi-ubuntu-resolute-kasm-terminal-dind:1.1 \
  -e '{"kasm_workspace_name": "Terminal DinD"}' \
  -e kasm_workspace_privileged=true \
  -e kasm_workspace_cores=2 \
  -e kasm_workspace_memory_gb=4 \
  2>&1 | tee /tmp/kasm-workspace-terminal.log
```

Lanza la imagen grande solo si el servidor tiene la RAM; los dos ejemplos
reservan 8 GB + 4 GB cuando ambos tienen una sesión abierta.

### Envoltorio para tu propia imagen

```bash
./05_workspace_create_custom_image.sh inventory-mi-servidor \
  pepesan/mi-ubuntu-resolute-kasm-python-dind:1.1 "Python DinD"
```

### Variables del workspace

| Variable | Por defecto | Significado |
|---|---|---|
| `kasm_workspace_name` | — (obligatoria) | Nombre que ven los usuarios |
| `kasm_workspace_desc` | = nombre | Descripción |
| `kasm_workspace_cores` | `4` | Cores de CPU por sesión |
| `kasm_workspace_memory_gb` | `8` | RAM por sesión |
| `kasm_workspace_privileged` | `false` | Necesario para imágenes DinD |
| `kasm_workspace_gpu_count` | `0` | GPUs |
| `kasm_workspace_session_time_limit` | `""` | Límite duro en segundos |
| `kasm_workspace_category` | `""` | Categoría en el catálogo |
| `kasm_workspace_enabled` | `true` | Visible para los usuarios |
| `kasm_workspace_profile_path` | `""` | Home persistente. Debe contener `{username}` o `{user_id}` |

Directorio home persistente (los ficheros del usuario sobreviven al borrado
de la sesión):

```bash
ansible-playbook -i inventory-mi-servidor kasm-workspace.yml \
  -e kasm_workspace_state=present \
  -e kasm_docker_image_name=user/imagen:1.0 \
  -e kasm_workspace_image=user/imagen:1.0 \
  -e '{"kasm_workspace_name": "Con persistencia"}' \
  -e 'kasm_workspace_profile_path=/opt/kasm_profiles/{user_id}/{image_id}'
```

Repetir con la misma imagen es seguro: se reutiliza el workspace existente.

## 7. Sesión caliente para un usuario (autostart)

Por defecto, el primer login de un usuario arranca la sesión en frío, lo
que con una imagen grande supone una espera (502 del proxy durante unos
segundos, escritorio lento en pintarse).
`kasm_workspace_autostart_enabled=true` lanza **una sesión del workspace
para un usuario de Kasm** justo después de crearlo, de modo que el primer
login la encuentre ya corriendo.

```bash
ansible-playbook -i inventory-mi-servidor kasm-workspace.yml \
  -e kasm_workspace_state=present \
  -e kasm_docker_image_name=pepesan/mi-ubuntu-resolute-kasm-terminal-dind:1.1 \
  -e kasm_workspace_image=pepesan/mi-ubuntu-resolute-kasm-terminal-dind:1.1 \
  -e '{"kasm_workspace_name": "Terminal DinD"}' \
  -e kasm_workspace_privileged=true \
  -e kasm_workspace_cores=2 \
  -e kasm_workspace_memory_gb=4 \
  -e kasm_workspace_autostart_enabled=true \
  2>&1 | tee /tmp/kasm-workspace-autostart.log
```

| Variable | Por defecto | Significado |
|---|---|---|
| `kasm_workspace_autostart_enabled` | `false` | Activarlo |
| `kasm_workspace_autostart_user` | `user@kasm.local` | De quién es la sesión |
| `kasm_workspace_autostart_timeout_seconds` | `600` | Cuánto esperar a `running` |

Cómo se comporta:

- **Idempotente.** Si ese usuario ya tiene una sesión de ese workspace, no
  se lanza otra (`changed=0` en una segunda ejecución).
- **Nunca hace fallar el workspace.** Un usuario inexistente o una sesión
  que no llega a `running` a tiempo es un `WARNING`; el workspace se crea
  igualmente.
- **Cuesta recursos.** Una sesión en marcha reserva de forma permanente los
  `cores` y `memory_gb` del workspace. En un servidor de 11 GB, una sesión
  Java (8 GB) deja casi nada; no hagas autostart de dos workspaces grandes.
- **Debe mantenerse viva.** Con la política de grupo por defecto
  (`keepalive_expiration=3600`, acción `pause`), una sesión a la que nadie
  está conectado se pausa a la hora. Mira la siguiente sección para
  ampliarlo.
- **No sobrevive a un reinicio de Kasm o del servidor.** Vuelve a lanzar el
  mismo comando para relanzarla.

Alternativa que el rol también soporta pero no activa (exige cambiar el
hostname de la zona en el panel de admin): **Session Staging**
(`kasm_workspace_group_staging_enabled=true`), que precalienta sesiones
anónimas para cualquier usuario.

## 8. Política de sesión y endurecimiento (`kasm_group`)

`site-kasm.yml` ya ejecuta `kasm_group` con valores seguros para el grupo
"All Users". Volver a lanzar `site-kasm.yml` con otros valores los
actualiza (es idempotente y solo toca lo que difiere):

| Variable | Por defecto | Significado |
|---|---|---|
| `kasm_group_keepalive_seconds` | `3600` | Segundos de inactividad antes de la acción de keepalive. Kasm ignora `0` |
| `kasm_group_keepalive_action` | `pause` | `pause` o `delete` |
| `kasm_group_allow_clipboard_down` / `_up` / `_seamless` | `false` | Portapapeles desde / hacia la sesión |
| `kasm_group_allow_downloads` / `_uploads` | `false` | Transferencia de ficheros |
| `kasm_group_allow_printing` | `false` | Impresión |

Mantener las sesiones un día y permitir el portapapeles (para una clase):

```bash
ansible-playbook -i inventory-mi-servidor site-kasm.yml \
  -e kasm_base_domain=kasm.example.com \
  -e kasm_group_keepalive_seconds=86400 \
  -e kasm_group_allow_clipboard_down=true \
  -e kasm_group_allow_clipboard_up=true
```

Basta con pasar el mismo `kasm_base_domain` que en la instalación
original; no se reinstala nada.

## 9. Borrar workspaces

Cierra las sesiones activas de esa imagen, quita el workspace del
catálogo, borra sus datos de perfil persistentes (irreversible, es el valor
por defecto) y elimina la imagen Docker del DinD.

```bash
ansible-playbook -i inventory-mi-servidor kasm-workspace.yml \
  -e kasm_workspace_state=absent \
  -e kasm_docker_image_name=pepesan/mi-ubuntu-resolute-kasm-terminal-dind:1.1 \
  -e kasm_workspace_image=pepesan/mi-ubuntu-resolute-kasm-terminal-dind:1.1
```

Conservar los directorios home persistentes de los usuarios:

```bash
ansible-playbook -i inventory-mi-servidor kasm-workspace.yml \
  -e kasm_workspace_state=absent \
  -e kasm_docker_image_name=user/imagen:1.0 \
  -e kasm_workspace_image=user/imagen:1.0 \
  -e kasm_workspace_delete_persistent_data=false
# o: ./06_workspace_delete.sh inventory-mi-servidor user/imagen:1.0 keep_profiles
```

El playbook borra un workspace por ejecución; lánzalo una vez por imagen
para limpiar varios. Un borrado correcto muestra `removed from Kasm's
catalog` en el log.

## 10. Desinstalar Kasm (`kasm-uninstall.yml`)

Elimina el contenedor Kasm (y sus contenedores, redes y volúmenes
anidados), los datos persistidos (base de datos, certificados propios de
Kasm, marcador de instalación, perfiles de sesión) y `/opt/kasm`. El
siguiente `site-kasm.yml` es una instalación nueva de verdad. **No** toca
Docker, el fichero de swap, el usuario `alumno` ni tu `.credenciales/`.

```bash
ansible-playbook -i inventory-mi-servidor kasm-uninstall.yml \
  2>&1 | tee /tmp/kasm-uninstall.log
# o: ./07_kasm_uninstall.sh inventory-mi-servidor
```

Por defecto el certificado de Let's Encrypt del host se **conserva**, así
que la reinstalación lo reutiliza (Let's Encrypt limita las emisiones por
dominio). Para forzar también un certificado nuevo:

```bash
ansible-playbook -i inventory-mi-servidor kasm-uninstall.yml \
  -e kasm_uninstall_remove_letsencrypt_certs=true \
  -e kasm_base_domain=kasm.example.com
```

(`node_name` viene del inventario.)

### Reinstalar desde cero

```bash
ansible-playbook -i inventory-mi-servidor kasm-uninstall.yml
rm -rf .credenciales         # opcional: contraseñas totalmente nuevas
ansible-playbook -i inventory-mi-servidor site-kasm.yml \
  -e kasm_base_domain=kasm.example.com \
  -e letsencrypt_email=tu@example.com
```

## 11. Comprobar el resultado (solo lectura)

Ejecútalos en el servidor; ninguno cambia nada.

```bash
# Contenedores propios de Kasm (api, manager, proxy, agent, db, guac, rdp)
docker exec kasm docker ps --format '{{.Names}}  {{.Status}}'

# Imágenes descargadas en el DinD
docker exec kasm docker images --format '{{.Repository}}:{{.Tag}}  {{.Size}}'

# Workspaces registrados
docker exec kasm docker exec kasm_db psql -U kasmapp -d kasm \
  -c "SELECT name, friendly_name FROM images;"

# Sesiones vivas ahora mismo, y de quién
docker exec kasm docker exec kasm_db psql -U kasmapp -d kasm \
  -c "SELECT u.username, k.operational_status, k.keepalive_date
        FROM kasms k JOIN users u USING (user_id);"

# Política de grupo aplicada
docker exec kasm docker exec kasm_db psql -U kasmapp -d kasm \
  -c "SELECT gs.name, gs.value FROM group_settings gs
        JOIN groups g USING (group_id) WHERE g.name='All Users' ORDER BY 1;"

# Log del instalador, en vivo
tail -f /opt/kasm/data/opt/kasm_deploy.log
```

## 12. Resolución de problemas

| Síntoma | Causa y solución |
|---|---|
| El primer login se queda en "Creating a secure connection…" y el proxy devuelve 502 | El contenedor de la sesión aún está arrancando (arranque en frío de una imagen grande). Se resuelve solo en segundos o pocos minutos. Usa [autostart](#7-sesión-caliente-para-un-usuario-autostart) para evitarlo. |
| El escritorio abre con el fondo negro pero el menú funciona | El escritorio aún se está pintando en el arranque en frío. Aparece poco después. |
| Docker no funciona dentro de la sesión | El workspace se creó sin `kasm_workspace_privileged=true`. Bórralo y créalo de nuevo con el flag. |
| `-e kasm_workspace_name=Mi workspace` registra el nombre "Mi" | Un `-e` normal se trunca en el primer espacio. Usa `-e '{"kasm_workspace_name": "Mi workspace"}'`. |
| `syntax error at or near "\"` en `kasm_group` | Una versión antigua del rol escapaba `$$` como `\$\$`. Actualiza el repositorio; la tarea ya usa `$$`. |
| `geerlingguy.certbot` falla con un condicional `list` vs `boolean` | Versión anterior a `5.4.1`. `../requirements.yml` fija `5.4.1`; reinstala los roles de Galaxy. |
| La sesión se pausa a la hora | Política de grupo. Sube `kasm_group_keepalive_seconds` (sección 8). |
| `ps -u alumno` en el host muestra procesos Python de Kasm | Los contenedores de servicio de Kasm corren con UID 1001, el mismo número que el usuario `alumno`. No son procesos de `alumno`. No hagas `pkill -u alumno`: matarías la API de Kasm. |
| Imagen solo-terminal: letra muy pequeña y sin barra de menú | La imagen arranca `xfce4-terminal --hide-menubar --zoom=-1`. Pulsa `Ctrl` + `+`, o clic derecho → Preferences. Para cambiar el zoom inicial, define `APP_ARGS` en el Docker Run Config Override del workspace. |

## 13. Referencia por rol

| Rol | README |
|---|---|
| `docker` | [`../docker/README.md`](../docker/README.md) |
| `student` / `linux_user` | [`../student/README.md`](../student/README.md), [`../linux_user/README.md`](../linux_user/README.md) |
| `kasm_credentials` | [`../kasm_credentials/README.md`](../kasm_credentials/README.md) |
| `kasm` | [`../kasm/README.md`](../kasm/README.md) |
| `kasm_group` | [`../kasm_group/README.md`](../kasm_group/README.md) |
| `kasm_workspace` | [`../kasm_workspace/README.md`](../kasm_workspace/README.md) |
| `kasm_docker_image` | [`../kasm_docker_image/README.md`](../kasm_docker_image/README.md) |
| `kasm_user` | [`../kasm_user/README.md`](../kasm_user/README.md) |
| `kasm_uninstall` | [`../kasm_uninstall/README.md`](../kasm_uninstall/README.md) |

Notas de pruebas extremo a extremo contra un servidor real:
[`TEST.md`](TEST.md) / [`TEST.es.md`](TEST.es.md). Versión en inglés de
esta página: [`README.md`](README.md).
