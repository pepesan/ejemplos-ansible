# kasm_uninstall

Removes a Kasm Workspaces install cleanly: stops and removes the `kasm` DinD
container (and its nested networks/volumes), wipes the persisted app data
(database, Kasm's self-signed certs, install marker, session profiles), and
optionally removes the host's real Let's Encrypt certificate. Lets the
[`kasm`](../kasm/README.md) role run again as a genuine fresh install
afterwards, instead of hand-fixing a half-broken server over SSH.

Not covered by any Galaxy role, and Kasm's own `install.sh` has no
`--uninstall` flag — confirmed by grepping it directly on a live host.

## Variables

| Variable | Default | Purpose |
|---|---|---|
| `kasm_dir` | `/opt/kasm` | Must match the same variable used by the `kasm` role |
| `kasm_uninstall_remove_data` | `true` | Wipes `kasm_dir/data` (DB, Kasm's own certs, install marker, profiles) |
| `kasm_uninstall_remove_all` | `true` | Also removes `kasm_dir` itself (`compose.yaml`, `init/`) — harmless, `kasm` recreates both |
| `kasm_uninstall_remove_letsencrypt_certs` | `false` | Removes `/etc/letsencrypt/live/<kasm_domain>` on the host. Off by default: forces a brand new certificate request next install, and Let's Encrypt rate-limits that per domain |
| `kasm_domain` | `{{ node_name }}.{{ kasm_base_domain }}` | Only read when `kasm_uninstall_remove_letsencrypt_certs` is true |

## Idempotency

Every task is a `state: absent`, guarded by a prior existence check
(`stat` for the compose file). Running it twice in a row is a no-op the
second time.

## Example

```yaml
- hosts: ubuntu
  roles:
    - role: kasm_uninstall
```

To also force a brand new TLS certificate on the next install:

```yaml
- hosts: ubuntu
  roles:
    - role: kasm_uninstall
      vars:
        kasm_uninstall_remove_letsencrypt_certs: true
        node_name: kasmcontabo
        kasm_base_domain: cursosdedesarrollo.com
```
