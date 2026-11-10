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

# MariaDB dividida en ficheros (ver la sección «MariaDB en ficheros pequeños»)
mariadb.yaml                    # instalación: import_tasks, include_tasks con loop y handlers importados
mariadb_uninstall.yaml          # desinstalación, también dividida en ficheros
tasks/mariadb/install.yaml          # paquetes y servicio
tasks/mariadb/config_file.yaml      # UN fichero de configuración (se procesa una vez por elemento)
tasks/mariadb/verify.yaml           # flush_handlers + comprobación de la configuración real
tasks/mariadb/uninstall_packages.yaml, remove_file.yaml, uninstall_cleanup.yaml
handlers/mariadb.yaml           # los tres handlers (validar, reiniciar, anunciar)
templates/mariadb-conexiones.cnf.j2, templates/mariadb-logs.cnf.j2
vars/mariadb.yaml               # versión, paquetes, parámetros y lista de ficheros de configuración
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

## MariaDB en ficheros pequeños

`mariadb.yaml` y `mariadb_uninstall.yaml` son el ejemplo de instalar y desinstalar MariaDB del
ejemplo 08 (handlers), pero **troceado en ficheros** con `import_tasks` e `include_tasks`.

### Instalación (`mariadb.yaml`)

| Paso | Mecanismo | Fichero | Por qué así |
|------|-----------|---------|-------------|
| 1. Repositorio | `import_tasks` | `tasks/mariadb_repo.yaml` | Fichero fijo, y ya lo usa `tasks/databases.yaml`: se reutiliza |
| 2. Paquetes y servicio | `import_tasks` | `tasks/mariadb/install.yaml` | Fichero fijo, siempre se ejecuta |
| 3. Configuración | `include_tasks` + `loop` | `tasks/mariadb/config_file.yaml` | **El mismo fichero** se procesa una vez por cada elemento de `mariadb_config_files` |
| 4. Aplicar y comprobar | `import_tasks` | `tasks/mariadb/verify.yaml` | Fichero fijo, siempre igual: no hay nada que decidir al ejecutar. Lleva `meta: flush_handlers` |
| Handlers | `import_tasks` dentro de `handlers:` | `handlers/mariadb.yaml` | Los handlers también se pueden mover a su propio fichero |

El paso 3 es el que justifica un `include_tasks`: la lista de ficheros de configuración vive en
`vars/mariadb.yaml` y añadir uno nuevo es añadir una línea, sin tocar el playbook:

```yaml
mariadb_config_files:
  - { src: mariadb-conexiones.cnf.j2, dest: 99-handlers-conexiones.cnf }
  - { src: mariadb-logs.cnf.j2,       dest: 99-handlers-logs.cnf }
```

Cada vuelta avisa con `notify: mariadb config changed` y los tres handlers de
`handlers/mariadb.yaml` (validar, reiniciar y anunciar) escuchan ese tema con `listen`, así que
se ejecutan **una sola vez** aunque cambien varios ficheros.

### Desinstalación (`mariadb_uninstall.yaml`)

| Paso | Mecanismo | Fichero |
|------|-----------|---------|
| 1. Servicio y paquetes | `import_tasks` | `tasks/mariadb/uninstall_packages.yaml` |
| 2. Configuración, datos y clave | `include_tasks` + `loop` | `tasks/mariadb/remove_file.yaml` (una vez por ruta) |
| 3. AppArmor, repositorio y caché de `apt` | `import_tasks` | `tasks/mariadb/uninstall_cleanup.yaml` |

### Qué verás

| Ejecución | Handlers | Valor leído de MariaDB |
|-----------|----------|------------------------|
| `mariadb.yaml` (1ª vez) | Se ejecutan **una vez** | `max_connections` 100, log lento desactivado |
| `mariadb.yaml` (2ª vez) | Ninguno (`changed=0`) | igual |
| `... -e mariadb_max_connections=300` | Una vez | 300 |
| `... -e mariadb_max_connections=300 -e mariadb_slow_query_log=1` | Una vez | 300 y log lento activo |

Con `ansible-playbook mariadb.yaml --list-tasks` aparecen las tareas de los ficheros
**importados** (repositorio, paquetes, comprobación), pero de los ficheros **incluidos** solo se ve
la tarea «Paso 3 - ficheros de configuración»: su contenido no se conoce hasta ejecutarla.

### Cosas que conviene saber

- **`import_tasks` dentro de `handlers:`** es válido. En el playbook queda una sola línea
  (`- ansible.builtin.import_tasks: handlers/mariadb.yaml`).
- **`flush_handlers` funciona dentro de un fichero importado y de uno incluido.** Se comprobó con
  los dos: el handler se ejecuta en el punto del `flush`, antes de las tareas siguientes. El paso 4
  es un `import_tasks` por el criterio de siempre: el fichero es fijo.
- **No lo mezcles con `main.yaml`** sin desinstalar antes: `main.yaml` pone contraseña a `root`, y
  la comprobación final de `mariadb.yaml` entra como `root` por socket, sin contraseña.
- **`apt update` solo si hace falta.** Tanto `mariadb_repo.yaml` como `uninstall_cleanup.yaml`
  actualizan la caché solo cuando el repositorio ha cambiado, así que las segundas pasadas no
  marcan cambios.

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

# MariaDB dividida en ficheros (no mezclar con main.yaml sin desinstalar antes)
ansible-playbook mariadb.yaml
ansible-playbook mariadb.yaml                                   # 2ª vez: sin cambios ni handlers
ansible-playbook mariadb.yaml -e mariadb_max_connections=300    # cambia un fichero: handlers una vez
ansible-playbook mariadb.yaml --list-tasks                      # import se ve; el include, no

# Limpiar
ansible-playbook uninstall.yaml
ansible-playbook mariadb_uninstall.yaml
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
