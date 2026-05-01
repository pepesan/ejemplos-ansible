#!/bin/bash


open https://127.0.0.1:443

# Como esta con un certificado autofirmado, el navegador mostrará una advertencia de seguridad. Deberás aceptar la excepción para continuar.
# Logueate con el usuario "admin@kasm.local" y la contraseña definida durante la instalación (en el paso anterior).
# Por ejemplo, puedes usar "Admin1234!" si la pusiste como ejemplo.
# Accede a la sección "Workspaces" y haz clic en "Create Workspace".
# Workspace Type: Container
# Friendly Name: Ubuntu Noble Custom
# Description: Ubuntu 24.04 con IntelliJ, ZAP, Firefox
# Docker Image: pepesan/mi-ubuntu-noble-kasm:1.0
# Cores: 4
# Memory: 8000
# GPU Count: 0
# Método de Asignación de CPU: Heredar

# Pulsa en Guardar
# Tendrás que esperar a que se cree el workspace, lo cual puede tardar unos minutos.

# Vete a Espacios de Trabajo (Workspaces) en la parte superior izquierda
# Y haz clic en el nombre del workspace que acabas de crear para arrancarlo.
# Para abandonar el workspace, pulsa en el menu flotante de la izquierda y selecciona "Esapcios de Trabajo/ Abandonar esta sesión".
# Si quieres eliminar el workspace, vete a la sección de Workspaces, haz clic en los tres puntos del workspace y selecciona "Delete Workspace".
# Ten cuidado, esto eliminará todos los datos dentro del contenedor asociado a ese workspace.





