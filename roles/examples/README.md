# examples/

Runnable playbooks and shell scripts that compose the roles in this
directory, so you don't have to reconstruct the right role order or
variable names from scratch.

This page is the practical guide: **install Kasm, create workspaces, keep a
session warm, tune sessions, delete, uninstall**, each with copy-paste
commands. The reference for every variable lives in each role's own README
(linked at the end).

- [1. Before you start](#1-before-you-start)
- [2. Quick start](#2-quick-start)
- [3. What is in this directory](#3-what-is-in-this-directory)
- [4. Install Kasm](#4-install-kasm-site-kasmyml)
- [5. Credentials and files that get generated](#5-credentials-and-files-that-get-generated)
- [6. Workspaces](#6-workspaces-kasm-workspaceyml)
- [7. Warm session for a user (autostart)](#7-warm-session-for-a-user-autostart)
- [8. Session policy and hardening](#8-session-policy-and-hardening-kasm_group)
- [9. Delete workspaces](#9-delete-workspaces)
- [10. Uninstall Kasm](#10-uninstall-kasm-kasm-uninstallyml)
- [11. Check the result (read-only)](#11-check-the-result-read-only)
- [12. Troubleshooting](#12-troubleshooting)
- [13. Per-role reference](#13-per-role-reference)

## 1. Before you start

**Control node** (your machine): Ansible with `ansible-playbook`, and SSH
access as `root` to the target server (Ubuntu 22.04+/24.04+).

**Galaxy dependencies** (Docker, swap, certbot — pinned in
`../requirements.yml`). Install them once:

```bash
cd roles/examples
ansible-galaxy role install -r ../requirements.yml
ansible-galaxy collection install -r ../requirements.yml
```

`ansible.cfg` in this directory sets `roles_path` to find the sibling roles
and the Galaxy dependencies automatically — no need to export
`ANSIBLE_ROLES_PATH` by hand when running from here.

**Inventory.** One host per Kasm server. `node_name` decides the DNS name:
the server is reachable at `<node_name>.<kasm_base_domain>`.

```ini
[ubuntu]
203.0.113.10 node_name=kasmdemo

[ubuntu:vars]
ansible_user=root
ansible_become=false
```

With `kasm_base_domain=kasm.example.com` that host becomes
`https://kasmdemo.kasm.example.com`. The plain `inventory` file in this
directory is a placeholder (`X.X.X.X`); keep real inventories in files named
`inventory-*` — they are git-ignored on purpose (a real IP is a secret).

**DNS.** For real TLS (Let's Encrypt), `<node_name>.<kasm_base_domain>` must
already resolve to the server and port 80 must be free for the HTTP-01
challenge.

## 2. Quick start

```bash
cd roles/examples
INV=inventory-my-server

# 1. Install Kasm (Docker, "alumno" user, Kasm itself with TLS, group policy)
ansible-playbook -i $INV site-kasm.yml \
  -e kasm_base_domain=kasm.example.com \
  -e letsencrypt_email=you@example.com \
  2>&1 | tee /tmp/kasm-install.log

# 2. Register a workspace
ansible-playbook -i $INV kasm-workspace.yml \
  -e kasm_workspace_state=present \
  -e kasm_docker_image_name=pepesan/mi-ubuntu-resolute-kasm-terminal-dind:1.1 \
  -e kasm_workspace_image=pepesan/mi-ubuntu-resolute-kasm-terminal-dind:1.1 \
  -e '{"kasm_workspace_name": "Terminal DinD"}' \
  -e kasm_workspace_privileged=true \
  2>&1 | tee /tmp/kasm-workspace.log

# 3. Credentials are in ./datos-acceso-<inventory file name>.csv
```

> Always send playbook output to a log with `tee` (as above) so you can
> `tail -f` it from another terminal. A first install takes several
> minutes; the slow part is Kasm's own installer.

## 3. What is in this directory

### Playbooks

| File | What it does |
|---|---|
| `site-kasm.yml` | Full install: `docker` → `student` → `kasm_credentials` → `kasm` → `kasm_group` |
| `kasm-workspace.yml` | Create or delete **one** workspace (`kasm_docker_image` → `kasm_workspace`, reversed for deletion) |
| `kasm-uninstall.yml` | Remove an existing Kasm install (`kasm_uninstall`) so the next `site-kasm.yml` is a genuine fresh install |
| `kasm-session.yml` | Start or destroy a running session of an already registered workspace for a user (`kasm_session`; default `user@kasm.local`). Names with spaces go as JSON |

### Scripts (thin wrappers around the playbooks)

| Script | What it shows |
|---|---|
| `01_install_default_domain.sh` | Full install with a placeholder domain (`kasm_base_domain` has no sane default outside this project on purpose — always pass a real one) |
| `02_install_custom_domain.sh` | Full install with your own domain and Let's Encrypt email |
| `03_install_no_tls.sh` | Local/DNS-less install, `kasm_letsencrypt_enabled=false` |
| `04_workspace_create.sh` | Create a workspace with the default example image |
| `05_workspace_create_custom_image.sh` | Create a workspace from your own image, with explicit cores/memory and a name containing spaces (JSON `-e` form) |
| `06_workspace_delete.sh` | Delete a workspace (and its Docker image), optionally keeping persistent profile data |
| `07_kasm_uninstall.sh` | Remove an existing Kasm install |

All scripts take the inventory path as an optional first argument,
defaulting to `./inventory` when omitted:

```bash
./02_install_custom_domain.sh                                   # ./inventory
./02_install_custom_domain.sh inventory-my-server kasm.example.com you@example.com
./05_workspace_create_custom_image.sh inventory-my-server user/image:1.0 "My workspace"
./06_workspace_delete.sh inventory-my-server user/image:1.0 keep_profiles
./07_kasm_uninstall.sh inventory-my-server
```

The scripts do not tee to a log or expose every variable. For anything
beyond them, call the playbooks directly, as in the rest of this page.

## 4. Install Kasm (`site-kasm.yml`)

### What it does, in order

| Role | What it does |
|---|---|
| `docker` | Docker CE + Compose plugin, `overlay`/`br_netfilter` modules, `ip_forward` and bridge sysctls, `python3-docker` |
| `student` | Linux user `alumno` (bash, groups `docker`,`sudo`) with a random 20-char password |
| `kasm_credentials` | Generates/reads the Kasm admin and user passwords and updates the access CSV (runs on your machine only) |
| `kasm` | 4 GB swap, certbot + certificate, AppArmor userns fix, `/opt/kasm/compose.yaml`, Kasm container, Kasm installer, image-pruning off, print-block snippet, HTTPS with Let's Encrypt |
| `kasm_group` | Per-group session policy (keepalive and hardening) for the "All Users" group |

It is **idempotent**: a second run does not reinstall Kasm (a marker
`/opt/kasm_install_complete` lives under `/opt/kasm/data`).

### Examples

Real domain with Let's Encrypt (the usual case):

```bash
ansible-playbook -i inventory-my-server site-kasm.yml \
  -e kasm_base_domain=kasm.example.com \
  -e letsencrypt_email=you@example.com \
  2>&1 | tee /tmp/kasm-install.log
```

Same, through the wrapper script:

```bash
./02_install_custom_domain.sh inventory-my-server kasm.example.com you@example.com
```

Local / no DNS (Kasm keeps its self-signed certificate):

```bash
ansible-playbook -i inventory-local site-kasm.yml \
  -e kasm_base_domain=example.com \
  -e kasm_letsencrypt_enabled=false
# or: ./03_install_no_tls.sh inventory-local
```

Bigger swap, and a cohort prefix for the access CSV (parallel courses don't
mix rows):

```bash
ansible-playbook -i inventory-my-server site-kasm.yml \
  -e kasm_base_domain=kasm.example.com \
  -e letsencrypt_email=you@example.com \
  -e kasm_swap_file_size_mb=8192 \
  -e kasm_proyecto_formativo=curso-docker
```

Choose the passwords instead of generating them:

```bash
ansible-playbook -i inventory-my-server site-kasm.yml \
  -e kasm_base_domain=kasm.example.com \
  -e kasm_admin_password='ChangeMe-Admin-1' \
  -e kasm_user_password='ChangeMe-User-1'
```

Install several servers in one go: one line per host in the inventory, each
with its own `node_name`. Each gets its own row in the CSV.

### Frequently used variables

| Variable | Default | Role | Meaning |
|---|---|---|---|
| `kasm_base_domain` | `example.com` | `kasm` | Base domain; host is `<node_name>.<kasm_base_domain>` |
| `letsencrypt_email` | `admin@<kasm_base_domain>` | `kasm` | Email for certbot |
| `kasm_letsencrypt_enabled` | `true` | `kasm` | `false` keeps the self-signed certificate |
| `kasm_version` / `kasm_image_tag` | `1.19.0` / `1.19.0-ls148` | `kasm` | Kasm release and the linuxserver image tag |
| `kasm_swap_file_size_mb` | `4096` | `kasm` | Swap file size |
| `kasm_proyecto_formativo` | `""` | `kasm_credentials` | Prefix of the access CSV |
| `kasm_admin_password` / `kasm_user_password` | random | `kasm_credentials` | Override the generated passwords |
| `kasm_group_keepalive_seconds` | `3600` | `kasm_group` | Seconds before an idle session acts |

## 5. Credentials and files that get generated

All of these are created on **your machine**, in this directory, and are
git-ignored. Never commit them.

| File | What it holds |
|---|---|
| `.credenciales/<ip>-alumno.pass` | Password of the Linux user `alumno` |
| `.credenciales/<ip>-kasm-admin.pass` | Password of `admin@kasm.local` |
| `.credenciales/<ip>-kasm-user.pass` | Password of `user@kasm.local` |
| `datos-acceso-<date>.csv` | One row per server: IP, Kasm URL, and the three credentials. With `kasm_proyecto_formativo=x`: `datos-acceso-x-<date>.csv` |
| `kasm-api-key-<ip>.json` | Copy of the persistent API key (created on the first workspace) |

Passwords are generated **once** and re-read on later runs. To get new
passwords, delete `.credenciales/` before running `site-kasm.yml`. The
uninstall does not touch it.

The API key itself lives on the server in `/opt/kasm/.kasm_api_key.json`
(mode 600) and is created the first time a workspace is registered.

## 6. Workspaces (`kasm-workspace.yml`)

A workspace is a Docker image registered in Kasm. `kasm-workspace.yml`
pulls the image into Kasm's nested Docker (the "DinD") and registers it.
Kasm must already be installed.

You always pass the image **twice**: `kasm_docker_image_name` (what to
pull) and `kasm_workspace_image` (what to register). They are the same
string.

Names with spaces must go through the JSON `-e` form — a plain
`-e var=a b` truncates at the first space.

### Minimal

```bash
ansible-playbook -i inventory-my-server kasm-workspace.yml \
  -e kasm_workspace_state=present \
  -e kasm_docker_image_name=pepesan/mi-ubuntu-resolute-kasm:1.0 \
  -e kasm_workspace_image=pepesan/mi-ubuntu-resolute-kasm:1.0 \
  -e '{"kasm_workspace_name": "Ubuntu Resolute"}'
# or: ./04_workspace_create.sh inventory-my-server
```

### DinD images (Docker inside the session) need `privileged`

Images that run their own Docker daemon cannot start it without
privileges. Without `kasm_workspace_privileged=true` the session boots but
Docker inside it does not work.

```bash
# Java / Spring Boot dev + DinD (18 GB image: the pull takes minutes)
ansible-playbook -i inventory-my-server kasm-workspace.yml \
  -e kasm_workspace_state=present \
  -e kasm_docker_image_name=pepesan/mi-ubuntu-resolute-kasm-java-spring-boot-web-dev-dind:1.6 \
  -e kasm_workspace_image=pepesan/mi-ubuntu-resolute-kasm-java-spring-boot-web-dev-dind:1.6 \
  -e '{"kasm_workspace_name": "Java Spring Boot Dev DinD"}' \
  -e kasm_workspace_privileged=true \
  -e kasm_workspace_cores=4 \
  -e kasm_workspace_memory_gb=8 \
  2>&1 | tee /tmp/kasm-workspace-java.log
```

```bash
# Terminal + DinD
ansible-playbook -i inventory-my-server kasm-workspace.yml \
  -e kasm_workspace_state=present \
  -e kasm_docker_image_name=pepesan/mi-ubuntu-resolute-kasm-terminal-dind:1.1 \
  -e kasm_workspace_image=pepesan/mi-ubuntu-resolute-kasm-terminal-dind:1.1 \
  -e '{"kasm_workspace_name": "Terminal DinD"}' \
  -e kasm_workspace_privileged=true \
  -e kasm_workspace_cores=2 \
  -e kasm_workspace_memory_gb=4 \
  2>&1 | tee /tmp/kasm-workspace-terminal.log
```

Launch the big image first only if the server has the RAM; the two
examples above reserve 8 GB + 4 GB when both have a session open.

### Wrapper for your own image

```bash
./05_workspace_create_custom_image.sh inventory-my-server \
  pepesan/mi-ubuntu-resolute-kasm-python-dind:1.1 "Python DinD"
```

### Workspace variables

| Variable | Default | Meaning |
|---|---|---|
| `kasm_workspace_name` | — (required) | Name shown to the users |
| `kasm_workspace_desc` | = name | Description |
| `kasm_workspace_cores` | `4` | CPU cores per session |
| `kasm_workspace_memory_gb` | `8` | RAM per session |
| `kasm_workspace_privileged` | `false` | Needed for DinD images |
| `kasm_workspace_gpu_count` | `0` | GPUs |
| `kasm_workspace_session_time_limit` | `""` | Hard limit in seconds |
| `kasm_workspace_category` | `""` | Category in the catalog |
| `kasm_workspace_enabled` | `true` | Visible to users |
| `kasm_workspace_profile_path` | `""` | Persistent home. Must contain `{username}` or `{user_id}` |

Persistent home directory (the user's files survive session deletion):

```bash
ansible-playbook -i inventory-my-server kasm-workspace.yml \
  -e kasm_workspace_state=present \
  -e kasm_docker_image_name=user/image:1.0 \
  -e kasm_workspace_image=user/image:1.0 \
  -e '{"kasm_workspace_name": "With persistence"}' \
  -e 'kasm_workspace_profile_path=/opt/kasm_profiles/{user_id}/{image_id}'
```

Re-running with the same image is safe: the existing workspace is reused.

## 7. Warm session for a user (autostart)

By default a user's first login starts the session from cold, which for a
large image means a wait (proxy 502 for several seconds, desktop slow to
paint). `kasm_workspace_autostart_enabled=true` launches **one session of
the workspace for a Kasm user** right after the workspace is created, so
the first login finds it already running.

```bash
ansible-playbook -i inventory-my-server kasm-workspace.yml \
  -e kasm_workspace_state=present \
  -e kasm_docker_image_name=pepesan/mi-ubuntu-resolute-kasm-terminal-dind:1.1 \
  -e kasm_workspace_image=pepesan/mi-ubuntu-resolute-kasm-terminal-dind:1.1 \
  -e '{"kasm_workspace_name": "Terminal DinD"}' \
  -e kasm_workspace_privileged=true \
  -e kasm_workspace_cores=2 \
  -e kasm_workspace_memory_gb=4 \
  -e kasm_workspace_autostart_enabled=true \
  2>&1 | tee /tmp/kasm-workspace-autostart.log
```

| Variable | Default | Meaning |
|---|---|---|
| `kasm_workspace_autostart_enabled` | `false` | Turn it on |
| `kasm_workspace_autostart_user` | `user@kasm.local` | Whose session to start |
| `kasm_workspace_autostart_timeout_seconds` | `600` | How long to wait for `running` |

How it behaves:

- **Idempotent.** If that user already has a session of that workspace,
  nothing new is launched (`changed=0` on a second run).
- **Never fails the workspace.** An unknown user or a session that does not
  reach `running` in time is a `WARNING`; the workspace is still created.
- **It costs resources.** A running session permanently reserves the
  workspace's `cores` and `memory_gb`. On an 11 GB server, one Java session
  (8 GB) leaves almost nothing; do not autostart two big workspaces.
- **It must stay alive.** With the default group policy
  (`keepalive_expiration=3600`, action `pause`) a session nobody is
  connected to is paused after one hour. See the next section to extend it.
- **It does not survive a Kasm or server restart.** Re-run the same command
  to launch it again.

Alternative the role also supports but does not enable (needs the zone
hostname changed in the admin panel): **Session Staging**
(`kasm_workspace_group_staging_enabled=true`), which pre-warms anonymous
sessions for any user.

## 8. Session policy and hardening (`kasm_group`)

`site-kasm.yml` already runs `kasm_group` with safe defaults for the "All
Users" group. Re-running `site-kasm.yml` with other values updates them
(it is idempotent and only touches what differs):

| Variable | Default | Meaning |
|---|---|---|
| `kasm_group_keepalive_seconds` | `3600` | Idle seconds before the keepalive action. `0` is ignored by Kasm |
| `kasm_group_keepalive_action` | `pause` | `pause` or `delete` |
| `kasm_group_allow_clipboard_down` / `_up` / `_seamless` | `false` | Clipboard out of / into the session |
| `kasm_group_allow_downloads` / `_uploads` | `false` | File transfer |
| `kasm_group_allow_printing` | `false` | Printing |

Keep sessions for a day and allow the clipboard (for a class):

```bash
ansible-playbook -i inventory-my-server site-kasm.yml \
  -e kasm_base_domain=kasm.example.com \
  -e kasm_group_keepalive_seconds=86400 \
  -e kasm_group_allow_clipboard_down=true \
  -e kasm_group_allow_clipboard_up=true
```

Passing the same `kasm_base_domain` as the original install is enough; no
reinstall happens.

## 9. Delete workspaces

Closes the active sessions of that image, removes the workspace from the
catalog, deletes its persistent profile data (irreversible, the default) and
removes the Docker image from the DinD.

```bash
ansible-playbook -i inventory-my-server kasm-workspace.yml \
  -e kasm_workspace_state=absent \
  -e kasm_docker_image_name=pepesan/mi-ubuntu-resolute-kasm-terminal-dind:1.1 \
  -e kasm_workspace_image=pepesan/mi-ubuntu-resolute-kasm-terminal-dind:1.1
```

Keep the users' persistent home directories:

```bash
ansible-playbook -i inventory-my-server kasm-workspace.yml \
  -e kasm_workspace_state=absent \
  -e kasm_docker_image_name=user/image:1.0 \
  -e kasm_workspace_image=user/image:1.0 \
  -e kasm_workspace_delete_persistent_data=false
# or: ./06_workspace_delete.sh inventory-my-server user/image:1.0 keep_profiles
```

The playbook deletes one workspace per run; run it once per image to clean
several. A success shows `removed from Kasm's catalog` in the log.

## 10. Uninstall Kasm (`kasm-uninstall.yml`)

Removes the Kasm container (and its nested containers, networks and
volumes), the persisted data (database, Kasm's own certs, install marker,
session profiles) and `/opt/kasm`. The next `site-kasm.yml` is a real fresh
install. It does **not** touch Docker, the swap file, the `alumno` user or
your `.credenciales/`.

```bash
ansible-playbook -i inventory-my-server kasm-uninstall.yml \
  2>&1 | tee /tmp/kasm-uninstall.log
# or: ./07_kasm_uninstall.sh inventory-my-server
```

By default the host's Let's Encrypt certificate is **kept**, so the
reinstall reuses it (Let's Encrypt rate-limits issuance per domain). To
force a brand new certificate too:

```bash
ansible-playbook -i inventory-my-server kasm-uninstall.yml \
  -e kasm_uninstall_remove_letsencrypt_certs=true \
  -e kasm_base_domain=kasm.example.com
```

(`node_name` comes from the inventory.)

### Reinstall from scratch

```bash
ansible-playbook -i inventory-my-server kasm-uninstall.yml
rm -rf .credenciales         # optional: brand new passwords
ansible-playbook -i inventory-my-server site-kasm.yml \
  -e kasm_base_domain=kasm.example.com \
  -e letsencrypt_email=you@example.com
```

## 11. Check the result (read-only)

Run these on the server; none of them change anything.

```bash
# Kasm's own containers (api, manager, proxy, agent, db, guac, rdp)
docker exec kasm docker ps --format '{{.Names}}  {{.Status}}'

# Images pulled into the DinD
docker exec kasm docker images --format '{{.Repository}}:{{.Tag}}  {{.Size}}'

# Registered workspaces
docker exec kasm docker exec kasm_db psql -U kasmapp -d kasm \
  -c "SELECT name, friendly_name FROM images;"

# Sessions currently alive, and whose
docker exec kasm docker exec kasm_db psql -U kasmapp -d kasm \
  -c "SELECT u.username, k.operational_status, k.keepalive_date
        FROM kasms k JOIN users u USING (user_id);"

# Group policy that was applied
docker exec kasm docker exec kasm_db psql -U kasmapp -d kasm \
  -c "SELECT gs.name, gs.value FROM group_settings gs
        JOIN groups g USING (group_id) WHERE g.name='All Users' ORDER BY 1;"

# Installer log, live
tail -f /opt/kasm/data/opt/kasm_deploy.log
```

## 12. Troubleshooting

| Symptom | Cause and fix |
|---|---|
| First login hangs on "Creating a secure connection…" and the proxy returns 502 | The session container is still booting (cold start of a large image). It resolves itself within seconds to a few minutes. Use [autostart](#7-warm-session-for-a-user-autostart) to avoid it. |
| Desktop opens with a black background but the menu works | The desktop is still rendering on a cold start. It appears shortly after. |
| Docker does not work inside the session | The workspace was created without `kasm_workspace_privileged=true`. Delete it and create it again with the flag. |
| `-e kasm_workspace_name=My workspace` registers the name "My" | A plain `-e` truncates at the first space. Use `-e '{"kasm_workspace_name": "My workspace"}'`. |
| `syntax error at or near "\"` in `kasm_group` | An old version of the role escaped `$$` as `\$\$`. Update the repository; the task now uses `$$`. |
| `geerlingguy.certbot` fails with a `list` vs `boolean` conditional | A version older than `5.4.1`. `../requirements.yml` pins `5.4.1`; reinstall the Galaxy roles. |
| The session is paused after an hour | Group policy. Raise `kasm_group_keepalive_seconds` (section 8). |
| `ps -u alumno` on the host shows Kasm's Python processes | Kasm's service containers run as UID 1001, the same number as the `alumno` user. They are not `alumno`'s processes. Do not `pkill -u alumno`: you would kill Kasm's API. |
| Terminal-only image: letters too small, no menu bar | The image starts `xfce4-terminal --hide-menubar --zoom=-1`. Press `Ctrl` + `+`, or right-click → Preferences. To change the start zoom, set `APP_ARGS` in the workspace's Docker Run Config Override. |

## 13. Per-role reference

| Role | README |
|---|---|
| `docker` | [`../docker/README.md`](../docker/README.md) |
| `student` / `linux_user` | [`../student/README.md`](../student/README.md), [`../linux_user/README.md`](../linux_user/README.md) |
| `kasm_credentials` | [`../kasm_credentials/README.md`](../kasm_credentials/README.md) |
| `kasm` | [`../kasm/README.md`](../kasm/README.md) |
| `kasm_group` | [`../kasm_group/README.md`](../kasm_group/README.md) |
| `kasm_workspace` | [`../kasm_workspace/README.md`](../kasm_workspace/README.md) |
| `kasm_docker_image` | [`../kasm_docker_image/README.md`](../kasm_docker_image/README.md) |
| `kasm_user` | [`../kasm_user/README.md`](../kasm_user/README.md) |
| `kasm_uninstall` | [`../kasm_uninstall/README.md`](../kasm_uninstall/README.md) |

End-to-end test notes against a real server:
[`TEST.md`](TEST.md) / [`TEST.es.md`](TEST.es.md). Spanish version of this
page: [`README.es.md`](README.es.md).
