# 09 · Imports e includes

Ansible permite **reutilizar** playbooks, ficheros de tareas y roles de dos maneras:

| | `import_*` (estático) | `include_*` (dinámico) |
|---|---|---|
| Cuándo se procesa | **Al leer** el playbook, antes de ejecutar nada | **Al ejecutar**, cuando se llega a esa tarea |
| Qué se ve en `--list-tasks` | Las tareas del fichero importado | Solo la tarea `include`, no su contenido |
| Con `when` | La condición se copia a **cada** tarea importada | Se evalúa **una vez**, en la tarea `include` |
| Con `loop` | No lo admite | Sí: procesa el fichero una vez por elemento |
| Nombre de fichero con variables | No (debe conocerse al leer) | Sí (`"tasks/demo_{{ tipo }}.yaml"`) |
| `tags` | Se aplican a las tareas importadas | Solo afectan a la tarea `include` |

Regla práctica: **`import`** cuando el fichero es fijo y quieres que todo sea predecible;
**`include`** cuando necesitas decidir en tiempo de ejecución (bucles, variables, condiciones).

## Qué hay en esta carpeta

```
main.yaml                       # import_playbook: encadena los playbooks de tasks/
tasks/webservers.yaml           # play de servidores web (nginx)
tasks/databases.yaml            # play de bases de datos (MariaDB 13.0)
tasks/firewall.yaml             # tareas reutilizables: abrir puertos en UFW (variable firewall_ports)
tasks/mariadb_repo.yaml         # tareas reutilizables: repositorio oficial de MariaDB
tasks/demo_item.yaml            # dos tareas sencillas para la demostración import vs include
roles/motd/                     # rol mínimo: escribe un mensaje del día con una plantilla
templates/index.html.j2         # página web
vars/webservers.yaml, vars/databases.yaml
demo_import_vs_include.yaml     # demostración de las diferencias de la tabla
uninstall.yaml                  # deshace el despliegue de main.yaml
mi-inventario, ansible.cfg      # inventario y configuración (roles_path = ./roles)
```

### Dónde se usa cada mecanismo

| Mecanismo | Dónde | Por qué |
|---|---|---|
| `import_playbook` | `main.yaml` | Encadena playbooks completos, cada uno con sus `hosts` y variables |
| `import_tasks` | `webservers.yaml` (firewall) y `databases.yaml` (repositorio) | Ficheros fijos, siempre se ejecutan |
| `include_tasks` | `databases.yaml` (firewall) | Mismo fichero que en web, pero cargado dinámicamente con otros puertos |
| `import_role` | `webservers.yaml` (rol `motd`) | El rol se resuelve al leer el playbook |
| `include_role` | `databases.yaml` (rol `motd`) | El rol se resuelve al ejecutar la tarea |

`tasks/firewall.yaml` se usa **dos veces** con distintas variables (`firewall_ports`): ese es el
beneficio de reutilizar un fichero de tareas.

Los playbooks de `tasks/` buscan los roles en `roles/` gracias a `roles_path = ./roles` en
`ansible.cfg` (por defecto buscarían en `tasks/roles/`). Las rutas de las plantillas y de las
variables (`../templates/...`, `../vars/...`) son relativas al fichero que las usa.

## Cómo probarlo

```bash
# Despliegue completo (web + base de datos)
ansible-playbook main.yaml
ansible-playbook main.yaml              # 2ª vez: no debe cambiar nada

# Diferencias entre import e include
ansible-playbook demo_import_vs_include.yaml                 # mira qué tareas salen "skipping"
ansible-playbook demo_import_vs_include.yaml -e ejecutar=true
ansible-playbook demo_import_vs_include.yaml --list-tasks    # import_tasks se ve; include_tasks no

# Limpiar
ansible-playbook uninstall.yaml
```

### Qué verás en la demostración

Con `ejecutar: false` (el valor por defecto):

| Tarea | Resultado | Por qué |
|---|---|---|
| 1. `import_tasks` + `when` | **2 tareas** «skipping» (las del fichero) | El `when` se copia a cada tarea importada |
| 2. `include_tasks` + `when` | **1 tarea** «skipping» | El `when` se evalúa en la propia tarea `include`; el fichero ni se lee |
| 3. `include_tasks` + `loop` | El fichero se procesa **3 veces** (uno, dos, tres) | Solo `include` admite `loop` |
| 4. `include_tasks` con nombre variable | Se procesa `tasks/demo_item.yaml` | El nombre se calcula al ejecutar |

Con `--list-tasks` aparecen las dos tareas del fichero importado (la 1) y solo las tareas
`include` (2, 3 y 4), porque el contenido de un `include` no se conoce hasta ejecutarlo.

## Notas

- **Un mensaje del día por play.** En esta máquina de pruebas los grupos `webservers` y
  `databases` apuntan al **mismo host**. Si los dos plays escribieran el mismo `/etc/motd`, cada
  ejecución lo reescribiría dos veces y el playbook nunca sería idempotente. Por eso el rol recibe
  la variable `motd_file` y cada play usa un fichero distinto. Con hosts distintos bastaría el
  `/etc/motd` por defecto.
- **Cerrar el firewall.** El orden importa: `firewall.yaml` abre los puertos y **después**
  habilita UFW, para no perder el acceso SSH. En `uninstall.yaml` el puerto 22 se cierra el último
  y con UFW ya deshabilitado.
- **`apt update` solo si hace falta.** `mariadb_repo.yaml` registra el resultado de la tarea del
  repositorio y actualiza la caché de `apt` únicamente si ese repositorio ha cambiado; así la
  segunda ejecución no marca cambios.
- Los ficheros `inventory` e `inventory-dns` son los originales del curso (IPs y nombres de
  otras máquinas). Los playbooks se ejecutan con `mi-inventario`.

## Requisitos

- Ubuntu 26.04 como destino, con acceso SSH como `root` (según `ansible.cfg`).
- Colecciones `community.general` (módulo `ufw`) y `ansible.mariadb` (usuarios y bases de datos).
