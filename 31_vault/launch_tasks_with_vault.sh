#!/bin/bash
# Comprobacion de conexión  (hecho)
# ansible-playbook 00_ping.yaml --ask-vault-pass
# instalación de docker
# ansible-playbook 01_docker_install.yaml --ask-vault-pass
# creación del usuario alumno (hecho)
# ansible-playbook 02_adduser_alumno.yaml --ask-vault-pass
# instalación de sdkman (hecho)
# ansible-playbook 03_sdkman_install.yaml --ask-vault-pass
# instalación de xrdp gnome (hecho)
# ansible-playbook 04_01_xrdp_install_gnome.yaml --ask-vault-pass
# instalación de xrdp xfce(hecho)
# ansible-playbook 04_02_xrdp_install_xfce.yaml --ask-vault-pass
# instalación de intellij (hecho)
# ansible-playbook 05_intellij_install.yaml --ask-vault-pass
# instalacion de chrome y chromedriver
# ansible-playbook 06_chrome_chromedriver_install.yaml --ask-vault-pass
# actualización de sistema (hecho)
# ansible-playbook 07_system_update.yaml --ask-vault-pass
# descarga de repositorios git (hecho)
# ansible-playbook 08_download_git.yaml --ask-vault-pass
# Instalación de vscode y extensiones php (hecho)
# ansible-playbook 09_install_vscode_php.yaml --ask-vault-pass
# Instalación de vscode y extensiones docker y k8s (hecho)
# ansible-playbook 09_install_vscode_docker_k8s.yaml --ask-vault-pass
# Instalación de vscode y extensiones python (hecho)
# ansible-playbook 09_install_vscode_python.yaml --ask-vault-pass
# Instalación de vscode y extensiones terraform y aws (hecho)
# ansible-playbook 09_install_vscode_terraform_localstack.yaml --ask-vault-pass
# instalación del servidor drupal (hecho)
# ansible-playbook 10_install_drupal.yaml --ask-vault-pass
# copia de los ejemplos de drupal (hecho)
# ansible-playbook 12_copy_drupal_examples.yaml --ask-vault-pass
# Limpia entornos drupal (hecho)
# ansible-playbook 13_clean_drupal_environment.yaml --ask-vault-pass
# Despliega docker compose para jupyter notebook (hecho)
# ansible-playbook 14_deploy_docker_compose_jupiter_notebook.yaml --ask-vault-pass
# Despliega mongodb tools (hecho)
# ansible-playbook 15_deploy_mongodb_tools.yaml --ask-vault-pass
# Despliega Terraform, aws cli y localstack  (hecho)
# ansible-playbook 16_deploy_terraform_localstack.yaml --ask-vault-pass
# Despliega Mysql client  (hecho)
# ansible-playbook 17_deploy_mysql_client.yaml --ask-vault-pass
# Delete docker container  (hecho)
# ansible-playbook 18_delete_docker_container.yaml --ask-vault-pass
# Delete jupiter docker container  (hecho)
# ansible-playbook 19_delete_jupyter_docker_container.yaml --ask-vault-pass
# Deploy Kasm (Resolute)
# Por defecto: Python + DinD (PyCharm, MariaDB, VS Code Python)
# ansible-playbook 20_deploy_kasm.yaml --ask-vault-pass
# IntelliJ + ZAP + Firefox
# ansible-playbook 20_deploy_kasm.yaml --ask-vault-pass -e kasm_image=pepesan/mi-ubuntu-resolute-kasm:1.0
# Go (GoLand, MariaDB, VS Code Go)
# ansible-playbook 20_deploy_kasm.yaml --ask-vault-pass -e kasm_image=pepesan/mi-ubuntu-resolute-kasm-go:1.0
# Python (PyCharm, MariaDB, VS Code Python, sin DinD)
# ansible-playbook 20_deploy_kasm.yaml --ask-vault-pass -e kasm_image=pepesan/mi-ubuntu-resolute-kasm-python:1.0
# Python (PyCharm, MariaDB, VS Code Python, con DinD)
# ansible-playbook 20_deploy_kasm.yaml --ask-vault-pass -e kasm_image=pepesan/mi-ubuntu-resolute-kasm-python-dind:1.1
# Java Spring Boot web dev (SDKMAN, Maven, Gradle, JDKs LTS, con DinD)
# ansible-playbook 20_deploy_kasm.yaml --ask-vault-pass -e kasm_image=pepesan/mi-ubuntu-resolute-kasm-java-spring-boot-web-dev-dind:1.2
# Otras imágenes reconocidas: ...-kasm-java-ciberseguridad-dind, ...-kasm-dind, ...-kasm-go-dind, ...-kasm-desktop
# Lo mismo, poniendo tú el nombre y la descripción del workspace con -e:
# ansible-playbook 20_deploy_kasm.yaml --ask-vault-pass -e kasm_image=pepesan/mi-ubuntu-resolute-kasm-java-spring-boot-web-dev-dind:1.2 -e kasm_workspace_name="Java Dev" -e kasm_workspace_desc="Entorno Java con Spring Boot"
#
# Nombre y descripción del workspace en Kasm:
#   Por defecto se deducen del nombre de la imagen (los patrones están en
#   files/kasm/08_automatic_workspace_configure.sh). Ej. la imagen Java Spring Boot DinD
#   se crea como "Ubuntu Resolute Java Spring Boot DinD". Una imagen que el script no
#   reconoce se crea como "Ubuntu Noble Custom" con la descripción genérica
#   "con IntelliJ, ZAP, Firefox", que puede no ser cierta.
#   Para fijarlos a mano, pasa una o las dos variables (ambas opcionales e independientes):
#     kasm_workspace_name  -> nombre visible del workspace
#     kasm_workspace_desc  -> descripción del workspace
#   También se pueden dejar fijos editando sus valores en el bloque vars: de 20_deploy_kasm.yaml
#   (vacío = deducir de la imagen). Ejemplo con una imagen propia no reconocida:
# ansible-playbook 20_deploy_kasm.yaml --ask-vault-pass -e kasm_image=miusuario/mi-imagen:2.0 -e kasm_workspace_name="Mi workspace" -e kasm_workspace_desc="Entorno de pruebas"
#   Nota: si ya existe un workspace con el mismo nombre de imagen (con tag), el script lo
#   omite y NO lo renombra; para cambiarlo, bórralo antes desde la consola de Kasm o
#   ejecuta el 21_undeploy_kasm.yaml.
# Si falla la creación, el script termina con error e imprime el motivo:
#   "ERROR al crear workspace '<nombre>' (imagen <imagen>): <mensaje de la API de Kasm>"
#
# Dominio: cada nodo cuelga de <node_name>.<kasm_base_domain> (node_name lo fija el inventory,
# ej. "node_name=nodo01"). kasm_base_domain por defecto es "kasm.cursosdedesarrollo.com",
# definido en group_vars/all/vars.yml — usado tanto por 20_deploy_kasm.yaml como por
# 22_configure_letsencrypt.yaml. Dos formas de cambiarlo a otro dominio:
#   1) Editar kasm_base_domain en group_vars/all/vars.yml (afecta a todos los despliegues)
#   2) Sobreescribirlo solo para esta llamada con -e:
# ansible-playbook 20_deploy_kasm.yaml --ask-vault-pass -e kasm_base_domain=miotrodominio.com
# Undeploy Kasm (elimina contenedores y datos, pero NO el certificado de Let's Encrypt
# en /etc/letsencrypt ni los ficheros de contraseñas en .credenciales/):
#ansible-playbook 21_undeploy_kasm.yaml --ask-vault-pass
# Configurar Let's Encrypt (requiere DNS apuntando al servidor; usa el mismo kasm_base_domain):
# ansible-playbook 22_configure_letsencrypt.yaml --ask-vault-pass
# ansible-playbook 22_configure_letsencrypt.yaml --ask-vault-pass -e kasm_base_domain=miotrodominio.com
#
# ============================================================
# 23/24/25: flujo alternativo separando instalación de Kasm y creación de workspaces
# (recomendado frente a 20_deploy_kasm.yaml si vas a gestionar varios workspaces en el
# mismo servidor, o si quieres poder añadir/quitar imágenes sin reinstalar Kasm cada vez)
# ============================================================
#
# 25_instalar_solo_kask_usuarios.yaml: instala Kasm + usuario alumno + HTTPS real de
# Let's Encrypt (fusiona lo que antes eran 20+22), SIN crear ningún workspace. Genera
# contraseñas aleatorias (alumno, admin@kasm.local, user@kasm.local) la primera vez y
# las reutiliza en ejecuciones posteriores (guardadas en .credenciales/, gitignored).
# Al final deja un CSV con todas las credenciales: datos-acceso-<proyecto-formativo>-<fecha-de-creación>.csv
# (también gitignored; una fila por IP, se actualiza/añade fila en cada ejecución,
# seguro para varias máquinas en paralelo gracias a un lock de fichero). El prefijo
# <proyecto-formativo> por defecto es "general"; cámbialo con -e kasm_proyecto_formativo=...
# para no mezclar en el mismo CSV credenciales de cursos distintos desplegados en paralelo.
#
# Orden recomendado:
# ansible-playbook -i inventory 01_docker_install.yaml --ask-vault-pass
# ansible-playbook -i inventory 02_adduser_alumno.yaml --ask-vault-pass
# ansible-playbook -i inventory 25_instalar_solo_kask_usuarios.yaml --ask-vault-pass
#
# Desactivar el paso de Let's Encrypt (ej. si el DNS todavía no apunta al servidor):
# ansible-playbook -i inventory 25_instalar_solo_kask_usuarios.yaml --ask-vault-pass -e kasm_letsencrypt_enabled=false
#
# Sobreescribir contraseñas en vez de generarlas aleatorias:
# ansible-playbook -i inventory 25_instalar_solo_kask_usuarios.yaml --ask-vault-pass -e kasm_admin_password=MiPass123! -e kasm_user_password=MiPass456!
#
# Prefijo de proyecto formativo (curso) para el CSV de credenciales — genera
# datos-acceso-curso-devops-2026-<fecha>.csv en vez de datos-acceso-general-<fecha>.csv:
# ansible-playbook -i inventory 25_instalar_solo_kask_usuarios.yaml --ask-vault-pass -e kasm_proyecto_formativo=curso-devops-2026
#
# ------------------------------------------------------------
# 23_crear_workspace.yaml: registra UN workspace nuevo (descarga la imagen + lo crea en
# Kasm), sin reinstalar nada. Es idempotente: si el workspace (misma imagen:tag) ya
# existe, lo detecta y no lo duplica. Por defecto crea
# pepesan/mi-ubuntu-resolute-kasm-java-spring-boot-web-dev-dind con persistencia activada.
#
# Todos los parámetros disponibles (todos opcionales salvo kasm_image si no quieres el
# default; OJO con valores que tengan espacios: -e var="valor con espacios" trunca en el
# primer espacio en Ansible, usa JSON: -e '{"kasm_workspace_name": "Nombre con espacios"}'):
# ansible-playbook -i inventory 23_crear_workspace.yaml --ask-vault-pass \
#   -e kasm_image=pepesan/mi-ubuntu-resolute-kasm-go:1.0 \
#   -e '{"kasm_workspace_name": "Ubuntu Resolute Go"}' \
#   -e '{"kasm_workspace_desc": "Entorno de desarrollo Go (GoLand, MariaDB)"}' \
#   -e kasm_workspace_cores=2 \
#   -e kasm_workspace_memory_gb=4 \
#   -e kasm_workspace_privileged=false \
#   -e kasm_workspace_gpu_count=0 \
#   -e kasm_workspace_session_time_limit=3600 \
#   -e kasm_workspace_category=Desarrollo \
#   -e kasm_workspace_enabled=true \
#   -e 'kasm_workspace_persistent_profile_path=/opt/kasm_profiles/{user_id}/{image_id}' \
#   -e kasm_workspace_staging_enabled=false \
#   -e kasm_workspace_staging_num_sessions=1 \
#   -e kasm_workspace_staging_expiration_hours=24 \
#   -e kasm_workspace_staging_zone_name=default
#
# Nota sobre staging: requiere que la zona de Kasm tenga un dominio fijo configurado
# (no $request_host$); si no, se avisa por stderr y se omite sin fallar la creación
# del workspace (revisa el "stderr" del registro, el playbook lo muestra aparte).
#
# API key de Kasm: se genera una sola vez por servidor (persistente en el propio
# servidor, /opt/kasm/.kasm_api_key.json, protegido con flock frente a ejecuciones
# en paralelo) y se reutiliza en creaciones posteriores de workspace, en vez de
# crear/destruir una nueva cada vez. Cada ejecución de este playbook se trae una
# copia a esta carpeta en kasm-api-key-<ip>.json (gitignored, patrón
# kasm-api-key-*.json) — una API key por servidor, nunca compartida entre hosts.
# Tiene permisos tanto para crear workspaces (200, admin) como para pedir/consultar/
# destruir sesiones (100, usuario), así que la misma key sirve para validar después
# que un workspace levanta sesión de verdad sin entrar al navegador:
#
# DOMAIN="https://tu-dominio-kasm"
# API_KEY=$(python3 -c "import json;print(json.load(open('kasm-api-key-IP.json'))['api_key'])")
# API_SECRET=$(python3 -c "import json;print(json.load(open('kasm-api-key-IP.json'))['api_key_secret'])")
# USER_ID=$(curl -sk -X POST "$DOMAIN/api/authenticate" -H "Content-Type: application/json" \
#   -d '{"username":"user@kasm.local","password":"LA_PASSWORD_DEL_CSV"}' \
#   | python3 -c 'import sys,json;print(json.load(sys.stdin)["user_id"])')
# IMAGE_ID=$(curl -sk -X POST "$DOMAIN/api/public/get_images" -H "Content-Type: application/json" \
#   -d "{\"api_key\":\"$API_KEY\",\"api_key_secret\":\"$API_SECRET\"}" \
#   | python3 -c 'import sys,json; [print(i["image_id"]) for i in json.load(sys.stdin)["images"] if "NOMBRE_IMAGEN" in i["name"]]')
# KASM_ID=$(curl -sk -X POST "$DOMAIN/api/public/request_kasm" -H "Content-Type: application/json" \
#   -d "{\"api_key\":\"$API_KEY\",\"api_key_secret\":\"$API_SECRET\",\"user_id\":\"$USER_ID\",\"image_id\":\"$IMAGE_ID\"}" \
#   | python3 -c 'import sys,json;print(json.load(sys.stdin)["kasm_id"])')
# curl -sk -X POST "$DOMAIN/api/public/get_kasm_status" -H "Content-Type: application/json" \
#   -d "{\"api_key\":\"$API_KEY\",\"api_key_secret\":\"$API_SECRET\",\"user_id\":\"$USER_ID\",\"kasm_id\":\"$KASM_ID\"}" \
#   | python3 -c 'import sys,json;print(json.load(sys.stdin)["kasm"]["operational_status"])'   # -> "running"
# curl -sk -X POST "$DOMAIN/api/public/destroy_kasm" -H "Content-Type: application/json" \
#   -d "{\"api_key\":\"$API_KEY\",\"api_key_secret\":\"$API_SECRET\",\"user_id\":\"$USER_ID\",\"kasm_id\":\"$KASM_ID\"}"
#
# Validado en Contabo (2026-10-08): dos ciclos completos 21 -> 25 -> 23 (escritorio
# java-spring-boot-web-dev-dind:1.5) -> 23 (terminal terminal-dind:1.1); en ambos
# ciclos ambas sesiones llegaron a operational_status "running" sin intervención manual.
#
# ------------------------------------------------------------
# 24_limpiar_workspace.yaml: borra un workspace (o TODOS) — borra el registro en Kasm,
# la imagen Docker del DinD (libera espacio real) y limpia layers huérfanos. Por defecto
# TAMBIÉN borra los perfiles persistentes de los usuarios que lo hayan usado (IRREVERSIBLE).
# Es el default a propósito: el perfil persistente se indexa por image_id, no por
# workspace, así que si se deja vivo puede arrastrar contenido de una versión anterior
# de la imagen a un workspace nuevo que reutilice el mismo image_id (ver sesión del
# 2026-10-08: icono de docker-twitch desactualizado tras actualizar la imagen sin
# recrear el workspace, mismo image_id de por medio).
#
# Borrar un workspace concreto (incluye su perfil persistente):
# ansible-playbook -i inventory 24_limpiar_workspace.yaml --ask-vault-pass -e kasm_image=pepesan/mi-ubuntu-resolute-kasm-go:1.0
#
# Borrar TODOS los workspaces registrados (incluye todos los perfiles persistentes):
# ansible-playbook -i inventory 24_limpiar_workspace.yaml --ask-vault-pass -e kasm_clean_all=true
#
# Borrar el workspace pero conservar los perfiles persistentes de los usuarios:
# ansible-playbook -i inventory 24_limpiar_workspace.yaml --ask-vault-pass -e kasm_image=pepesan/mi-ubuntu-resolute-kasm-go:1.0 -e kasm_delete_persistent_data=false
#
# reinicio de la máquina
# ansible-playbook 30_reboot.yaml --ask-vault-pass


