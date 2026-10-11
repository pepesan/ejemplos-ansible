# examples/

Playbooks y scripts de shell ejecutables que componen los roles de este
directorio, para no tener que reconstruir desde cero el orden correcto de
roles ni los nombres de variables.

El `ansible.cfg` de este directorio fija `roles_path` para encontrar
automáticamente los roles hermanos y las dependencias de Galaxy — no hace
falta exportar `ANSIBLE_ROLES_PATH` a mano al ejecutar desde aquí.

## Playbooks

- **`site-kasm.yml`** — instalación completa: `docker` → `student` →
  `kasm_credentials` → `kasm` → `kasm_group`.
- **`kasm-workspace.yml`** — crea o borra un único workspace
  (`kasm_docker_image` → `kasm_workspace`, o el orden inverso para borrar).
- **`kasm-uninstall.yml`** — elimina una instalación de Kasm existente
  (`kasm_uninstall`) para que el siguiente `site-kasm.yml` sea una
  instalación realmente nueva.

## Scripts

| Script | Qué muestra |
|---|---|
| `01_install_default_domain.sh` | Instalación completa con un dominio placeholder (`kasm_base_domain` no tiene valor por defecto sensato fuera de este proyecto a propósito — pasa siempre uno real) |
| `02_install_custom_domain.sh` | Instalación completa con tu propio dominio y email de Let's Encrypt |
| `03_install_no_tls.sh` | Instalación local/sin DNS, `kasm_letsencrypt_enabled=false` |
| `04_workspace_create.sh` | Crea un workspace con la imagen de ejemplo por defecto |
| `05_workspace_create_custom_image.sh` | Crea un workspace con tu propia imagen, cores/memoria explícitos y un nombre con espacios (forma JSON de `-e`) |
| `06_workspace_delete.sh` | Borra un workspace (y su imagen Docker), opcionalmente conservando los perfiles persistentes |
| `07_kasm_uninstall.sh` | Elimina una instalación de Kasm existente, para que la siguiente instalación sea realmente nueva |

Todos los scripts toman la ruta del inventory como primer argumento
opcional, con valor por defecto `./inventory` (el nombre plano
convencional) si se omite:

```bash
./01_install_default_domain.sh                          # usa ./inventory
./01_install_default_domain.sh inventory-mi-despliegue   # override explícito
```

Para las pruebas reales de este proyecto contra Contabo, pasar
`inventory-prueba-kasm-contabo` explícitamente — ver
[`TEST.md`](TEST.md)/[`TEST.es.md`](TEST.es.md).

Requiere tener instaladas antes las dependencias de Galaxy:

```bash
ansible-galaxy role install -r ../requirements.yml
```
