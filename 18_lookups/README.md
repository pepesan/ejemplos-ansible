# 18_lookups

Ejemplos de `lookup`. Son de solo lectura: no modifican la VM de `mi-inventario`.

```bash
ansible-playbook tasks.yaml
ansible-playbook tasks.yaml --tags lookup   # solo las dos primeras tareas
```

**Un lookup se ejecuta en el equipo de control, no en el servidor.** La tarea 1 lee el `/etc/hostname`
del equipo desde el que lanzas Ansible y la 1b muestra el del servidor (con un fact), para ver la diferencia.

| Lookup | Qué hace |
|---|---|
| `file` | Contenido de un fichero del control. |
| `env` | Variable de entorno del control. |
| `pipe` | Salida de un comando local. |
| `password` | Contraseña aleatoria (con `/dev/null` no se guarda). |
| `fileglob` | Lista de ficheros por patrón. |
| `first_found` | Primer fichero que exista de una lista. |
| `ini` | Valor de un fichero `.ini` (`datos.ini`). |
| `template` | Plantilla Jinja2 (`plantilla.j2`) ya procesada. |
| `varnames` | Nombres de variables que coinciden con una expresión regular. |
