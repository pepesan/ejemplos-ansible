# 10 · Bucles

Un bucle repite una tarea para cada elemento de una lista. En Ansible se usa **`loop`** (la forma
recomendada hoy) y, en playbooks antiguos, las variantes `with_*`.

## Ficheros

| Fichero | Para qué sirve |
|---------|----------------|
| `main-simple.yaml` | Bucles básicos: `loop`, `with_list` (estilo antiguo), lista de diccionarios y `dict2items`. |
| `main-avanzado.yaml` | `loop_control`, `index_var`, `when` en un bucle, bucles anidados, `subelements`, `zip` y `register` en un bucle. |
| `main.yaml` | Reintentos con `until` / `retries` / `delay`, que son un bucle de una sola tarea. |
| `scripts/miscript.sh` | Script de apoyo para los reintentos: cuenta cuántas veces se ejecuta. |
| `mi-inventario`, `ansible.cfg` | Inventario y configuración usados por los playbooks. |

## `loop` y su equivalente antiguo

| Antes | Ahora |
|-------|-------|
| `with_list: [a, b]` / `with_items: [a, b]` | `loop: [a, b]` |
| `with_dict: "{{ d }}"` | `loop: "{{ d \| dict2items }}"` |
| `with_nested: [[a, b], [1, 2]]` | `loop: "{{ ['a','b'] \| product([1,2]) \| list }}"` |
| `with_subelements: [...]` | `loop: "{{ lista \| subelements('clave') }}"` |
| `with_together: [[a, b], [1, 2]]` | `loop: "{{ ['a','b'] \| zip([1,2]) \| list }}"` |

En cada vuelta el elemento actual está en la variable **`item`**.

## `main-simple.yaml`

Cuatro tareas, todas de solo lectura (`debug`):

1. **`loop` sobre una lista**: muestra `one` y `two`.
2. **`with_list`**: el mismo resultado con la sintaxis antigua.
3. **Lista de diccionarios**: cada elemento tiene sus claves (`item.nombre`, `item.dato`).
4. **`dict2items`**: convierte un diccionario en una lista de pares `key` / `value`.

> Un error habitual en listas de objetos: escribir `- one:` y `dato:` al mismo nivel crea **un solo**
> diccionario con las claves `one` (nula) y `dato`. Cada clave de un elemento debe ir alineada con
> las demás, no con la primera.

## `main-avanzado.yaml`

Trabaja en `/tmp/ejemplo-bucles` y lo borra al final, así que se puede repetir sin cambios.

| # | Qué enseña | Detalle |
|---|------------|---------|
| 1 | `loop` sobre una lista | Crea tres directorios |
| 2 | Lista de diccionarios + `loop_control: label` | Crea ficheros; `label` evita volcar todo el diccionario en la salida |
| 3 | `when` dentro de un bucle | Se evalúa **por elemento**: `tres.log` sale «skipping» |
| 4 | `index_var` | Número de vuelta, empezando en 0 |
| 5 | Bucle anidado | `product` genera todas las combinaciones (`x-1`, `x-2`, `y-1`, `y-2`) |
| 6 | `subelements` | Recorre las aficiones de cada usuario |
| 7 | `zip` | Recorre dos listas a la vez |
| 8 / 8b | `register` en un bucle | El resultado es una lista en `contenidos.results`; cada entrada guarda su `item` y su salida |
| 9 | Limpieza | Borra el directorio de trabajo |

## `main.yaml` · reintentos

`until` repite **una** tarea hasta que se cumple una condición (hasta `retries` veces, esperando
`delay` segundos). El script cuenta las veces que se ejecuta y solo imprime `Loaded 3 times` a la
tercera:

```yaml
- name: Retry a task until a certain condition is met
  ansible.builtin.command: "{{ script_path }} {{ count_file }}"
  register: result
  until: result.stdout.find("Loaded 3 times") != -1
  retries: 5
  delay: 1
```

La salida muestra dos líneas `FAILED - RETRYING ... (4 retries left)` y `(3 retries left)`, y
después `result.attempts` vale 3. La tarea siguiente lo imprime.

El playbook borra el contador al empezar y los ficheros al terminar, por eso se puede ejecutar
varias veces con el mismo resultado. El `command` se marca como cambiado a propósito
(`changed_when: true`) porque ejecuta algo con efectos.

## Cómo probarlo

```bash
ansible-playbook main-simple.yaml
ansible-playbook main-avanzado.yaml
ansible-playbook main.yaml
```

## Requisitos

- Ubuntu 26.04 como destino, con acceso SSH como `root` (según `ansible.cfg`).
- Los playbooks solo escriben en `/tmp` del destino y no instalan nada.
- Los ficheros `inventory` e `inventory-dns` son los originales del curso; los playbooks usan
  `mi-inventario`.
