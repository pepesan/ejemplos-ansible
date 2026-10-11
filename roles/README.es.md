# roles/

Roles de Ansible reutilizables y componibles que cubren lo mismo que los
playbooks monolíticos de `31_vault` (`01`, `02`, `25`, `23`, `24`):
aprovisionar un servidor de Kasm Workspaces de principio a fin. `31_vault`
no se toca y sigue funcionando; migrar a estos roles es aparte y opcional.

Ver [`PLAN.md`](PLAN.md) para el historial de diseño y las decisiones
abiertas, y el `README.md` (inglés, canónico) / `README.es.md` (español) de
cada rol para la referencia completa de variables.

## Roles

| Rol | Depende de | Qué hace |
|---|---|---|
| [`docker`](docker/README.es.md) | `geerlingguy.docker` (Galaxy) | Módulos de kernel + sysctl que la red de contenedores de Kasm necesita, sobre un rol de instalación de Docker ya mantenido |
| [`linux_user`](linux_user/README.es.md) | — | Genérico: crea un usuario Linux con password aleatoria persistida, asegurando antes que sus grupos existen |
| [`student`](student/README.es.md) | `linux_user` | Wrapper fino: fija el username a `alumno` y sus grupos por defecto (`docker`+`sudo`) |
| [`kasm`](kasm/README.es.md) | `geerlingguy.swap`, `geerlingguy.certbot` (Galaxy) | Instala Kasm Workspaces (sin workspace registrado todavía): compose, fix-e-instalación, modo de pruning de imágenes, bloqueo de impresión en nginx y, por defecto, TLS real con Let's Encrypt |
| [`kasm_credentials`](kasm_credentials/README.es.md) | — | Passwords aleatorias de admin/user de Kasm + el CSV de accesos (`datos-acceso-<proyecto>-<fecha>.csv`) |
| [`kasm_group`](kasm_group/README.es.md) | — | Keepalive de sesión + bastionado por grupo (portapapeles/descargas/subidas/impresión), idempotente, parametrizado por grupo |
| [`kasm_docker_image`](kasm_docker_image/README.es.md) | — | Pull/borrado de la imagen Docker dentro del DinD de Kasm, independiente del registro del workspace |
| [`kasm_workspace`](kasm_workspace/README.es.md) | — | Da de alta/baja un workspace (la fila en la tabla `images`), `state: present\|absent` |
| [`kasm_user`](kasm_user/README.es.md) | — | Crea/borra un usuario de la aplicación Kasm, API pública pura (`ansible.builtin.uri`, sin SQL) |
| [`kasm_uninstall`](kasm_uninstall/README.es.md) | — | Desinstala Kasm de forma limpia (contenedor + datos persistidos, opcionalmente su cert de Let's Encrypt) para una reinstalación realmente nueva |

`docker`, `linux_user` y `student` son genéricos (nombre simple, estilo
Galaxy, como `geerlingguy.*`); el resto son específicos de Kasm y mantienen
el prefijo `kasm_`. `kasm_image` no existe a propósito: se renombró a
`kasm_docker_image` para evitar el choque con la propia terminología de
Kasm, donde "image" significa lo que esta colección llama *workspace*
(`kasm_workspace`) — ver más abajo.

## Por qué estas dependencias de Galaxy y no roles reimplementados

`geerlingguy.docker`, `geerlingguy.swap` y `geerlingguy.certbot` son roles
activamente mantenidos y muy usados que ya resuelven la instalación de
Docker, la gestión de swapfile y certbot/Let's Encrypt — reimplementarlos
sería pura duplicación. Las versiones están fijadas en
[`requirements.yml`](requirements.yml); instalar con:

```bash
ansible-galaxy role install -r roles/requirements.yml
```

También se valoró un rol de Galaxy para el propio Kasm
(`monolithprojects.kasm_server`) y se descartó: sin mantenimiento desde
2021, y aun así solo cubría una instalación básica, sin nada de lo que
cubren `kasm`, `kasm_credentials`, `kasm_workspace`, `kasm_group`,
`kasm_docker_image` o `kasm_user`.

## API pública de Kasm vs. SQL directo

La API pública de desarrollador de Kasm (`api_key`/`api_key_secret`) es más
completa de lo que parecía al principio, pero sigue teniendo huecos reales.
Dónde queda cada rol:

| Rol | Cómo habla con Kasm |
|---|---|
| `kasm_user` | 100% API pública (`create_user`/`get_users`/`delete_user`) — nada de SQL |
| `kasm_workspace` | Mayormente API ya (`create_image`, `get_images` para la comprobación de existencia); sigue con SQL directo para borrar un workspace (no hay `delete_image` público) y para la resolución de zona del Session Staging (no hay `get_zones` público) |
| `kasm_group` | SQL directo — `group_settings` no tiene endpoint público que funcione |
| `kasm_docker_image` | `docker exec` puro — esto es gestión de la imagen Docker dentro del DinD de Kasm, no un asunto de la API de Kasm en absoluto |

**Pendiente conocido**: el Session Staging **sí** tiene API pública
(`create_staging_config`/`update_staging_config`), todavía no adoptada en
`kasm_workspace` porque no se ha verificado el payload exacto de la petición
contra una instancia real — ver el plan de la sesión referenciado en
`PLAN.md` antes de intentarlo, para no dejar el staging mal configurado en
silencio.

## Orden de composición

```
docker ─────────────────┐
linux_user ──> student ──┼──> kasm ──> kasm_credentials
                         │      │
                         │      └────> kasm_group
                         │
                         └──────────> kasm_docker_image ──> kasm_workspace ──> kasm_user
```

`kasm_credentials` debe ejecutarse antes (o junto a) `kasm`, ya que `kasm`
consume `kasm_admin_password`/`kasm_user_password`. `kasm_docker_image` debe
ejecutarse antes que `kasm_workspace` para un workspace dado (la imagen
debe existir en el DinD antes de poder registrarse). `kasm_user` solo
necesita que `kasm_workspace` se haya ejecutado una vez en el host, para
que exista la API key persistente que reutiliza.

Ver [`examples/`](examples/) para scripts ejecutables que cubren la
secuencia completa, un dominio personalizado, un despliegue local sin TLS,
y el alta/baja de workspace.

## Pruebas

`ansible-lint` pasa en perfil `production` para todos los roles de esta
carpeta. Todos los roles tienen un escenario Molecule `molecule/default/`:
- `linux_user`, `student` y `kasm_credentials` ejecutan `molecule test` de
  verdad (converge + idempotence + verify) en un contenedor Docker
  desechable.
- `docker` y `kasm` tocan sysctl/módulos de kernel del host — ejecutarlos
  dentro de un contenedor Molecule modificaría el **kernel real de la
  máquina que corra el test** (los contenedores comparten kernel con el
  host), así que sus escenarios existen solo para lint/estructura.
- `kasm_group`, `kasm_docker_image`, `kasm_workspace` y `kasm_user`
  necesitan todos una instancia de Kasm real ya instalada (Postgres, API)
  que un contenedor genérico no tiene — sus escenarios también son solo
  lint/estructura.

La verificación real end-to-end de los roles de arriba ocurre contra VMs
reales — ver las Fases A/B de pruebas de la sesión.
