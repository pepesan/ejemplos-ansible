# kasm_group

Idempotently configures Kasm group-level settings — session keepalive and
hardening (clipboard/downloads/uploads/printing) — for a given group.
Extracted out of what used to be a single "configure everything after
install" script so it can be run against any group, re-run safely, and
report accurate changed/unchanged status per setting.

Not covered by any Galaxy role, and there is no working public API for
this either: the public `update_setting` endpoint rejects every payload
tried, and these are per-group overrides stored in `group_settings`, not
the (encrypted) global settings. Writes go directly to Kasm's Postgres.

## Idempotency

Each setting's current value is read first; the UPSERT for a given setting
only runs when it differs from the desired value. A second run against an
already-configured group reports no changes — this is what Molecule's
`idempotence` check verifies for this role.

## Group lifecycle: create, never delete

`kasm_group_state: present` (the only supported value) creates the group
if it doesn't exist yet, then applies the settings. There is no `absent`:
deleting a Kasm group is deliberately **not implemented**, because:

- Kasm's `groups` table schema beyond `name`/`group_id`/`priority` has not
  been verified against a running instance, so a `DELETE` could leave
  orphaned `group_users`/`group_permissions` rows.
- A typo in `kasm_group_name` (e.g. targeting `"All Users"` by mistake)
  could delete a built-in group Kasm itself depends on, with no undo.

If you need to remove a group, do it from Kasm's admin UI.

## Variables

| Variable | Default | Purpose |
|---|---|---|
| `kasm_group_name` | `All Users` | Target group; re-run the role with a different value to configure another group |
| `kasm_group_state` | `present` | Only `present` is supported (see above) |
| `kasm_group_priority` | `100` | Used only when creating a new group |
| `kasm_group_keepalive_seconds` | `3600` | Session keepalive timeout |
| `kasm_group_keepalive_action` | `pause` | `pause` or `delete` when the keepalive expires |
| `kasm_group_allow_clipboard_down` / `_up` / `_seamless` | `false` | Clipboard hardening |
| `kasm_group_allow_downloads` / `_uploads` / `_printing` | `false` | File/printing hardening |

Image-pruning mode (`prune_images_mode`) is server-wide, not per group, and
stays as its own task in [`kasm`](../kasm/README.md) instead of living here.

## Example

```yaml
- hosts: ubuntu
  roles:
    - role: kasm_group
      vars:
        kasm_group_name: "Instructors"
        kasm_group_keepalive_seconds: 604800
        kasm_group_allow_printing: true
```
