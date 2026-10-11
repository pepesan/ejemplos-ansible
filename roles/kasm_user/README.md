# kasm_user

Creates or deletes a Kasm application user (e.g. `user@kasm.local`) via
`kasm_user_state: present|absent` — **not** the Linux `alumno` user (see
[`student`](../student/README.md)), a Kasm account inside the application
itself.

Unlike [`kasm_workspace`](../kasm_workspace/README.md) and
[`kasm_group`](../kasm_group/README.md), Kasm's public API
fully covers user management (`create_user`, `get_users`, `delete_user`), so
this role is pure `ansible.builtin.uri` — no direct Postgres access, no
wrapped bash script. It's the first Kasm role in this collection with zero
SQL.

## Requires an existing API key

Reuses the persistent, ansible-managed API key bootstrapped by
[`kasm_workspace`](../kasm_workspace/README.md) (`{{ kasm_dir }}/.kasm_api_key.json`)
rather than minting its own. Run `kasm_workspace` at least once first, or
create a key manually and grant it the **Users Create**, **Users Delete**
and **Users View** permissions (the key `kasm_workspace` creates is only
granted permissions for images/sessions — extending it for user management
is a manual one-time step until that permission bootstrap is unified across
roles).

## Idempotency

Checks `get_users` first; `create_user` only runs if no user with that
username exists yet, `delete_user` only runs if one does.

## Variables

| Variable | Default | Purpose |
|---|---|---|
| `kasm_user_username` | — (required) | e.g. `user@kasm.local` |
| `kasm_user_state` | `present` | `present` creates if missing; `absent` deletes if present |
| `kasm_user_password` | `""` | Required in practice for `present` |
| `kasm_user_first_name` / `_last_name` / `_organization` / `_phone` | `""` | Optional profile fields |
| `kasm_user_locked` / `_disabled` | `false` | Account flags |
| `kasm_url` | `https://127.0.0.1:443` | Kasm base URL |
| `kasm_user_api_key_file` | `{{ kasm_dir }}/.kasm_api_key.json` | Where to read the API key from |

## Example

```yaml
- hosts: ubuntu
  roles:
    - role: kasm_user
      vars:
        kasm_user_username: "user@kasm.local"
        kasm_user_password: "{{ kasm_user_password_generated }}"
```
