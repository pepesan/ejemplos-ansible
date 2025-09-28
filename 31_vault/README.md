# Despliegue de máquinas  remotas con Ansible y usando Vault

## Introducción
Este proyecto tiene como objetivo desplegar máquinas remotas utilizando Ansible y gestionar las credenciales de manera segura con Ansible Vault. Ansible Vault permite cifrar archivos sensibles, como contraseñas y claves SSH, para proteger la información confidencial durante el despliegue.
## Requisitos previos
- Tener Ansible instalado en tu máquina local.
- Tener acceso a las máquinas remotas que deseas gestionar.
- Tener Ansible Vault instalado (viene incluido con Ansible).
- Tener configurado SSH para acceder a las máquinas remotas.
- Tener un archivo de inventario de Ansible que liste las máquinas remotas.
- Tener un archivo de configuración de Ansible (ansible.cfg) adecuado.
## Configuración de Ansible Vault
En primer lugar, existe un archivo de contraseñas para Ansible Vault. Este archivo contendrá la contraseña que se utilizará para acceder con el usuario a la máquina en remoto.
Este fichero está dentro de la carpeta `group_vars/all/vault.yml` que ya se encuentra cifrado.
Pero si quieres crear uno nuevo, puedes hacerlo con el siguiente comando:
```bash
nano group_vars/all/vault.yml
```
Esto abrirá un editor de texto donde puedes ingresar las variables que deseas cifrar. Por ejemplo:
```yaml
alumno_password_plain: tu_contrasegna_aqui
```
Guarda y cierra el editor.

Luego, cifra el archivo con el siguiente comando:
```bash
ansible-vault encrypt group_vars/all/vault.yml
```
Se te pedirá que ingreses una contraseña para proteger el archivo. Asegúrate de recordar esta contraseña, ya que la necesitarás para descifrar el archivo más adelante.
## Uso de Ansible Vault en Playbooks
Para utilizar las variables cifradas en tus playbooks de Ansible, simplemente incluye el archivo cifrado en tu playbook. Por ejemplo:
```yaml
---
- name: Desplegar aplicación con variables cifradas
  hosts: localhost # ejecución en local
  connection: local
  vars_files:
    - secrets.yaml
  tasks:
    - name: Mostrar la contraseña de la base de datos
      debug:
        msg: "La contraseña de la base de datos es {{ db_password }}"
``` 
Cuando ejecutes el playbook, utiliza la opción `--ask-vault-pass` para que Ansible te solicite la contraseña del Vault:
```bash
ansible-playbook playbook.yml --ask-vault-pass
```
Entonces te pedirá la contraseña que usaste para cifrar el archivo, y podrás acceder a las variables cifradas dentro del playbook.
## Despliegue de máquinas remotas
En este ejemplo estamos haciendo un despliegue en remoto de una máquina virtual en Contabo, pero se puede hacer con cualquier máquina remota.

El script llamado `launch_tasks_with_vault.sh` hace lo siguiente, ejecuta paso a paso los siguientes playbooks:
1. `01_docker_install.yaml`: Instala Docker en la máquina remota.
2. `02_sdkman_install.yaml`: Instala SDKMAN en la máquina remota.
3. `03_xrdp_install.yaml`: Instala XRDP en la máquina remota, para poder acceder a la máquina de forma gráfica.
4. `04_intellij_install.yaml`: Instala IntelliJ IDEA en la máquina remota.
5. `05_adduser_alumno.yaml`: Añade un usuario llamado "alumno" en la máquina remota. Usando la contraseña que está en el vault y lo mete en el grupo docker y en sudo.
6. `06_chrome_chromedriver_install.yaml`: Instala Google Chrome y ChromeDriver en la máquina remota.
7. `07_system_update.yaml`: Actualiza el sistema operativo de la máquina remota.
8. `08_download_git.yaml`: Instala git y clona unos repositorios de Git en la máquina remota.
9. `10_reboot.yaml`: Reinicia la máquina remota para aplicar todos los cambios.

## Conclusión
Ansible Vault es una herramienta poderosa para gestionar credenciales de manera segura durante el despliegue de máquinas remotas con Ansible. Siguiendo los pasos descritos en este README, puedes proteger tu información sensible y automatizar el proceso de despliegue de manera segura.
Así tendremos instaladas todas las herramientas necesarias para trabajar en remoto con la máquina:
- Docker
- SDKMAN y el JDK 21
- XRDP
- IntelliJ IDEA
- Google Chrome y ChromeDriver
- Git y repositorios clonados
- Usuario "alumno" con permisos de sudo y docker
- Sistema operativo actualizado
- Máquina reiniciada para aplicar cambios



