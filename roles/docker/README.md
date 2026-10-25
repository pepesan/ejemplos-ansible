# docker

Thin wrapper around [`geerlingguy.docker`](https://galaxy.ansible.com/ui/standalone/roles/geerlingguy/docker/)
(included from `tasks/main.yml`) that adds what that role does not cover but
Kasm needs: the `overlay` / `br_netfilter` kernel modules, the
`net.ipv4.ip_forward` / `net.bridge.bridge-nf-call-iptables` sysctl values,
and a preference for IPv4 over IPv6 in name resolution applied *before* anything
is installed.

## Order of execution

1. **Prefer IPv4 over IPv6** (`/etc/gai.conf`).
2. `geerlingguy.docker`, through `include_role`.
3. Kernel modules, sysctl values and `python3-docker`.

`geerlingguy.docker` is deliberately included from the tasks and **not** a
`meta` dependency: dependencies always run before the role's own tasks, and
step 1 has to precede the `apt` installs of step 2.

## IPv4 preference

Writes `precedence ::ffff:0:0/96  100` into `/etc/gai.conf`, so glibc ranks
IPv4 above IPv6 when a name resolves to both. Useful on VPS providers that
advertise an IPv6 route that does not work (`apt`, `curl` or `git` wait tens of
seconds for IPv6 to time out before using IPv4).

- It does **not** disable IPv6: an IPv6-only destination keeps working.
- It only affects programs that resolve through glibc. Go binaries such as
  `dockerd` have their own resolver and ignore `gai.conf`, so a slow
  `docker pull` is not fixed by this.
- It does not reach inside containers (each has its own `/etc/gai.conf`).
- Idempotent: the stock `gai.conf` ships the directive commented out, so the
  first run appends one line and later runs change nothing.

## Why not reimplement Docker installation

`geerlingguy.docker` is actively maintained (v8.0.0, Jan 2026) and already
installs Docker Engine, the official repo, the Compose plugin, manages the
service, and adds users to the `docker` group. Reimplementing that would be
pure duplication.

## Variables

| Variable | Default | Purpose |
|---|---|---|
| `docker_kernel_modules` | `[overlay, br_netfilter]` | Kernel modules loaded via `modprobe` |
| `docker_sysctl_values` | ip_forward + bridge-nf-call-iptables | sysctl values required for container networking |
| `docker_prefer_ipv4` | `true` | Apply the IPv4 preference described above. `false` keeps the distribution default |
| `docker_prefer_ipv4_gai_conf` | `/etc/gai.conf` | File to edit |
| `docker_prefer_ipv4_precedence` | `100` | Precedence of IPv4-mapped addresses (glibc default 35, native IPv6 40; above 40 flips the preference) |
| `docker_edition` | `ce` | Passed through to `geerlingguy.docker` |
| `docker_users` | `["{{ ansible_user_id }}"]` | Users added to the `docker` group |

See [`geerlingguy.docker`'s README](https://github.com/geerlingguy/ansible-role-docker)
for its full variable list.

## Dependencies

- `geerlingguy.docker` (Galaxy, pinned in `roles/requirements.yml`)
- `community.general` (modprobe), `ansible.posix` (sysctl)

## Example

```yaml
- hosts: ubuntu
  roles:
    - docker
```
