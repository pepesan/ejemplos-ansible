# student

Creates the `alumno` (student) Linux user with `docker` and `sudo` group
membership. Thin wrapper around the generic [`linux_user`](../linux_user/README.md)
role — fixes the username and default groups, nothing else; see
`linux_user`'s README for the password/idempotency details.

## Variables

| Variable | Default | Purpose |
|---|---|---|
| `student_name` | `alumno` | Username/group created |
| `student_shell` | `/bin/bash` | Login shell |
| `student_extra_groups` | `[docker, sudo]` | Supplementary groups |
| `student_credentials_dir` | `{{ playbook_dir }}/.credenciales` | Where the generated password file lives |
| `student_password_plain` | random, persisted | Override with `-e` to set a fixed password |

The password file path (`<credentials_dir>/<inventory_hostname>-alumno.pass`)
is the same pattern [`kasm_credentials`](../kasm_credentials/README.md) uses
to read the same value when writing the access CSV — keep
`student_credentials_dir` consistent across roles if you change it.

## Example

```yaml
- hosts: ubuntu
  roles:
    - student
```
