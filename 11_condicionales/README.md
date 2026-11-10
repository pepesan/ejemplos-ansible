# 11 · Condicionales

`when` ejecuta una tarea **solo si** se cumple una condición. Las tareas que no la cumplen salen
como `skipping`. La condición es una expresión Jinja2 **sin llaves** (`{{ }}` no hace falta).

## Ficheros

| Fichero | Para qué sirve |
|---------|----------------|
| `main.yaml` | Condicional básico en `localhost`: no toca ningún servidor. |
| `main-multidistro.yaml` | 15 ejemplos de condicionales, pensados para ejecutarse en **Ubuntu y Rocky a la vez**: cada tarea salta en una de las dos o en ninguna. |
| `mi-inventario`, `ansible.cfg` | Grupos `ubuntu`, `rocky` y `todas` (los dos). |

## Cómo probarlo

```bash
ansible-playbook main.yaml
ansible-playbook main-multidistro.yaml
ansible-playbook main-multidistro.yaml -e mi_variable=hola    # activa la tarea 7, salta la 8
ansible-playbook main-multidistro.yaml -e forzar_error=true   # la tarea 11a falla y entra en rescue
```

## Los 15 ejemplos de `main-multidistro.yaml`

| # | Qué enseña | Ejemplo | Ubuntu | Rocky |
|---|------------|---------|:------:|:-----:|
| 1 | Condición simple | `ansible_facts['os_family'] == 'Debian'` | ✔ | salta |
| 2 | Otra familia | `... == 'RedHat'` | salta | ✔ |
| 3 | **and** (lista de condiciones) | Debian **y** versión mayor `>= 24` | ✔ | salta |
| 4 | **or** | `distribution == 'Ubuntu' or ... == 'Rocky'` | ✔ | ✔ |
| 5 | **in** (pertenencia) | `distribution in ['Ubuntu', 'Debian', ...]` | ✔ | ✔ |
| 6 | Test `version` | `kernel is version('6.0', '<')` | salta | salta |
| 7 | `is defined` | solo si se pasó `-e mi_variable=...` | salta* | salta* |
| 8 | `is not defined` | el caso contrario | ✔* | ✔* |
| 9 | Diccionario indexado por la familia | `paquetes_ssh[ansible_facts['os_family']]` | ✔ | ✔ |
| 10 | `when` dentro de un **loop** | `when: item < 1024` filtra elementos | 3 de 4 | 3 de 4 |
| 11 | `block` / `rescue` / `always` | el bloque entero lleva `when` (solo Debian) | ✔ | salta |
| 12 / 12b | Condición sobre un **resultado registrado** | `resultado.rc == 0`, con `failed_when` | ✔ | ✔ |
| 13 / 13b | `changed_when` y `when: tarea is changed` | solo actúa si la tarea anterior cambió algo | ✔ | ✔ |
| 14 | `assert` | detiene el play si no se cumple | ✔ | ✔ |
| 15 | Limpieza | borra la marca de la tarea 13 | ✔ | ✔ |

\* Sin `-e mi_variable=...`. Con la variable pasa lo contrario: la 7 se ejecuta y la 8 salta.

### Cosas que conviene fijarse

- **Lista de condiciones = `and`.** En la tarea 3, las dos líneas bajo `when:` deben cumplirse a la vez.
- **`when` con `loop` se evalúa por elemento** (tarea 10): con `puertos: [22, 80, 443, 3306]`, solo
  22, 80 y 443 pasan el filtro `item < 1024` y 3306 sale como `skipping`.
- **`block` con `when`** (tarea 11): la condición se aplica al bloque completo. Con
  `-e forzar_error=true`, la tarea 11a falla (`/bin/false`), Ansible ejecuta `rescue` (11b) y
  después `always` (11c). El play sigue y termina sin error en esa máquina, porque el fallo se
  ha **recuperado**: en el resumen aparece como `rescued=1`.
- **`failed_when`** (tarea 12) redefine qué cuenta como fallo: aquí un código de salida 1 de `grep`
  («no encontrado») no se considera error, solo si es otro.
- **`changed_when`** (tarea 13) hace que un `shell` informe de si realmente cambió algo; la 13b
  usa `marca is changed` para actuar solo en ese caso. Como la tarea 15 borra la marca, la 13
  vuelve a marcar `changed` en cada ejecución.
- **Versiones**: nunca compares versiones como texto (`'10' < '9'` es cierto). Usa
  `| int` para números enteros o el test `is version(...)`.
- **Los facts** se escriben como `ansible_facts['clave']`; las variables sueltas `ansible_os_family`
  están en desuso.

## `main.yaml`

Se ejecuta en el propio equipo (`connection: local`) y usa `when` con
`ansible_facts['os_family'] == "Debian"`. Escribe y borra `/tmp/condicionales-fichero.txt`, y el
`debug` con `verbosity: 2` solo muestra el resultado si ejecutas con `-vv`.

## Requisitos

- Para `main-multidistro.yaml`: Ubuntu 26.04 (acceso SSH como `root`, según `ansible.cfg`) y
  Rocky 10 (acceso como `alumno` con `sudo`, indicado en `mi-inventario`). Los playbooks solo
  escriben en `/tmp`.
- `main.yaml` no necesita ninguna máquina.
