# Despliegue de máquinas remotas con Ansible y usando Vault

## Introducción

Este proyecto tiene como objetivo desplegar máquinas remotas utilizando Ansible y gestionar las credenciales de manera segura con Ansible Vault. Ansible Vault permite cifrar archivos sensibles, como contraseñas y claves SSH, para proteger la información confidencial durante el despliegue.

## Requisitos previos

- Tener Ansible instalado en tu máquina local.
- Tener acceso a las máquinas remotas que deseas gestionar.
- Tener Ansible Vault instalado (viene incluido con Ansible).
- Tener configurado SSH para acceder a las máquinas remotas.
- Tener un archivo de inventario de Ansible que liste las máquinas remotas.
- Tener un archivo de configuración de Ansible (`ansible.cfg`) adecuado.

## Configuración de Ansible Vault

Las credenciales están almacenadas en `group_vars/all/vault.yml`, que ya se encuentra cifrado con Ansible Vault.

Para crear o editar el fichero de variables cifradas:

```bash
# Editar en texto plano antes de cifrar
nano group_vars/all/vault.yml
```

Ejemplo de contenido:

```yaml
alumno_password_plain: tu_contrasegna_aqui
```

Para cifrarlo:

```bash
ansible-vault encrypt group_vars/all/vault.yml
```

Para ejecutar cualquier playbook usando las variables del vault:

```bash
ansible-playbook <playbook>.yaml --ask-vault-pass
```

## Playbooks disponibles

### Infraestructura base

| Playbook | Descripción |
|----------|-------------|
| `00_ping.yaml` | Comprueba conectividad con los hosts |
| `01_docker_install.yaml` | Instala Docker |
| `02_adduser_alumno.yaml` | Crea el usuario `alumno` con permisos de `sudo` y `docker` |
| `03_sdkman_install.yaml` | Instala SDKMAN y el JDK 21 |
| `04_01_xrdp_install_gnome.yaml` | Instala XRDP con escritorio GNOME |
| `04_02_xrdp_install_xfce.yaml` | Instala XRDP con escritorio XFCE |
| `05_intellij_install.yaml` | Instala IntelliJ IDEA |
| `06_chrome_chromedriver_install.yaml` | Instala Google Chrome y ChromeDriver |
| `07_system_update.yaml` | Actualiza el sistema operativo |
| `08_download_git.yaml` | Instala Git y clona repositorios de ejemplo |
| `30_reboot.yaml` | Reinicia la máquina remota |

### VSCode y extensiones

| Playbook | Descripción |
|----------|-------------|
| `09_install_vscode_php.yaml` | Instala VSCode con extensiones PHP |
| `09_install_vscode_python.yaml` | Instala VSCode con extensiones Python |
| `09_install_vscode_docker_k8s.yaml` | Instala VSCode con extensiones Docker y Kubernetes |
| `09_install_vscode_terraform_localstack.yaml` | Instala VSCode con extensiones Terraform y AWS |

### Drupal

| Playbook | Descripción |
|----------|-------------|
| `10_install_drupal.yaml` | Despliega el entorno Drupal con Docker |
| `11_repair_docker.yaml` | Repara la instalación de Docker si hay problemas |
| `12_copy_drupal_examples.yaml` | Copia los ficheros de ejemplos de Drupal al servidor |
| `13_clean_drupal_environment.yaml` | Limpia y elimina el entorno Drupal |

### Herramientas adicionales

| Playbook | Descripción |
|----------|-------------|
| `14_deploy_docker_compose_jupiter_notebook.yaml` | Despliega Jupyter Notebook con Docker Compose |
| `15_deploy_mongodb_tools.yaml` | Instala MongoDB y MongoDB Compass |
| `16_deploy_terraform_localstack.yaml` | Instala Terraform, LocalStack y AWS CLI |
| `17_deploy_mysql_client.yaml` | Instala el cliente MySQL |

### Limpieza de contenedores

| Playbook | Descripción |
|----------|-------------|
| `18_delete_docker_container.yaml` | Elimina un contenedor Docker genérico |
| `19_delete_jupyter_docker_container.yaml` | Elimina el contenedor de Jupyter Notebook |

