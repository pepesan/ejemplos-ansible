# kasm_user

Crea o borra un usuario de la aplicación Kasm (ej. `user@kasm.local`) vía
`kasm_user_state: present|absent` — **no** el usuario Linux `alumno` (ver
[`student`](../student/README.es.md)), sino una cuenta de Kasm dentro de la
propia aplicación.

A diferencia de [`kasm_workspace`](../kasm_workspace/README.es.md) y
[`kasm_group`](../kasm_group/README.es.md), la API pública
de Kasm cubre completamente la gestión de usuarios (`create_user`,
`get_users`, `delete_user`), así que este rol es `ansible.builtin.uri` puro
— sin acceso directo a Postgres, sin script bash envuelto. Es el primer rol
de Kasm de esta colección sin nada de SQL.

## Requiere una API key existente

Reutiliza la API key persistente de gestión por Ansible que ya genera
[`kasm_workspace`](../kasm_workspace/README.es.md) (`{{ kasm_dir }}/.kasm_api_key.json`)
en vez de crear una propia. Ejecuta `kasm_workspace` al menos una vez antes,
o crea una key a mano y concédele los permisos **Users Create**, **Users
Delete** y **Users View** (la key que crea `kasm_workspace` solo tiene
permisos para imágenes/sesiones — ampliarla para gestión de usuarios es,
por ahora, un paso manual único hasta unificar el bootstrap de permisos
entre roles).

## Idempotencia

Comprueba primero con `get_users`; `create_user` solo se ejecuta si no
existe ya un usuario con ese username, `delete_user` solo si existe.

## Variables

| Variable | Valor por defecto | Propósito |
|---|---|---|
| `kasm_user_username` | — (obligatoria) | ej. `user@kasm.local` |
| `kasm_user_state` | `present` | `present` crea si falta; `absent` borra si existe |
| `kasm_user_password` | `""` | Requerida en la práctica para `present` |
| `kasm_user_first_name` / `_last_name` / `_organization` / `_phone` | `""` | Campos de perfil opcionales |
| `kasm_user_locked` / `_disabled` | `false` | Flags de cuenta |
| `kasm_url` | `https://127.0.0.1:443` | URL base de Kasm |
| `kasm_user_api_key_file` | `{{ kasm_dir }}/.kasm_api_key.json` | De dónde leer la API key |

## Ejemplo

```yaml
- hosts: ubuntu
  roles:
    - role: kasm_user
      vars:
        kasm_user_username: "user@kasm.local"
        kasm_user_password: "{{ kasm_user_password_generada }}"
```
