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
