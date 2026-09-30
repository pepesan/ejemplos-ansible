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
# Undeploy Kasm (elimina contenedores y datos):
#ansible-playbook 21_undeploy_kasm.yaml --ask-vault-pass
# Configurar Let's Encrypt (requiere DNS apuntando al servidor; usa el mismo kasm_base_domain):
# ansible-playbook 22_configure_letsencrypt.yaml --ask-vault-pass
# ansible-playbook 22_configure_letsencrypt.yaml --ask-vault-pass -e kasm_base_domain=miotrodominio.com
# reinicio de la máquina
# ansible-playbook 30_reboot.yaml --ask-vault-pass


