# roles/

Reusable, composable Ansible roles that cover the same ground as the
monolithic `31_vault` playbooks (`01`, `02`, `25`, `23`, `24`): provisioning
a Kasm Workspaces server end to end. `31_vault` is untouched and keeps
working; migrating to these roles is separate and optional.

See [`PLAN.md`](PLAN.md) for the design history and open decisions, and
each role's own `README.md` (English, canonical) / `README.es.md`
(Spanish) for full variable references.

## Roles

| Role | Depends on | What it does |
|---|---|---|
| [`ipv4_preference`](ipv4_preference/README.md) | — | Makes glibc prefer IPv4 over IPv6 (`/etc/gai.conf`); first dependency of `docker`, so it runs before any `apt` install |
| [`docker`](docker/README.md) | `ipv4_preference`, `geerlingguy.docker` (Galaxy) | Kernel modules + sysctl Kasm's container networking needs, on top of a maintained Docker install role |
| [`linux_user`](linux_user/README.md) | — | Generic: creates a Linux user with a persisted random password, ensuring its groups exist first |
| [`student`](student/README.md) | `linux_user` | Thin wrapper: fixes the username to `alumno` and its default groups (`docker`+`sudo`) |
| [`kasm`](kasm/README.md) | `geerlingguy.swap`, `geerlingguy.certbot` (Galaxy) | Installs Kasm Workspaces (no workspace registered yet): compose, fix-and-install, image-pruning mode, nginx print blocking, and — by default — real Let's Encrypt TLS |
| [`kasm_credentials`](kasm_credentials/README.md) | — | Random Kasm admin/user passwords + the access CSV (`datos-acceso-<project>-<date>.csv`) |
| [`kasm_group`](kasm_group/README.md) | — | Per-group session keepalive + hardening (clipboard/downloads/uploads/printing), idempotent, parameterised by group |
| [`kasm_docker_image`](kasm_docker_image/README.md) | — | Pulls/removes the Docker image inside Kasm's DinD, independent of workspace registration |
| [`kasm_workspace`](kasm_workspace/README.md) | — | Registers/deletes a workspace (the `images` table row), `state: present\|absent` |
| [`kasm_user`](kasm_user/README.md) | — | Creates/deletes a Kasm application user, pure public-API (`ansible.builtin.uri`, no SQL) |
| [`kasm_uninstall`](kasm_uninstall/README.md) | — | Removes a Kasm install cleanly (container + persisted data, optionally its Let's Encrypt cert) for a genuine fresh re-install |
| [`kasm_session`](kasm_session/README.md) | — | Starts/destroys a running session of an already registered workspace for a user (default `user@kasm.local`), pure public API; exports `kasm_id` and the session's container id |

`docker`, `linux_user` and `student` are generic (bare names, Galaxy-style,
like `geerlingguy.*`); the rest are Kasm-specific and keep the `kasm_`
prefix. `kasm_image` doesn't exist on purpose: it was renamed to
`kasm_docker_image` to avoid clashing with Kasm's own terminology, where
"image" means what this collection calls a *workspace*
(`kasm_workspace`) — see below.

## Why these Galaxy dependencies and not reimplemented roles

`geerlingguy.docker`, `geerlingguy.swap` and `geerlingguy.certbot` are
actively maintained, widely used roles that already solve Docker
installation, swapfile management, and certbot/Let's Encrypt — reimplementing
them would be pure duplication. Versions are pinned in
[`requirements.yml`](requirements.yml); install with:

```bash
ansible-galaxy role install -r roles/requirements.yml
```

A Galaxy role was also considered for Kasm itself
(`monolithprojects.kasm_server`) and discarded: unmaintained since 2021, and
even then it only covered a bare install with none of what `kasm`,
`kasm_credentials`, `kasm_workspace`, `kasm_group`, `kasm_docker_image` or
`kasm_user` cover.

## Kasm's public API vs. direct SQL

Kasm's public developer API (`api_key`/`api_key_secret`) is more complete
than it first looked, but still has real gaps. Where each role lands:

| Role | How it talks to Kasm |
|---|---|
| `kasm_user` | 100% public API (`create_user`/`get_users`/`delete_user`) — no SQL at all |
| `kasm_workspace` | Mostly API now (`create_image`, `get_images` for the existence check); still direct SQL for deleting a workspace (no public `delete_image`) and for the Session Staging zone lookup (no public `get_zones`) |
| `kasm_group` | Direct SQL — `group_settings` has no working public endpoint |
| `kasm_docker_image` | Plain `docker exec` — this is Docker image management inside Kasm's DinD, not a Kasm API concern at all |

**Known follow-up**: Session Staging *does* have a public API
(`create_staging_config`/`update_staging_config`), not yet adopted in
`kasm_workspace` because its exact request payload hasn't been verified
against a running instance — see the session plan referenced in `PLAN.md`
before attempting it, to avoid silently misconfiguring staging.

## Composition order

```
docker ─────────────────┐
linux_user ──> student ──┼──> kasm ──> kasm_credentials
                         │      │
                         │      └────> kasm_group
                         │
                         └──────────> kasm_docker_image ──> kasm_workspace ──> kasm_user
```

`kasm_credentials` must run before (or alongside) `kasm`, since `kasm`
consumes `kasm_admin_password`/`kasm_user_password`. `kasm_docker_image` must run
before `kasm_workspace` for a given workspace (the image must exist in the
DinD before it can be registered). `kasm_user` only needs `kasm_workspace`
to have run once anywhere on the host, to bootstrap the persistent API key
it reuses.

See [`examples/`](examples/) for runnable scripts covering the full
sequence, a custom domain, a no-TLS local deployment, and workspace
create/delete.

## Testing

`ansible-lint` passes at the `production` profile for every role in this
directory. Every role has a Molecule `molecule/default/` scenario:
- `linux_user`, `student` and `kasm_credentials` run `molecule test` for
  real (converge + idempotence + verify) in a disposable Docker container.
- `docker` and `kasm` touch host-kernel sysctl/kernel modules — running
  them inside a Molecule container would modify the **real kernel of
  whichever machine runs the test** (containers share the host kernel), so
  their scenarios exist for lint/structure only.
- `kasm_group`, `kasm_docker_image`, `kasm_workspace` and `kasm_user` all
  need a live, already-installed Kasm instance (Postgres, API) that a
  generic container doesn't have — their scenarios are lint/structure only
  too.

Real end-to-end verification for the roles above happens against actual
VMs — see the session's Fase A/B testing.
