# examples/

Runnable playbooks and shell scripts that compose the roles in this
directory, so you don't have to reconstruct the right role order or
variable names from scratch.

`ansible.cfg` in this directory sets `roles_path` to find the sibling roles
and the Galaxy dependencies automatically — no need to export
`ANSIBLE_ROLES_PATH` by hand when running these from here.

## Playbooks

- **`site-kasm.yml`** — full install: `docker` → `student` →
  `kasm_credentials` → `kasm` → `kasm_group`.
- **`kasm-workspace.yml`** — create or delete a single workspace
  (`kasm_docker_image` → `kasm_workspace`, or the reverse order for deletion).
- **`kasm-uninstall.yml`** — removes an existing Kasm install (`kasm_uninstall`)
  so the next `site-kasm.yml` run is a genuine fresh install.

## Scripts

| Script | What it shows |
|---|---|
| `01_install_default_domain.sh` | Full install with a placeholder domain (`kasm_base_domain` has no sane default outside this project on purpose — always pass a real one) |
| `02_install_custom_domain.sh` | Full install with your own domain and Let's Encrypt email |
| `03_install_no_tls.sh` | Local/DNS-less install, `kasm_letsencrypt_enabled=false` |
| `04_workspace_create.sh` | Create a workspace with the default example image |
| `05_workspace_create_custom_image.sh` | Create a workspace from your own image, with explicit cores/memory and a name containing spaces (JSON `-e` form) |
| `06_workspace_delete.sh` | Delete a workspace (and its Docker image), optionally keeping persistent profile data |
| `07_kasm_uninstall.sh` | Remove an existing Kasm install, so the next install is genuinely fresh |

All scripts take the inventory path as an optional first argument,
defaulting to `./inventory` (the plain, conventional filename) when
omitted:

```bash
./01_install_default_domain.sh                          # uses ./inventory
./01_install_default_domain.sh inventory-my-deployment   # explicit override
```

For this project's own real Contabo testing, pass
`inventory-prueba-kasm-contabo` explicitly — see
[`TEST.md`](TEST.md)/[`TEST.es.md`](TEST.es.md).

Requires the Galaxy dependencies installed first:

```bash
ansible-galaxy role install -r ../requirements.yml
```
