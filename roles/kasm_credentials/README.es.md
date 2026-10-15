# kasm_credentials

Genera contraseñas aleatorias de admin/user de Kasm por host (persistidas en
el nodo de control para que ejecuciones repetidas las reutilicen) y registra
las credenciales de este host en un CSV compartido con el nombre del
inventario usado (`datos-acceso-<inventario>.csv`, p. ej. `-i inventory-mi-curso`
→ `datos-acceso-inventory-mi-curso.csv`), una fila por IP. Lo usa
[`kasm`](../kasm/README.es.md) y lee el mismo fichero de
contraseña de `alumno` que genera [`student`](../student/README.es.md),
para incluirla en la misma fila del CSV.

No cubierto por ningún rol o collection de Galaxy — es contabilidad
específica de Kasm sin equivalente upstream.

## Variables

| Variable | Valor por defecto | Propósito |
|---|---|---|
| `kasm_credentials_dir` | `{{ playbook_dir }}/.credenciales` | Dónde viven los ficheros de contraseña generados (mantener sincronizado con `student_credentials_dir`) |
| `kasm_admin_password` / `kasm_user_password` | aleatoria, persistida | Sobreescribir con `-e` para fijar contraseñas concretas |
| `kasm_credentials_admin_user` / `_user_user` | `admin@kasm.local` / `user@kasm.local` | Usuarios registrados en el CSV |
| `kasm_credentials_csv_name` | `datos-acceso-<nombre del fichero de inventario>.csv` | Nombre exacto del CSV, derivado del fichero de inventario de la ejecución (`inventory_file`). Sin fecha: todas las ejecuciones del mismo inventario caen en el mismo fichero y el nombre indica qué hosts contiene. Poner `""` para usar la fecha del día de ejecución (abajo). Debe ser un nombre `*.csv` simple; el script rechaza rutas |
| `kasm_proyecto_formativo` | `""` | Solo cuando `kasm_credentials_csv_name` es `""`: prefijo de curso opcional en `datos-acceso[-<proyecto>]-<fecha de ejecución>.csv`; un fichero nuevo cada día |
| `kasm_credentials_csv_dir` | `{{ playbook_dir }}` | Dónde se escribe el CSV |

Requiere que quien llame al rol fije `kasm_domain` (normalmente lo aporta
`kasm`).

## Idempotencia

`files/update_credentials_csv.py` compara la fila que va a escribir contra
lo que ya hay para la IP de este host; solo reescribe el fichero (e imprime
`CHANGED ...`) cuando algo difiere de verdad, imprimiendo
`OK ... already up to date` en caso contrario. El `changed_when` de la task
de Ansible lee esa marca, así que una segunda ejecución con las mismas
entradas no reporta cambios.

## Concurrencia

La actualización del CSV es segura para ejecuciones paralelas multi-host:
`files/update_credentials_csv.py` usa un `flock` bloqueante alrededor del
ciclo de lectura-modificación-escritura y escribe de forma atómica (fichero
temporal + `os.replace`), así que varios hosts concurrentes delegando en el
mismo nodo de control nunca corrompen el fichero ni pierden una fila.

## Ejemplo

```yaml
- hosts: ubuntu
  roles:
    - role: kasm_credentials
      vars:
        kasm_domain: "{{ node_name }}.example.com"
```
