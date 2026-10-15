# kasm_session

Arranca (o destruye) una **sesión en ejecución** de un workspace de Kasm ya
registrado para un usuario concreto, mediante la API pública de Kasm. Es la
pieza que faltaba junto a [`kasm_workspace`](../kasm_workspace/README.es.md)
(registra el workspace) y [`kasm_user`](../kasm_user/README.es.md) (crea el
usuario): este rol hace que un usuario *tenga una sesión*.

Solo `ansible.builtin.uri` contra `get_users`, `get_images`, `get_kasms`,
`request_kasm`, `get_kasm_status` y `destroy_kasm` — sin acceso directo a
Postgres, igual que `kasm_user`. Se autentica con la API key persistente que
crea `kasm_workspace` en el host (`/opt/kasm/.kasm_api_key.json`), así que
antes debe haberse registrado al menos un workspace en ese host.

## Variables

| Variable | Valor por defecto | Propósito |
|---|---|---|
| `kasm_session_state` | `present` | `present`: asegura que el usuario tiene una sesión en ejecución (la lanza si falta y espera a `running`). `absent`: la destruye |
| `kasm_session_user` | `user@kasm.local` | Usuario de Kasm dueño de la sesión. Debe existir ya |
| `kasm_session_workspace` | `""` (obligatoria) | Un workspace ya registrado, por el `name` de su imagen (`pepesan/mi-ubuntu-resolute-kasm-python-dind:1.3`) o por su `friendly_name` (`Python Docker (Ubuntu 26.04)`) |
| `kasm_session_timeout_seconds` | `600` | Cuánto esperar a `running` (el arranque en frío de una imagen grande puede tardar minutos) |
| `kasm_session_poll_seconds` | `5` | Intervalo de sondeo mientras espera |
| `kasm_session_api_key_file` | `{{ kasm_dir }}/.kasm_api_key.json` | API key persistente creada por `kasm_workspace` |

## Hechos exportados (estado `present`)

| Hecho | Contenido |
|---|---|
| `kasm_session_id` | El `kasm_id` de la sesión |
| `kasm_session_container_id` | Su id de contenedor dentro del DinD de Kasm (`docker exec kasm docker exec <id> …`) |
| `kasm_session_status` | `operational_status` (`running`) |

## Comportamiento a tener en cuenta

- **Idempotente**: si el usuario ya tiene una sesión de ese workspace no se
  lanza otra (`changed=false`); `absent` no hace nada si no hay sesión.
- **Los endpoints devuelven los UUID en formatos distintos**: `get_users` con
  guiones, `get_images`/`get_kasms` sin ellos. El rol compara en minúsculas y
  sin guiones y envía la forma canónica con guiones. Una primera versión los
  comparaba tal cual, no encontraba la sesión existente e intentaba lanzar una
  segunda (`request_kasm` la rechazó, así que sin daños, pero solo se detectó
  probándolo).
- **Una sesión arrancada por automatización no tiene cliente conectado**, así
  que Kasm la *pausará* tras `keepalive_expiration` segundos (ver
  [`kasm_group`](../kasm_group/README.es.md): 3600 s y acción `pause` por
  defecto). Lo que corra dentro (p. ej. un laboratorio docker compose) queda
  congelado, no perdido, y se reanuda cuando un usuario se conecta.
- La respuesta de `request_kasm` incluye un token de sesión: esas tareas van
  con `no_log`.
- Una sesión reserva los cores y la memoria del workspace mientras exista;
  conviene vigilar la capacidad del host antes de lanzar varias.

## Nombres con espacios

Pásalos como JSON; con `-e clave="a b"` el valor se corta en el primer
espacio:

```bash
ansible-playbook -i <inventario> kasm-session.yml \
  -e '{"kasm_session_workspace": "Python Docker (Ubuntu 26.04)"}'
```

## Ejemplo

```yaml
- hosts: ubuntu
  roles:
    - role: kasm_session
      vars:
        kasm_session_user: user@kasm.local
        kasm_session_workspace: "Python Docker (Ubuntu 26.04)"
```

Ver [`../examples/kasm-session.yml`](../examples/kasm-session.yml).
