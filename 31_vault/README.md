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

| Imagen | Descripción |
|--------|-------------|
| `pepesan/mi-ubuntu-noble-kasm:1.0` *(por defecto)* | Ubuntu 24.04 con IntelliJ, ZAP y Firefox |
| `pepesan/mi-ubuntu-noble-kasm-go` | Ubuntu 24.04 con entorno de desarrollo Go |

### Playbooks de Kasm

| Playbook | Descripción |
|----------|-------------|
| `20_deploy_kasm.yaml` | Despliega Kasm completo (instalación, workspace, bastionado) |
| `21_undeploy_kasm.yaml` | Elimina Kasm completamente para empezar desde cero |
| `22_configure_letsencrypt.yaml` | Configura certificado Let's Encrypt para HTTPS (requiere DNS configurado) |

### Uso

```bash
# Imagen por defecto
ansible-playbook 20_deploy_kasm.yaml --ask-vault-pass

# Imagen de desarrollo Go
ansible-playbook 20_deploy_kasm.yaml --ask-vault-pass -e "kasm_image=pepesan/mi-ubuntu-noble-kasm-go"

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

## Script de lanzamiento

El script `launch_tasks_with_vault.sh` agrupa los comandos de los playbooks más habituales como referencia rápida. Está comentado para que puedas descomentar y ejecutar solo los pasos que necesites.
