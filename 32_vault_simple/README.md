## Introducción
Ansible Vault es una herramienta que permite cifrar y proteger datos sensibles, como contraseñas y claves API, dentro de archivos de Ansible. En esta entrada, se explica cómo guardar y manejar secretos con Ansible Vault para mejorar la seguridad de tus playbooks.
Y cómo integrarlo en el lanzamiento de un playbook de Ansible.

## Requisitos previos
Antes de comenzar, asegúrate de tener lo siguiente:
- Ansible instalado en tu máquina.
- Un archivo de inventario de Ansible.
- Un archivo de configuración de Ansible (opcional).

## Pasos para manejar secretos con Ansible Vault
1. **Crear un fichero de Variables de Ansible**: Crea un archivo YAML donde almacenarás las variables que deseas cifrar. Por ejemplo, crea un archivo llamado `secrets.yaml` con el siguiente contenido:
```yaml
db_password: mi_contraseña_secreta
```
2. **Cifrar el archivo con Ansible Vault**: Utiliza el comando `ansible-vault encrypt` para cifrar el archivo que contiene las variables sensibles. Ejecuta el siguiente comando en la terminal:
```bash
ansible-vault encrypt secrets.yaml
```
Se te pedirá que ingreses una contraseña para proteger el archivo. Asegúrate de recordar esta contraseña, ya que la necesitarás para descifrar el archivo más adelante.
3. **Usar las variables cifradas en un playbook**: En tu playbook de Ansible, puedes incluir el archivo cifrado utilizando la directiva `vars_files`. Aquí tienes un ejemplo de un playbook que utiliza las variables cifradas:
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
        msg: 'La contraseña de la base de datos es {{ db_password }}'
```
4. **Ejecutar el playbook con Ansible Vault**: Para ejecutar el playbook que contiene variables cifradas, utiliza el comando `ansible-playbook` junto con la opción `--ask-vault-pass` para que se te solicite la contraseña del vault. Ejecuta el siguiente comando:
```bash
ansible-playbook playbook.yaml --ask-vault-pass
```
Se te pedirá que ingreses la contraseña que utilizaste para cifrar el archivo `secrets.yml`. Una vez ingresada la contraseña correcta, Ansible descifrará el archivo y ejecutará el playbook utilizando las variables sensibles.
Deberías ver la salida del playbook, incluyendo la contraseña de la base de datos que se mostró en la tarea de depuración.

5. **Editar un archivo cifrado**: Si necesitas modificar las variables cifradas, puedes utilizar el comando `ansible-vault edit` para abrir el archivo en un editor de texto. Ejecuta el siguiente comando:
```bash
ansible-vault edit secrets.yaml
```
Se te pedirá que ingreses la contraseña del vault. Después de ingresar la contraseña, el archivo se abrirá en el editor predeterminado, donde podrás realizar los cambios necesarios. Una vez que hayas terminado de editar, guarda el archivo y cierra el editor. El archivo permanecerá cifrado.
Si quieres cambiar el editor por defecto puedes usar la variable de entorno EDITOR, por ejemplo:
```bash
export EDITOR=nano
```
De esta manera se abrirá el archivo con nano en lugar del editor por defecto.
6. **Ver el contenido de un archivo cifrado**: Si en algún momento necesitas descifrar el archivo para verlo en texto plano, puedes utilizar el comando `ansible-vault decrypt`. Ejecuta el siguiente comando:
```bash
ansible-vault view secrets.yaml
```
Se te pedirá que ingreses la contraseña del vault. Después de ingresar la contraseña, el contenido del archivo se mostrará en la terminal en texto plano, pero el archivo permanecerá cifrado.
7. **Eliminar el cifrado de un archivo**: Si deseas eliminar el cifrado de un archivo y dejarlo en texto plano, puedes utilizar el comando `ansible-vault decrypt`. Ejecuta el siguiente comando:
```bash
ansible-vault decrypt secrets.yaml
```
8. **No mostrar el log de una tarea**: Si no quieres que se muestre el log de una tarea en la salida del playbook, puedes utilizar el parámetro `no_log: true` en la tarea. Aquí tienes un ejemplo:
```yaml
- name: Mostrar la contraseña de la base de datos
  debug:
    msg: 'La contraseña de la base de datos es {{ db_password }}'
  no_log: true
```
Con esta configuración, la salida de la tarea no se mostrará en la terminal, protegiendo así la información sensible.
Recuerda hacer esto cada vez que uses una variable sensible en una tarea.
## Conclusión
Siguiendo estos pasos, deberías poder manejar secretos de manera segura utilizando Ansible Vault. Esta herramienta es esencial para proteger datos sensibles en tus playbooks de Ansible, mejorando la seguridad de tus despliegues y configuraciones.
