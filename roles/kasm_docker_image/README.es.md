# kasm_docker_image

Hace pull o borra una imagen Docker dentro del DinD de Kasm
(`docker exec kasm docker ...`), independientemente de si esa imagen está
registrada como workspace de Kasm. Separado de
[`kasm_workspace`](../kasm_workspace/README.es.md), que antes hacía el pull
como parte de crear un workspace y el remove+prune como parte de borrarlo —
ahora el ciclo de vida del workspace (la fila en la tabla `images`, staging,
perfil persistente) y el ciclo de vida de la imagen Docker subyacente son
dos pasos separados y componibles.

Idempotente: comprueba primero con `docker image inspect`, así que hacer
pull de una imagen ya presente o borrar una ya ausente no hace nada.

## Variables

| Variable | Valor por defecto | Propósito |
|---|---|---|
| `kasm_docker_image_name` | — (obligatoria) | ej. `usuario/imagen:tag` |
| `kasm_docker_image_state` | `present` | `present` hace pull si falta; `absent` borra si está presente |
| `kasm_docker_image_prune_after_remove` | `true` | También ejecuta `docker image prune -f` tras borrar (solo con absent) |

`state: absent` falla si un workspace todavía referencia la imagen o una
sesión la sigue usando (Docker rechaza borrar una imagen en uso) — borra
antes el registro de [`kasm_workspace`](../kasm_workspace/README.es.md).

## Ejemplo

```yaml
- hosts: ubuntu
  roles:
    - role: kasm_docker_image
      vars:
        kasm_docker_image_name: "usuario/mi-imagen:1.0"
        kasm_docker_image_state: present
    - role: kasm_workspace
      vars:
        kasm_workspace_state: present
        kasm_workspace_image: "usuario/mi-imagen:1.0"
        kasm_workspace_name: "Mi workspace"
```
