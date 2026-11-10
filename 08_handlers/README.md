# 08 · Handlers

Un **handler** es una tarea que solo se ejecuta cuando otra tarea la avisa con `notify` **y esa
tarea ha cambiado algo** (`changed`). Se usan para acciones costosas o con efectos visibles
(recargar o reiniciar un servicio) que solo hacen falta si la configuración ha cambiado de verdad.

## Las reglas que enseñan estos ejemplos

| # | Regla | Dónde se ve |
|---|-------|-------------|
| 1 | Si la tarea no cambia nada, el handler **no** se ejecuta. | 2ª ejecución de `tasks.yaml` / `tasks_mariadb.yaml` |
| 2 | Cada handler se ejecuta **una sola vez** por host, al **final del play**, aunque lo avisen varias tareas. | Las dos tareas de configuración avisan al mismo tema |
| 3 | Se ejecutan en el orden en que están **definidos** en `handlers:`, no en el orden de aviso. | Primero «Validate», luego «Reload/Restart» |
| 4 | `listen` hace que varios handlers respondan al mismo aviso (un «tema»). | `notify: nginx config changed` lanza tres handlers |
| 5 | `meta: flush_handlers` los ejecuta **en ese punto**, sin esperar al final del play. | La comprobación posterior ve ya la configuración nueva |
| 6 | Si una tarea posterior **falla**, los handlers pendientes se pierden, salvo con `force_handlers: true`. | `tasks_force_handlers.yaml` |

## Ficheros

| Fichero | Para qué sirve |
|---------|----------------|
| `tasks.yaml` | Ejemplo con **nginx** (reglas 1–5). Hosts: grupo `webservers`. |
| `tasks_mariadb.yaml` | El mismo ejemplo con **MariaDB 13.0**, para entornos donde no se puede usar nginx. Hosts: grupo `ubuntu`. |
| `tasks_force_handlers.yaml` | Qué pasa con un handler ya avisado si una tarea posterior falla (regla 6). |
| `tasks_uninstall.yaml` | Deshace el ejemplo de nginx. |
| `tasks_mariadb_uninstall.yaml` | Deshace el ejemplo de MariaDB (paquetes, configuración, datos y repositorio). |
| `vars.yaml` | Variables de los ejemplos: puerto y *keepalive* de nginx, y `max_connections` / log de consultas lentas de MariaDB. |
| `nginx-site.conf.j2`, `nginx-tuning.conf.j2`, `index.html.j2` | Plantillas del ejemplo de nginx. |
| `mariadb-conexiones.cnf.j2`, `mariadb-logs.cnf.j2` | Plantillas del ejemplo de MariaDB (dos ficheros de configuración). |
| `mi-inventario` | Inventario usado por `ansible.cfg` (grupos `ubuntu`, `webservers` y `rocky`). |

## Cómo está construido cada ejemplo

Dos tareas escriben dos ficheros de configuración distintos y **avisan al mismo tema**
(`notify: mariadb config changed`). Tres handlers escuchan ese tema con `listen`:

```yaml
handlers:
  - name: Validate mariadb config      # 1º: comprueba que la configuración es válida
    ansible.builtin.command: mariadbd --user=mysql --help --verbose
    listen: mariadb config changed
  - name: Restart mariadb              # 2º: aplica la configuración
    ansible.builtin.service: {name: mariadb, state: restarted}
    listen: mariadb config changed
  - name: Announce handlers ran        # 3º: deja constancia en la salida
    ansible.builtin.debug: {msg: "HANDLERS EJECUTADOS ..."}
    listen: mariadb config changed
```

Entre las tareas de configuración y la comprobación final hay un
`meta: flush_handlers`. Sin él, la comprobación (`select @@max_connections ...`) se haría
**antes** de que el handler reinicie MariaDB y leería todavía el valor antiguo.

## Cómo probarlo

Fíjate en las líneas `RUNNING HANDLER` de la salida de cada ejecución.

```bash
# --- MariaDB (tasks_mariadb.yaml) ---
ansible-playbook tasks_mariadb.yaml                                  # 1ª vez: todo cambia -> handlers, 1 vez
ansible-playbook tasks_mariadb.yaml                                  # 2ª vez: nada cambia -> NO hay handlers
ansible-playbook tasks_mariadb.yaml -e mariadb_max_connections=300   # cambia 1 fichero -> handlers, 1 vez
ansible-playbook tasks_mariadb.yaml -e mariadb_max_connections=300 \
                                    -e mariadb_slow_query_log=1      # cambia otro fichero -> handlers, 1 vez

# --- nginx (tasks.yaml) ---
ansible-playbook tasks.yaml
ansible-playbook tasks.yaml
ansible-playbook tasks.yaml -e nginx_keepalive=30
ansible-playbook tasks.yaml -e nginx_port=8081

# --- Una tarea falla después de avisar al handler ---
ansible-playbook tasks_force_handlers.yaml                           # el handler NO se ejecuta
ansible-playbook tasks_force_handlers.yaml -e force=true             # el handler SÍ se ejecuta

# --- Limpiar ---
ansible-playbook tasks_mariadb_uninstall.yaml
ansible-playbook tasks_uninstall.yaml
```

La clave está en **qué ejecución dispara handlers**:

| Ejecución | ¿Cambia algo? | Handlers |
|-----------|---------------|----------|
| 1ª vez | Sí, todos los ficheros | 1 vez (aunque cambien dos ficheros) |
| 2ª vez, sin tocar nada | No | Ninguno |
| Cambiando solo `mariadb_max_connections` | Un fichero | 1 vez |
| Cambiando además `mariadb_slow_query_log` | Otro fichero | 1 vez |

Con nginx pasa igual. Probado en una VM Ubuntu 26.04:

| Ejecución | Qué cambia | Resultado |
|-----------|------------|-----------|
| `tasks.yaml` (1ª vez) | Todos los ficheros | Handlers 1 vez; nginx responde en el 8080 con `keepalive_timeout 65` |
| `-e nginx_keepalive=30` | Solo el fichero de afinado | Handlers 1 vez; `keepalive_timeout 30` |
| `-e nginx_port=8081` | El fichero del sitio **y** el de afinado | Handlers 1 vez; responde en el 8081 y el 8080 ya no |

> **Los `-e` valen solo para su ejecución.** En la tercera fila, el `keepalive` vuelve a 65
> (el valor de `vars.yaml`) porque esa ejecución ya no lleva `-e nginx_keepalive=30`. Por eso
> cambian **dos** ficheros y no uno. Para conservar un valor hay que repetir el `-e` o
> cambiarlo en `vars.yaml`.

## Requisitos

- Inventario con la máquina de destino en `mi-inventario` (acceso por SSH como `root`, según
  `ansible.cfg`).
- Sobre Ubuntu 26.04. El ejemplo de MariaDB añade el repositorio oficial de MariaDB 13.0 con
  `deb822_repository`.
