# 17_etiquetas

Ejemplo de etiquetas (tags) de Ansible. Todo ocurre en `/tmp/ejemplo-etiquetas` de la VM de `mi-inventario`;
no se toca la configuración del sistema. Ejecuta los comandos desde este directorio.

## Ver qué hay
```bash
ansible-playbook tasks.yaml --list-tags     # etiquetas disponibles
ansible-playbook tasks.yaml --list-tasks    # tarea por tarea, con sus etiquetas
```

## Ejecutar solo una parte
Orden recomendado (cada paso parte del estado que dejó el anterior):
```bash
ansible-playbook tasks.yaml --tags limpieza          # 0. partir de cero (borra /tmp/ejemplo-etiquetas)
ansible-playbook tasks.yaml --tags copia             # 1. FALLA a propósito: el directorio no existe, las etiquetas no resuelven dependencias
ansible-playbook tasks.yaml --tags preparacion       # 2. solo crear el directorio (y las tareas "always")
ansible-playbook tasks.yaml --tags copia             # 3. ahora sí: copia el fichero (y dispara el handler)
ansible-playbook tasks.yaml --tags informe           # 4. leer y mostrar el fichero copiado (block con etiqueta heredada)
ansible-playbook tasks.yaml --tags preparacion,copia # 5. varias etiquetas a la vez
ansible-playbook tasks.yaml --tags ficheros          # 6. una etiqueta compartida por dos tareas (directorio + copia)
ansible-playbook tasks.yaml --tags untagged          # 7. solo las tareas sin etiqueta
ansible-playbook tasks.yaml --skip-tags copia        # 8. todo menos la copia (el informe lee lo ya copiado)
ansible-playbook tasks.yaml                          # 9. todo, salvo lo marcado con never
ansible-playbook tasks.yaml --tags limpieza          # 10. deshacer
```

## Etiquetas especiales
| Etiqueta | Efecto |
|---|---|
| `always` | La tarea se ejecuta siempre, aunque se filtre por otra etiqueta. |
| `never` | La tarea no se ejecuta salvo que se pida otra de sus etiquetas. |
| `untagged` / `tagged` | Seleccionan las tareas sin etiqueta / con alguna etiqueta. |
