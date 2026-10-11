# kasm_docker_image

Pulls or removes a Docker image inside Kasm's DinD (`docker exec kasm docker
...`), independent of whether that image is registered as a Kasm workspace.
Split out of [`kasm_workspace`](../kasm_workspace/README.md), which used to
pull the image as part of creating a workspace and remove+prune it as part
of deleting one — now a workspace's lifecycle (the `images` table row,
staging, persistent profile) and the underlying Docker image's lifecycle are
two separate, composable steps.

Idempotent: checks `docker image inspect` first, so pulling an
already-present image or removing an already-absent one is a no-op.

## Variables

| Variable | Default | Purpose |
|---|---|---|
| `kasm_docker_image_name` | — (required) | e.g. `user/image:tag` |
| `kasm_docker_image_state` | `present` | `present` pulls if missing; `absent` removes if present |
| `kasm_docker_image_prune_after_remove` | `true` | Also run `docker image prune -f` after removing (absent only) |

`state: absent` fails if a workspace still references the image or a
session still uses it (Docker refuses to remove an image in use) — delete
the [`kasm_workspace`](../kasm_workspace/README.md) registration first.

## Example

```yaml
- hosts: ubuntu
  roles:
    - role: kasm_docker_image
      vars:
        kasm_docker_image_name: "user/my-image:1.0"
        kasm_docker_image_state: present
    - role: kasm_workspace
      vars:
        kasm_workspace_state: present
        kasm_workspace_image: "user/my-image:1.0"
        kasm_workspace_name: "My workspace"
```
