# docker

Thin wrapper around [`geerlingguy.docker`](https://galaxy.ansible.com/ui/standalone/roles/geerlingguy/docker/)
(declared as a dependency in `meta/main.yml`) that adds the two things that
role does not cover but Kasm's container networking needs: the `overlay` /
`br_netfilter` kernel modules, and the `net.ipv4.ip_forward` /
`net.bridge.bridge-nf-call-iptables` sysctl values.

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
