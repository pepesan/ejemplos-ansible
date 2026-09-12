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
| `20_deploy_kasm.yaml` | Despliega Kasm completo (instalación, workspace, bastionado) |
| `21_undeploy_kasm.yaml` | Elimina Kasm completamente para empezar desde cero |
| `22_configure_letsencrypt.yaml` | Configura certificado Let's Encrypt para HTTPS (requiere DNS configurado) |

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

Una vez desplegado, acceder a `https://IP_SERVIDOR/` con alguno de estos usuarios:

| Rol | Usuario | Contraseña |
|-----|---------|------------|
| Administrador | `admin@kasm.local` | `Admin1234!` |
| Usuario normal | `user@kasm.local` | `User1234!` |

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
