#!/bin/bash

# creación del usuario alumno
ansible-playbook 02_adduser_alumno.yaml --ask-vault-pass
# instalación de xrdp
ansible-playbook 04_xrdp_install.yaml --ask-vault-pass
# actualización de sistema
ansible-playbook 07_system_update.yaml --ask-vault-pass
# descarga de repositorios git
ansible-playbook 08_download_git.yaml --ask-vault-pass

# reinicio de la máquina
ansible-playbook 10_reboot.yaml --ask-vault-pass


