# kasm_session

Starts (or destroys) a **running session** of an already registered Kasm
workspace for a given user, through Kasm's public API. It is the missing
counterpart of [`kasm_workspace`](../kasm_workspace/README.md) (registers the
workspace) and [`kasm_user`](../kasm_user/README.md) (creates the user): this
one makes a user *have a session*.

Pure `ansible.builtin.uri` against `get_users`, `get_images`, `get_kasms`,
`request_kasm`, `get_kasm_status` and `destroy_kasm` — no direct Postgres
access, same approach as `kasm_user`. It authenticates with the persistent API
key `kasm_workspace` creates on the host (`/opt/kasm/.kasm_api_key.json`), so
at least one workspace must have been registered on that host first.

## Variables

| Variable | Default | Purpose |
|---|---|---|
| `kasm_session_state` | `present` | `present`: make sure the user has one running session (launch it if missing, wait until `running`). `absent`: destroy it |
| `kasm_session_user` | `user@kasm.local` | Kasm username owning the session. Must already exist |
| `kasm_session_workspace` | `""` (required) | An already registered workspace, by its image `name` (`pepesan/mi-ubuntu-resolute-kasm-python-dind:1.3`) or `friendly_name` (`Python Docker (Ubuntu 26.04)`) |
| `kasm_session_timeout_seconds` | `600` | How long to wait for `running` (a cold start of a large image can take minutes) |
| `kasm_session_poll_seconds` | `5` | Polling interval while waiting |
| `kasm_session_api_key_file` | `{{ kasm_dir }}/.kasm_api_key.json` | Persistent API key bootstrapped by `kasm_workspace` |

## Facts exported (state `present`)

| Fact | Content |
|---|---|
| `kasm_session_id` | The session's `kasm_id` |
| `kasm_session_container_id` | Its container id inside Kasm's DinD (`docker exec kasm docker exec <id> …`) |
| `kasm_session_status` | `operational_status` (`running`) |

## Behaviour worth knowing

- **Idempotent**: if the user already has a session of that workspace, nothing
  is launched (`changed=false`); `absent` is a no-op when there is none.
- **ID formats differ between endpoints**: `get_users` returns UUIDs with
  dashes, `get_images`/`get_kasms` without. The role compares on the dashless
  lowercase form and sends the canonical dashed form. A first version compared
  them raw, never found the existing session and tried to launch a second one
  (`request_kasm` refused, so no harm, but it was caught only by testing).
- **A session started by automation has no client attached**, so Kasm will
  *pause* it after `keepalive_expiration` seconds (see
  [`kasm_group`](../kasm_group/README.md): 3600 s and action `pause` by
  default). Anything running inside (e.g. a docker compose lab) is frozen, not
  lost, and resumes when a user connects.
- The `request_kasm` response carries a session token: those tasks are
  `no_log`.
- One session reserves the workspace's cores and memory for as long as it
  exists; mind the host's capacity before launching several.

## Names with spaces

Pass them as JSON, otherwise `-e key="a b"` is cut at the first space:

```bash
ansible-playbook -i <inventory> kasm-session.yml \
  -e '{"kasm_session_workspace": "Python Docker (Ubuntu 26.04)"}'
```

## Example

```yaml
- hosts: ubuntu
  roles:
    - role: kasm_session
      vars:
        kasm_session_user: user@kasm.local
        kasm_session_workspace: "Python Docker (Ubuntu 26.04)"
```

See [`../examples/kasm-session.yml`](../examples/kasm-session.yml).