## Despliegue de Kasm

El playbook `20_deploy_kasm.yaml` instala y configura [Kasm Workspaces](https://www.kasmweb.com/) en la máquina remota. Kasm permite acceder a entornos de escritorio completos desde el navegador.

### Imágenes disponibles

Las imágenes personalizadas se construyen desde el repositorio: https://github.com/pepesan/kasm-workspaces-images.git

Ubuntu 26.04 (Resolute) es la base por defecto. Kasm todavía no publica una
imagen base oficial para esa versión de Ubuntu, así que estas imágenes se
construyen sobre un fork propio: https://github.com/pepesan/workspaces-core-images.
Las variantes sobre Ubuntu 24.04 (Noble), con base oficial de Kasm, siguen
disponibles como alternativa.

| Imagen | Descripción |
|--------|-------------|
| `pepesan/mi-ubuntu-resolute-kasm-python-dind:1.0` *(por defecto)* | Ubuntu 26.04 con PyCharm, MariaDB, DinD |
| `pepesan/mi-ubuntu-resolute-kasm:1.0` | Ubuntu 26.04 con IntelliJ, ZAP y Firefox |
| `pepesan/mi-ubuntu-resolute-kasm-go:1.0` | Ubuntu 26.04 con entorno de desarrollo Go |
| `pepesan/mi-ubuntu-noble-kasm:1.0` | Ubuntu 24.04 con IntelliJ, ZAP y Firefox |
| `pepesan/mi-ubuntu-noble-kasm-go:1.0` | Ubuntu 24.04 con entorno de desarrollo Go |
| `pepesan/mi-ubuntu-noble-kasm-python:1.0` | Ubuntu 24.04 con entorno de desarrollo Python |

### Origen de las imágenes

Cada imagen se construye desde el repositorio [`kasm-workspaces-images`](https://github.com/pepesan/kasm-workspaces-images.git).
La base es [`pepesan/core-ubuntu-resolute`](https://hub.docker.com/r/pepesan/core-ubuntu-resolute) (fork propio de
[`workspaces-core-images`](https://github.com/pepesan/workspaces-core-images) porque Kasm no tiene base oficial
para Ubuntu 26.04).

| Imagen Resolute | Dockerfile | Script de build |
|---|---|---|
| `mi-ubuntu-resolute-kasm-python-dind` | `dockerfile-kasm-ubuntu-resolute-desktop-python-dind` | `scripts/python-resolute-dind/build.sh` |
| `mi-ubuntu-resolute-kasm` | `dockerfile-kasm-ubuntu-resolute-desktop-dind` | `scripts/java-resolute/build.sh` |
| `mi-ubuntu-resolute-kasm-go` | `dockerfile-kasm-ubuntu-resolute-desktop-go` | `scripts/go-resolute/build.sh` |
| `mi-ubuntu-resolute-kasm-python` | `dockerfile-kasm-ubuntu-resolute-desktop-python` | `scripts/python-resolute/build.sh` |

Para construir localmente:

```bash
cd /home/pepesan/Dropbox/proyectos/kasm-workspaces-images
./scripts/python-resolute-dind/build.sh
./scripts/python-resolute-dind/push.sh   # sube a Docker Hub
```

### Playbooks de Kasm

| Playbook | Descripción |
|----------|-------------|
| `20_deploy_kasm.yaml` | Despliega Kasm completo (instalación, workspace, bastionado) — flujo original, todo en uno |
| `21_undeploy_kasm.yaml` | Elimina Kasm completamente para empezar desde cero (no toca `/etc/letsencrypt` ni `.credenciales/`) |
| `22_configure_letsencrypt.yaml` | Configura certificado Let's Encrypt para HTTPS (requiere DNS configurado) |
| `23_crear_workspace.yaml` | Registra un workspace nuevo sin reinstalar Kasm (idempotente, parametrizable: cores, memoria, GPU, persistencia, categoría, staging...) |
| `24_limpiar_workspace.yaml` | Borra un workspace (o todos): cierra primero sus sesiones abiertas, borra registro, imagen Docker, layers huérfanos, y por defecto también los perfiles persistentes (`-e kasm_delete_persistent_data=false` para conservarlos) |
| `25_instalar_solo_kask_usuarios.yaml` | Instala Kasm + usuario `alumno` + HTTPS real de Let's Encrypt, **sin** crear ningún workspace (fusiona `20`+`22` menos la parte de workspace); genera contraseñas aleatorias y las vuelca en un CSV |

`23`/`24`/`25` son un flujo alternativo a `20_deploy_kasm.yaml` pensado para gestionar varios
workspaces en el mismo servidor sin tener que reinstalar Kasm cada vez. Ver ejemplos completos de
uso (todos los parámetros) en `launch_tasks_with_vault.sh`.

### API key de Kasm: persistente, una por servidor

`23_crear_workspace.yaml` necesita una API key administrativa de Kasm para hablar con
`/api/public/create_image` (y, de paso, con `/api/public/get_images`, `request_kasm`,
`get_kasm_status` y `destroy_kasm`, útiles para validar que un workspace levanta sesión de
verdad). En vez de crear y destruir una API key distinta en cada ejecución (como hacían las
primeras versiones de este flujo), ahora se genera **una sola vez por servidor** y se reutiliza:

- Se guarda en el propio servidor, fuera de cualquier contenedor, en `/opt/kasm/.kasm_api_key.json`
  (solo legible por root). La base de datos de Kasm únicamente guarda el *hash* del secreto, así
  que ese fichero es la única copia del secreto en claro.
- Al generarla se le conceden dos permisos: `200` (grupo "Administrators" — crear/listar
  imágenes) y `100` (grupo "All Users" — pedir, consultar y destruir sesiones). Con los dos, la
  misma key sirve tanto para crear workspaces como para lanzar una sesión de prueba después.
- Cada ejecución de `23_crear_workspace.yaml` se trae una copia a tu máquina (al controlador), en
  `kasm-api-key-<ip-del-host>.json`, en la raíz de este proyecto — **una API key por servidor**,
  nunca compartida entre hosts distintos. Ese fichero está en `.gitignore` (patrón
  `kasm-api-key-*.json`): nunca se sube al repositorio.
- Generarla está protegido con un lock de fichero (`flock`, igual que el CSV de credenciales) para
  que dos ejecuciones casi simultáneas contra el mismo servidor no acaben creando dos API keys en
  paralelo.
- `21_undeploy_kasm.yaml` borra `/opt/kasm` entero, así que también se lleva por delante esta API
  key — es intencionado (es un "borrar todo y empezar de cero"); la siguiente vez que se cree un
  workspace en ese servidor se genera una nueva.

#### Validar que un workspace levanta sesión de verdad

Con la API key ya guardada en local (`kasm-api-key-<ip>.json`), se puede comprobar que un
workspace recién creado realmente arranca un contenedor de sesión y llega a `running`, sin tener
que entrar al navegador:

```bash
DOMAIN="https://kasmcontabo.kasm.cursosdedesarrollo.com"   # tu dominio/IP de Kasm
API_KEY=$(python3 -c "import json;print(json.load(open('kasm-api-key-IP_SERVIDOR.json'))['api_key'])")
API_SECRET=$(python3 -c "import json;print(json.load(open('kasm-api-key-IP_SERVIDOR.json'))['api_key_secret'])")

# user_id del usuario que lanzará la sesión (user@kasm.local u otro)
USER_ID=$(curl -sk -X POST "$DOMAIN/api/authenticate" -H "Content-Type: application/json" \
  -d '{"username":"user@kasm.local","password":"LA_PASSWORD_DEL_CSV"}' | python3 -c 'import sys,json;print(json.load(sys.stdin)["user_id"])')

# image_id del workspace a probar (sale en "Crear workspace" o en get_images)
IMAGE_ID=$(curl -sk -X POST "$DOMAIN/api/public/get_images" -H "Content-Type: application/json" \
  -d "{\"api_key\":\"$API_KEY\",\"api_key_secret\":\"$API_SECRET\"}" \
  | python3 -c 'import sys,json; [print(i["image_id"]) for i in json.load(sys.stdin)["images"] if "NOMBRE_DE_LA_IMAGEN" in i["name"]]')

# Pedir la sesión
KASM_ID=$(curl -sk -X POST "$DOMAIN/api/public/request_kasm" -H "Content-Type: application/json" \
  -d "{\"api_key\":\"$API_KEY\",\"api_key_secret\":\"$API_SECRET\",\"user_id\":\"$USER_ID\",\"image_id\":\"$IMAGE_ID\"}" \
  | python3 -c 'import sys,json;print(json.load(sys.stdin)["kasm_id"])')

# Consultar el estado hasta que sea "running" (dentro de kasm.operational_status)
curl -sk -X POST "$DOMAIN/api/public/get_kasm_status" -H "Content-Type: application/json" \
  -d "{\"api_key\":\"$API_KEY\",\"api_key_secret\":\"$API_SECRET\",\"user_id\":\"$USER_ID\",\"kasm_id\":\"$KASM_ID\"}" \
  | python3 -c 'import sys,json;print(json.load(sys.stdin)["kasm"]["operational_status"])'

# Limpiar la sesión de prueba
curl -sk -X POST "$DOMAIN/api/public/destroy_kasm" -H "Content-Type: application/json" \
  -d "{\"api_key\":\"$API_KEY\",\"api_key_secret\":\"$API_SECRET\",\"user_id\":\"$USER_ID\",\"kasm_id\":\"$KASM_ID\"}"
```

Validado en Contabo (2026-10-08): dos ciclos completos `21` → `25` → `23` (workspace de escritorio
`java-spring-boot-web-dev-dind:1.5`) → `23` (workspace terminal `terminal-dind:1.1`), y en ambos
ciclos las dos sesiones (escritorio y terminal) llegaron a `operational_status: running` sin
intervención manual.

### Uso

```bash
# Imagen por defecto (Ubuntu Resolute con PyCharm, MariaDB, DinD)
ansible-playbook 20_deploy_kasm.yaml --ask-vault-pass

# Imagen de desarrollo Go (Resolute)
ansible-playbook 20_deploy_kasm.yaml --ask-vault-pass -e "kasm_image=pepesan/mi-ubuntu-resolute-kasm-go:1.0"

# Imagen de IntelliJ (Resolute)
ansible-playbook 20_deploy_kasm.yaml --ask-vault-pass -e "kasm_image=pepesan/mi-ubuntu-resolute-kasm:1.0"

# Cualquier variante sobre Ubuntu Noble (24.04), sustituyendo "resolute" por "noble"
ansible-playbook 20_deploy_kasm.yaml --ask-vault-pass -e "kasm_image=pepesan/mi-ubuntu-noble-kasm-go:1.0"

# Desactivar el modo privilegiado del contenedor de sesión
ansible-playbook 20_deploy_kasm.yaml --ask-vault-pass -e "kasm_privileged=false"

# Eliminar despliegue
ansible-playbook 21_undeploy_kasm.yaml --ask-vault-pass

# Configurar Let's Encrypt (DNS debe apuntar al servidor antes de ejecutar)
ansible-playbook 22_configure_letsencrypt.yaml --ask-vault-pass
```

La instalación de Kasm tarda varios minutos. Para seguir el progreso en tiempo real, abre otra terminal y ejecuta:

```bash
ssh root@IP_SERVIDOR 'tail -f /opt/kasm/data/opt/kasm_deploy.log'
```

Una vez desplegado, acceder a `https://IP_SERVIDOR/` (o al dominio configurado) con el usuario
administrador (`admin@kasm.local`) o el usuario normal (`user@kasm.local`).

**Con `20_deploy_kasm.yaml` (flujo original):** las contraseñas son fijas, `Admin1234!` y
`User1234!` respectivamente, salvo que se sobreescriban con `-e kasm_admin_password=...` /
`-e kasm_user_password=...`.

**Con `25_instalar_solo_kask_usuarios.yaml` (flujo nuevo):** las contraseñas son **aleatorias**,
generadas una vez por host y reutilizadas en ejecuciones posteriores (guardadas en
`.credenciales/`, ignorado por git). Al final del playbook quedan volcadas, junto con la
contraseña del usuario `alumno` y la URL del servidor, en un fichero CSV:

```
datos-acceso-<proyecto-formativo>-<fecha-de-creación>.csv
```

El prefijo `<proyecto-formativo>` (por defecto `general`, variable `kasm_proyecto_formativo`) evita
mezclar en el mismo CSV credenciales de cursos distintos desplegando Kasm en paralelo; sobreescribir
con `-e kasm_proyecto_formativo=mi-curso-2026`. Sin este parámetro en versiones anteriores del playbook
se generaba `datos-acceso-<fecha>.csv` (sin prefijo) — esos ficheros antiguos siguen siendo válidos y
no se tocan.

Columnas: `ip,alumno_password,kasm_url,kasm_admin_user,kasm_admin_password,kasm_user_user,kasm_user_password`
— una fila por servidor, actualizada (no duplicada) en cada ejecución posterior sobre el mismo
host, y segura frente a ejecuciones en paralelo sobre varios servidores a la vez (usa un lock de
fichero, uno distinto por proyecto formativo). Este CSV también está en `.gitignore`: **nunca se
sube al repositorio**, solo vive en el disco local de quien ejecuta el playbook.

Dentro del escritorio de la imagen personalizada, el usuario del sistema es:

| Campo | Valor |
|-------|-------|
| Usuario | `kasm_user` |
| Contraseña | `sta3war2` |

### Modo privilegiado del contenedor de sesión

Cada sesión de escritorio que lanza Kasm es un contenedor Docker. Ese contenedor se arranca en
modo privilegiado **por defecto**, porque es lo que necesitan las imágenes con Docker-in-Docker
(las que terminan en `-dind`) para poder ejecutar Docker dentro del escritorio.

#### Por qué es necesario

Una imagen DinD arranca su propio demonio `dockerd` mediante `supervisord`. Sin privilegios ese
demonio no puede montar `/tmp` ni `/sys/kernel/security`, ni cargar el módulo `ip_tables`, así que
nunca llega a crear el socket `/var/run/docker.sock`. El escritorio arranca con normalidad y el
cliente `docker` está instalado, pero cualquier comando falla:

```
failed to connect to the docker API at unix:///var/run/docker.sock;
check if the path is correct and if the daemon is running
```

El fallo es silencioso: el despliegue de Ansible termina sin errores y el escritorio se ve bien.
Solo se detecta al abrir una terminal dentro de la sesión y ejecutar `docker ps`.

#### Cómo se configura

| Variable | Ubicación | Valor por defecto |
|---|---|---|
| `kasm_privileged` | `20_deploy_kasm.yaml` (`vars`) | `true` |
| `KASM_PRIVILEGED` | entorno de `08_automatic_workspace_configure.sh` | `true` |

El playbook pasa la variable al script, y este la escribe como `"privileged": true` dentro del
`run_config` del workspace en la base de datos de Kasm. Kasm lee ese `run_config` cada vez que
crea un contenedor de sesión.

```
kasm_privileged (Ansible)
   └─> KASM_PRIVILEGED (entorno del script)
         └─> run_config.privileged (BD de Kasm, tabla images)
               └─> HostConfig.Privileged (contenedor de la sesión)
```

Valores aceptados por `KASM_PRIVILEGED`: `true`/`True`/`TRUE`/`yes`/`1` y `false`/`False`/`FALSE`/`no`/`0`.
Cualquier otro valor aborta el script con error en lugar de asumir un default silencioso.

#### Desactivarlo

Las imágenes sin DinD (IntelliJ, Go, la Python normal) no lo necesitan. Desactivarlo en esos casos
reduce la superficie de ataque, ya que un contenedor privilegiado tiene acceso efectivo al kernel
del host:

```bash
ansible-playbook 20_deploy_kasm.yaml --ask-vault-pass \
  -e "kasm_image=pepesan/mi-ubuntu-resolute-kasm:1.0" \
  -e "kasm_privileged=false"
```

No se autodetecta a partir del nombre de la imagen a propósito: el nombre no es un contrato fiable
y una imagen con DinD sin el sufijo `-dind` quedaría rota en silencio. Por eso el default es
activarlo y desactivarlo de forma consciente cuando no haga falta.

#### Comprobar el valor aplicado

En la configuración del workspace:

```bash
ssh root@IP_SERVIDOR \
  'docker exec kasm docker exec kasm_db psql -U kasmapp -d kasm -t -c "SELECT name, run_config FROM images;"'
```

En un contenedor de sesión que ya esté corriendo:

```bash
# listar las sesiones activas (nombres tipo adminkasm.lo_xxxxxxxx);
# el grep descarta los contenedores de infraestructura de Kasm
ssh root@IP_SERVIDOR 'docker exec kasm docker ps --format "{{.Names}}" | grep -v "^kasm_"'

# comprobar el flag
ssh root@IP_SERVIDOR 'docker exec kasm docker inspect NOMBRE_SESION --format "{{.HostConfig.Privileged}}"'   # -> true

# comprobar que Docker funciona dentro del escritorio
ssh root@IP_SERVIDOR 'docker exec kasm docker exec NOMBRE_SESION docker run --rm hello-world'   # -> Hello from Docker!
```

Los cambios en `run_config` solo afectan a las sesiones nuevas. Si modificas el valor sobre un
despliegue en marcha, hay que cerrar la sesión existente y abrir otra para que Kasm recree el
contenedor con la configuración nueva.

### Bastionado aplicado a Kasm

El despliegue aplica automáticamente una serie de restricciones de seguridad sobre el grupo All Users.

**Control del portapapeles**

El portapapeles está deshabilitado en todas sus variantes. No se puede copiar texto desde dentro de Kasm al host (`allow_kasm_clipboard_down=false`), ni del host hacia Kasm (`allow_kasm_clipboard_up=false`), ni usar el portapapeles fluido de Chromium (`allow_kasm_clipboard_seamless=false`). Además, en la configuración del workspace se pasan las variables de entorno `KASM_SVC_SEND_CUT_TEXT=-SendCutText 0` y `KASM_SVC_ACCEPT_CUT_TEXT=-AcceptCutText 0` directamente al proceso VNC del contenedor.

**Bloqueo de transferencia de ficheros**

La descarga de ficheros desde Kasm al host está bloqueada (`allow_kasm_downloads=false`), igual que la subida de ficheros del host a Kasm (`allow_kasm_uploads=false`). Esto se refuerza en el primer arranque del contenedor poniendo los directorios `Downloads` y `Uploads` del escritorio sin ningún permiso (`chmod 000`) y con propietario root.

**Bloqueo de impresión**

La impresión se bloquea en tres capas simultáneas. A nivel de directiva Kasm se establece `allow_kasm_printing=false` en los ajustes de grupo, y la variable `KASM_SVC_PRINTER=0` se pasa al proceso VNC. El servicio CUPS se detiene y deshabilita en el primer arranque del contenedor. Por último, se inyecta un fichero de configuración en el nginx de `kasm_proxy` que añade CSS para ocultar todo el contenido en impresión y bloquea por JavaScript tanto el atajo `Ctrl+P`/`Cmd+P` como el evento `beforeprint`.

**Gestión de sesiones**

El tiempo de expiración por inactividad está configurado a cero, lo que significa que las sesiones no expiran. Si en algún momento se activara esa expiración, la acción configurada sería pausar la sesión en lugar de eliminarla.

**Disponibilidad de imágenes**

El modo de limpieza de imágenes en todos los servidores se establece a `No Prune`, para evitar que el agente de Kasm elimine automáticamente las imágenes personalizadas cuando no hay ninguna sesión activa que las use.

## Script de lanzamiento

El script `launch_tasks_with_vault.sh` agrupa los comandos de los playbooks más habituales como referencia rápida. Está comentado para que puedas descomentar y ejecutar solo los pasos que necesites.
