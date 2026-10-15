# ipv4_preference

Makes glibc prefer IPv4 over IPv6 when a name resolves to both, by writing
`precedence ::ffff:0:0/96  100` into `/etc/gai.conf`.

Useful on VPS providers where the IPv6 route is advertised in DNS but does not
actually work: `apt`, `curl` or `git` then wait tens of seconds for IPv6 to
time out before falling back to IPv4.

## What it does and does not do

- Changes the address *ordering* in `getaddrinfo(3)`. It does **not** disable
  IPv6: an IPv6-only destination keeps working.
- Only affects programs that resolve through glibc (`apt`, `curl`, `git`,
  Python...). Go binaries — `dockerd` among them — use their own resolver and
  ignore `gai.conf`, so a slow `docker pull` is not fixed by this role.
- Does not reach into containers: each one has its own `/etc/gai.conf`.

## Variables

| Variable | Default | Purpose |
|---|---|---|
| `ipv4_preference_enabled` | `true` | Set to `false` to skip the role entirely |
| `ipv4_preference_gai_conf` | `/etc/gai.conf` | File to edit |
| `ipv4_preference_precedence` | `100` | Precedence of IPv4-mapped addresses. glibc's default is 35, below native IPv6 (40); anything above 40 flips the preference |

## Idempotency

A single `lineinfile` anchored on the *uncommented* directive. The stock
`gai.conf` ships it commented out, so the first run appends one line and
later runs find that same line and change nothing.

## Example

```yaml
- hosts: ubuntu
  roles:
    - role: ipv4_preference
```

The [`docker`](../docker/README.md) role already declares it as its first
dependency, so it runs before `geerlingguy.docker` installs anything through
`apt`; listing it explicitly is only needed in playbooks that do not use
`docker`.
