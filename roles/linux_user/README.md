# linux_user

Generic, reusable role: creates a Linux user with a random password
persisted on the control node, and ensures its own group plus any extra
groups (e.g. `docker`, `sudo`) exist first — so it works even if nothing
else created those groups yet.

Not specific to this project or to Kasm at all. [`student`](../student/README.md)
is a thin wrapper around this role that just fixes the username to `alumno`
and its default groups.

## Idempotency note

`password_hash()` generates a random salt on every call unless one is given
explicitly — without a fixed salt, the computed hash (and therefore the
user task) would show as "changed" on every single run, even when the
password itself never changed. This role persists the salt the same way as
the password itself (`linux_user_password_salt`, read via the same
`lookup('password', ...)` pattern), so re-runs are genuinely idempotent.

## Variables

| Variable | Default | Purpose |
|---|---|---|
| `linux_user_name` | — (required) | Username and primary group name |
| `linux_user_shell` | `/bin/bash` | Login shell |
| `linux_user_extra_groups` | `[]` | Supplementary groups, created first if missing |
| `linux_user_credentials_dir` | `{{ playbook_dir }}/.credenciales` | Where the password and salt files live |
| `linux_user_password_plain` | random, persisted | Override with `-e` to set a fixed password |
| `linux_user_password_salt` | random, persisted | Rarely overridden directly |

## Example

```yaml
- hosts: ubuntu
  roles:
    - role: linux_user
      vars:
        linux_user_name: "ci-runner"
        linux_user_extra_groups: [docker]
```
