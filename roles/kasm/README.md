# kasm

Installs Kasm Workspaces with no workspace registered yet (that's
[`kasm_workspace`](../kasm_workspace/README.md)'s job): sysctl tuning,
`/opt/kasm`, docker compose, the fix-and-install script, server-wide image
pruning mode, nginx print blocking, and — by default — a real Let's Encrypt
certificate. Session timeouts and per-group hardening are configured
separately by [`kasm_group`](../kasm_group/README.md),
run after this role.

Not covered by any maintained Galaxy role (`monolithprojects.kasm_server` was
considered and discarded — last commit 2021, and even then it only covered a
bare install). This role is written from scratch, but delegates the two
generic pieces it needs to maintained Galaxy roles instead of reimplementing
them:

- **Swap**: [`geerlingguy.swap`](https://github.com/geerlingguy/ansible-role-swap)
  (dependency in `meta/main.yml`) — Kasm's installer needs swap present or it
  fails.
- **Let's Encrypt**: [`geerlingguy.certbot`](https://github.com/geerlingguy/ansible-role-certbot)
  (dependency) handles installing certbot, issuing the initial cert, and the
  renewal cron. `tasks/letsencrypt.yml` only adds what's Kasm-specific:
  locating its real cert directory inside the container, copying the
  certbot-issued cert there, restarting `kasm_proxy`, installing the renewal
  deploy-hook, and verifying HTTPS comes up.

## TLS is on by default

`kasm_letsencrypt_enabled: true`. Requires `kasm_domain`
(`{{ node_name }}.{{ kasm_base_domain }}`) to already resolve to this host
and port 80 to be free for the HTTP-01 challenge. For local/DNS-less
environments, disable explicitly:

```
-e kasm_letsencrypt_enabled=false
```

Kasm then stays reachable over its self-signed certificate.

## How the install is verified (and retried)

`files/fix_and_install_kasm.sh` runs Kasm's `install.sh` inside the container.
Two things about it are easy to get wrong and cost a lot of time to debug:

- **`install.sh` can abort early** with `dial unix .../kasmlogger.sock` or
  `.../kasmnetwork.sock: connect: connection refused`. Those are Kasm's own
  Docker plugins (`kasmweb/logger`, `kasmweb/sidecar`) not answering on their
  socket in the instant Docker tries to enable them: a timing race, not a
  persistent fault. The plugin is up seconds later, so enabling it by hand
  just after works. It hits some hosts more than others and gets more likely
  the more installs run at once (see `examples/` — use a low `-f`).
- **Success is decided by the services, not by the exit code.** The script
  tolerates a non-zero `install.sh` (a harmless `kasm_manager` healthcheck
  timeout is a known case), so it checks that `kasm_db`, `kasm_api` and
  `kasm_manager` are actually running. If they are not, it enables any
  disabled plugin and runs `install.sh` again, up to 3 attempts, and only
  then exits with an error **without** writing the install marker
  (`/opt/kasm/data/opt/kasm_install_complete` on the host).

An earlier version wrote the marker regardless and its "wait until healthy"
loop declared success when there were *no* containers at all (nothing is
`unhealthy` or `starting`). The play then "passed" and failed several tasks
later in `Read current image-pruning mode` with `No such container: kasm_db`,
and every re-run printed `already installed. Skipping` and repaired nothing.
If you meet that state on a host, delete the marker and re-run.

## Variables

| Variable | Default | Purpose |
|---|---|---|
| `kasm_dir` | `/opt/kasm` | Install directory |
| `kasm_version` / `kasm_image_tag` | `1.19.0` / `1.19.0-ls148` | Kasm version / container image tag |
| `kasm_base_domain` | `example.com` (placeholder, no sane default outside this project) | Base domain; set explicitly per deployment |
| `kasm_domain` | `{{ node_name }}.{{ kasm_base_domain }}` | Full per-node domain |
| `kasm_letsencrypt_enabled` | `true` | Toggle real TLS on/off |
| `letsencrypt_email` | `admin@{{ kasm_base_domain }}` | Certbot account email |
| `kasm_admin_password` / `kasm_user_password` | — | Provided by [`kasm_credentials`](../kasm_credentials/README.md); run that role first or set these yourself |

## Dependencies

- `geerlingguy.swap`, `geerlingguy.certbot` (Galaxy, pinned in `roles/requirements.yml`)
- `community.docker` (compose, container exec)
- Requires `kasm_admin_password`/`kasm_user_password` to already be defined —
  normally by running [`kasm_credentials`](../kasm_credentials/README.md)
  beforehand.

## Example

```yaml
- hosts: ubuntu
  roles:
    - docker
    - kasm_credentials
    - role: kasm
      vars:
        kasm_base_domain: mydomain.example.com
    - kasm_group
```
