# Plan: roles de Ansible para configurar una máquina con Kasm

## Contexto

El ejemplo `31_vault` configura una máquina con Kasm mediante playbooks monolíticos:
`01` (Docker), `02` (usuario `alumno`), `25` (instalar Kasm + HTTPS + credenciales),
`23` (crear workspace) y `24` (borrar workspace). `25` tiene ~250 líneas con seis
responsabilidades distintas, y los pasos de Let's Encrypt están duplicados entre `22` y `25`.

Objetivo: un directorio `roles/` con roles reutilizables y componibles que cubran lo mismo
que esos cinco playbooks. `31_vault` no se toca (sigue funcionando); la migración es posterior
y opcional.

Estado: **borrador para discutir punto por punto**. No hay ningún rol creado todavía.

## Propuesta: 7 roles

| # | Rol | Origen | Responsabilidad |
|---|-----|--------|-----------------|
| 1 | `docker_engine` | 01 | Repo oficial de Docker, paquetes, módulos de kernel (`overlay`, `br_netfilter`), sysctl, servicios, `python3-docker`, grupo `docker` |
| 2 | `swapfile` | 25 | Swapfile genérico (tamaño variable, idempotente, entrada en fstab) |
| 3 | `usuario_alumno` | 02 | Usuario `alumno` con grupos `docker` y `sudo`, contraseña aleatoria persistida en `.credenciales/` |
| 4 | `kasm_install` | 25 | sysctl AppArmor userns, `/opt/kasm`, compose, `fix_and_install_kasm.sh`, límites de sesión, bloqueo de impresión en nginx |
| 5 | `kasm_letsencrypt` | 22 / 25 | certbot standalone, copia de certs a Kasm, restart de `kasm_proxy`, deploy hook de renovación, verificación HTTPS |
| 6 | `kasm_credenciales` | 25 | Contraseñas aleatorias de admin/user y volcado al CSV `datos-acceso-<proyecto>-<fecha>.csv` |
| 7 | `kasm_workspace` | 23 + 24 | `state: present` (pull de imagen, `11_create_workspace.sh`, API key persistente) / `state: absent` (`12_delete_workspace.sh`, sesiones, imagen, perfiles persistentes) |

## Estructura estándar de cada rol

```
roles/<rol>/
  defaults/main.yml   # variables públicas, documentadas
  tasks/main.yml
  files/ templates/   # scripts y plantillas propios del rol
  handlers/main.yml   # si aplica
  meta/main.yml       # dependencias
  README.md
```

Los scripts de `31_vault/files/kasm/` (`11_create_workspace.sh`, `12_delete_workspace.sh`,
`09_configure_session_limits.sh`, hook de Let's Encrypt, etc.) se copian al rol que los usa.

## Dependencias entre roles

```
docker_engine ─┐
swapfile ──────┼─> kasm_install ─> kasm_letsencrypt
               │         │
kasm_credenciales ───────┘            kasm_workspace (requiere Kasm instalado)
usuario_alumno (independiente; docker_engine por el grupo docker)
```

Orden de ejecución equivalente al actual: `01` → `02` → `25` → `23` / `24`.

## Variables públicas principales (de los playbooks actuales)

- `kasm_install`: `kasm_dir` (`/opt/kasm`), `kasm_version`, `kasm_domain`, `kasm_base_domain`, `swap_size`.
- `kasm_letsencrypt`: `kasm_letsencrypt_enabled`, `letsencrypt_email`, `kasm_domain`.
- `kasm_credenciales`: `credentials_dir`, `kasm_proyecto_formativo`, `kasm_admin_password`, `kasm_user_password`.
- `usuario_alumno`: `alumno_password_plain`.
- `kasm_workspace`: `kasm_workspace_state`, `kasm_image`, `kasm_workspace_name`, `_desc`, `_cores`, `_memory_gb`, `_privileged`, `_gpu_count`, `_persistent_profile_path`, `_staging_*`, `kasm_clean_all`, `kasm_delete_persistent_data`.

## Decisiones abiertas (para discutir)

1. **¿23 y 24 en un solo rol con `state`, o dos roles?** Propuesta: uno, porque comparten API, scripts y variables.
2. **¿`kasm_credenciales` como rol propio, o integrado en `kasm_install`?** Lo usan 02 y 25; separado evita acoplar `usuario_alumno` a Kasm.
3. **¿`swapfile` genérico o dentro de `kasm_install`?** Propuesta: genérico (reutilizable fuera de Kasm).
4. **¿`kasm_letsencrypt` dentro de `kasm_install` o separado?** Propuesta: separado (se puede desactivar y se usa también sin reinstalar).
5. **Playbooks de ejemplo** que compongan los roles (`site-kasm.yml`, `kasm-workspace.yml`): ¿dónde viven?
6. **Scripts bash vs. módulos Ansible**: `11`/`12` son scripts largos (API y BD de Kasm). ¿Se mantienen como scripts dentro del rol o se reescriben con módulos `uri`/`command`?
7. **Secretos**: `.credenciales/`, CSV y `kasm-api-key-*.json` deben seguir fuera de git (revisar `.gitignore` en la raíz).
8. **Dependencias de colecciones**: `community.docker` → `requirements.yml` en la raíz de `roles/`.

## Orden de implementación sugerido

1. `docker_engine`
2. `usuario_alumno`
3. `swapfile`
4. `kasm_install`
5. `kasm_letsencrypt`
6. `kasm_credenciales`
7. `kasm_workspace`

## Verificación (por rol, en fases posteriores)

- `ansible-lint` y `ansible-playbook --syntax-check`.
- Ejecución sobre `inventory-prueba-kasm-local` / `-lxc`, y segunda pasada sin cambios (idempotencia).
- Ciclo completo equivalente al validado en Contabo: instalar → crear workspace → sesión `running` → limpiar.
- Toda ejecución de `ansible-playbook` con salida a un log de ruta conocida (`tee`).
