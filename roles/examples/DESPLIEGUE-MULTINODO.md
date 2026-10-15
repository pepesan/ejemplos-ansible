# Despliegue de Kasm en varios nodos: lecciones y operativa

Notas de la primera instalación real de Kasm + workspace `python-dind` +
laboratorio docker compose 41 en 20 nodos a la vez (2026-10-15). Recoge lo que
funcionó, lo que falló, **por qué**, y cómo se resolvió, para no volver a
descubrirlo.

No contiene IPs ni contraseñas. El estado vivo de cada nodo no va aquí (ver
"Seguimiento").

## Secuencia por nodo

| # | Paso | Cómo | Verificación |
|---|---|---|---|
| 1 | Instalar Kasm (Docker, usuario `alumno`, Kasm, TLS, política de grupo) | `site-kasm.yml` | HTTPS 200 con certificado válido, 7 servicios `healthy` |
| 2 | Registrar el workspace | `kasm-workspace.yml` | `get_images` lo lista; la imagen está en el Docker interno |
| 3 | Arrancar sesión de `user@kasm.local` | `kasm-session.yml` | `get_kasms` → `running` |
| 4 | Lanzar el compose 41 dentro de la sesión | `launch_docker_twitch.sh 41` | 4 contenedores, Zeppelin 200, Adminer 200, Postgres OK |

Cada paso se verifica por separado: un `ok` de Ansible no basta (ver el
fallo del marcador, más abajo).

## Qué falló y por qué

### 1. Carrera de arranque de los plugins de Docker de Kasm

`install.sh` aborta con `dial unix .../kasmlogger.sock` o `.../kasmnetwork.sock:
connect: connection refused`: el plugin no responde en el instante en que
Docker lo habilita. Es una carrera de tiempo, no una avería.

- Con 19 instalaciones en paralelo (`-f 19`) falló en 5 de 16 nodos. Con
  `-f 4`, en 3 de 8. Con `-f 1`, en 1 de 3.
- Un nodo (`nodo07`) falló siete veces seguidas. Se descartaron CPU, disco
  (811 MB/s), DNS del proveedor, kernel, versiones y recursos; sigue sin causa
  de fondo identificada. Arreglar el DNS del host no cambió nada.
- **Recomendación: `-f` bajo (2 a 4) para instalaciones masivas.**

### 2. El script daba por buena una instalación abortada

`fix_and_install_kasm.sh` toleraba un `install.sh` con error y, con **cero
contenedores**, su bucle de espera veía "ninguno `unhealthy`, ninguno
`starting`" y declaraba "All services are healthy". Escribía el marcador
`kasm_install_complete` y el play seguía; fallaba varias tareas después
(`Read current image-pruning mode`, `No such container: kasm_db`). Las
reejecuciones decían `already installed. Skipping` y no reparaban nada.

Corregido en el rol `kasm`: éxito = `kasm_db`, `kasm_api` y `kasm_manager` en
marcha; si no, habilita los plugins desactivados y reintenta (3 intentos) y,
si sigue sin ir, sale con error sin marcador. Ver `roles/kasm/README.md`.

> Si un host quedó con marcador pero sin servicios: borrar
> `/opt/kasm/data/opt/kasm_install_complete` y reejecutar `site-kasm.yml`.

### 3. `kasm_uninstall` con `-e ...=true`

`-e kasm_uninstall_remove_letsencrypt_certs=true` llega como cadena y
`ansible-core` reciente rechaza condicionales no booleanos. Corregido con
`| bool`.

### 4. `--diff` sobre `/opt/kasm/data`

`--check --diff` con `state: absent` recorre los ~28 GB de ficheros para
calcular el diff y se cuelga. Usar solo `--check`.

### 5. Timeouts de SSH puntuales

Con 19 conexiones simultáneas, 3 nodos perdieron SSH en la misma tarea y
Ansible los sacó del play. El nodo queda sin instalar aunque responda minutos
después: repetir con `--limit`.

### 6. Descarga de imágenes que falla de forma transitoria

El `docker pull` de Zeppelin puede caer con `Client.Timeout exceeded` al pedir
el token a `auth.docker.io`. Es transitorio: relanzar
`launch_docker_twitch.sh 41` (compose es idempotente y reanuda).

## Cosas que parecen fallos y no lo son

- **Sesiones `paused`**: Kasm pausa una sesión tras `keepalive_expiration`
  (3600 s) sin cliente conectado (`kasm_group`, acción `pause`). Las sesiones
  arrancadas por automatización no tienen cliente, así que se pausan a la hora.
  El compose 41 queda congelado dentro y se reanuda al conectarse un usuario.
- **El 41 tarda ~20 minutos** en la primera ejecución: ~10 GB de imágenes
  (Zeppelin 7,2 GB, HUE 2,6 GB).
- **Reutilización de datos**: `kasm_uninstall` borra `/opt/kasm/data` (~28 GB
  con imágenes) y corta las sesiones activas. No toca Docker, usuarios ni
  certificados.

## Credenciales: nombre del CSV

`kasm_credentials` escribe `datos-acceso-<nombre del fichero de inventario>.csv`
en el directorio del playbook (sin fecha: todas las ejecuciones del mismo
inventario caen en el mismo fichero y el nombre dice qué hosts contiene). Las
contraseñas individuales viven en `.credenciales/`. Ambos están en `.gitignore`.
Con `-e kasm_credentials_csv_name=""` vuelve al nombrado por fecha de
ejecución.

## Seguimiento

El estado de cada nodo por fase se mantiene en `ESTADO-NODOS.md`, **ignorado
por git** (información operativa local). Convención: se actualiza tras cada
ejecución que toque nodos, con lo realmente comprobado.

Comprobaciones de solo lectura útiles:

```bash
ansible -i <inventario> ubuntu -m ansible.builtin.ping -f 20      # conectividad
ansible-playbook -i <inventario> kasm-session.yml --check ...     # sesiones
```

## Buenas prácticas que salieron de aquí

1. `-f` bajo en instalaciones masivas; reintentar solo los nodos fallidos con
   `--limit`.
2. Verificar cada fase de forma independiente (HTTPS, servicios, API, 41).
3. Redirigir siempre la salida de `ansible-playbook` a un log de ruta conocida.
4. No volcar `kasm_deploy.log` sin filtrar: contiene las contraseñas de admin y
   de usuario.
5. Probar antes de commitear; los inventarios con IPs reales no se versionan.
