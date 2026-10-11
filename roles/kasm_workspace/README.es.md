# kasm_workspace

Crea o borra un workspace de Kasm (una imagen registrada), elegido vía
`kasm_workspace_state: present|absent`. Requiere que Kasm ya esté instalado
(ejecutar antes [`kasm`](../kasm/README.es.md)).

No cubierto por ningún rol ni collection de Galaxy. La API pública de Kasm
cubre más de lo que se asumió al principio: la creación del workspace
(`create_image`) y la comprobación de existencia (`get_images`) ya usan la
API. Sigue siendo SQL directo: borrar un workspace (no existe endpoint
público `delete_image`), y la resolución de zona para el Session Staging
(no existe endpoint público `get_zones`). El staging en sí **sí** tiene API
pública (`create_staging_config`/`update_staging_config`) — todavía no
migrado porque no se ha verificado el esquema exacto del payload contra una
instancia real; queda como pendiente (ver el plan de la sesión). Esta
mezcla de llamadas API y SQL directo es la razón de que
`files/create_workspace.sh` y `files/delete_workspace.sh` se mantengan como
scripts bash envueltos por el rol en vez de reescribirse como tasks
`ansible.builtin.uri` — la lógica (bootstrap de API key con flock, staging
condicional, parseo de respuestas) es demasiado compleja para que eso
simplifique nada.

## Grupos de variables

Las variables se agrupan por lo que configuran, no solo alfabéticamente:

- **Núcleo del workspace**: `kasm_workspace_image`, `_name`, `_desc`, `_cores`,
  `_memory_gb`, `_privileged`, `_gpu_count`, `_session_time_limit`,
  `_category`, `_enabled`.
- **`_profile`** — el directorio home persistente del workspace:
  `kasm_workspace_profile_path`. Debe contener `{username}` o `{user_id}`;
  vacío desactiva la persistencia.
- **`_group`** — Session Staging a nivel de zona/grupo (precalienta sesiones
  de antemano): `kasm_workspace_group_staging_enabled`, `_num_sessions`,
  `_expiration_hours`, `_zone_name`. El staging vive a nivel de zona en Kasm,
  no por workspace, por eso es una familia propia en vez de ir plano junto a
  las variables del núcleo del workspace. Requiere que la zona destino ya
  tenga un `proxy_hostname` fijo configurado (no `$request_host$`) — si no,
  el script omite el staging con un aviso en vez de fallar toda la creación
  del workspace.
- **Solo con `state: absent`**: `kasm_workspace_clean_all` (borra todos los
  workspaces registrados en vez de uno), `kasm_workspace_delete_persistent_data`
  (por defecto `true` — irreversible, ver aviso abajo).

## Borrado de datos persistentes

`kasm_workspace_delete_persistent_data` es `true` por defecto a propósito:
los perfiles persistentes se indexan por `image_id`, no por workspace, así
que dejarlos vivos puede filtrar ficheros de una versión anterior de la
imagen a un workspace nuevo que reutilice el mismo `image_id`. Poner a
`false` para conservarlos (ej. al reinstalar un workspace mantenido el home
de los usuarios).

## Ejemplo

```yaml
- hosts: ubuntu
  roles:
    - role: kasm_workspace
      vars:
        kasm_workspace_state: present
        kasm_workspace_image: "usuario/mi-imagen:1.0"
        kasm_workspace_name: "Mi workspace"
        kasm_workspace_profile_path: "/opt/kasm_profiles/{user_id}/{image_id}"
```

```yaml
# Volver a borrarlo
- hosts: ubuntu
  roles:
    - role: kasm_workspace
      vars:
        kasm_workspace_state: absent
        kasm_workspace_image: "usuario/mi-imagen:1.0"
```
