#!/bin/bash
# Comprobacion de conexión  (hecho)
ansible-playbook 00_ping.yaml --ask-vault-pass
# instalación de docker
ansible-playbook 01_docker_install.yaml --ask-vault-pass
# creación del usuario alumno (hecho)
ansible-playbook 02_adduser_alumno.yaml --ask-vault-pass
# instalación de sdkman (hecho)
ansible-playbook 03_sdkman_install.yaml --ask-vault-pass
# instalación de xrdp gnome (hecho)
ansible-playbook 04_01_xrdp_install_gnome.yaml --ask-vault-pass
# instalación de xrdp xfce(hecho)
ansible-playbook 04_02_xrdp_install_xfce.yaml --ask-vault-pass
# instalación de intellij (hecho)
ansible-playbook 05_intellij_install.yaml --ask-vault-pass
# instalacion de chrome y chromedriver
ansible-playbook 06_chrome_chromedriver_install.yaml --ask-vault-pass
# actualización de sistema (hecho)
ansible-playbook 07_system_update.yaml --ask-vault-pass
# descarga de repositorios git (hecho)
ansible-playbook 08_download_git.yaml --ask-vault-pass

# reinicio de la máquina
ansible-playbook 10_reboot.yaml --ask-vault-pass


