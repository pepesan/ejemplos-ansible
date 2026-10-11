# kasm_workspace

Creates or deletes a Kasm workspace (a registered image), chosen via
`kasm_workspace_state: present|absent`. Requires Kasm already installed
(run [`kasm`](../kasm/README.md) first).

Not covered by any Galaxy role or collection. Kasm's public API covers more
of this than first assumed: workspace creation (`create_image`) and the
existence check (`get_images`) both use it. Still direct-SQL, though:
deleting a workspace (no public `delete_image` endpoint exists), and zone
lookup for Session Staging (no public `get_zones` endpoint). Staging itself
*does* have a public API (`create_staging_config`/`update_staging_config`)
— not yet switched over because its exact request schema hasn't been
verified against a running instance; tracked as a follow-up (see the
session plan). This mix of API calls and direct SQL is why
`files/create_workspace.sh` and `files/delete_workspace.sh` stay as bash
scripts wrapped by the role instead of being rewritten as
`ansible.builtin.uri` tasks — the logic (API key bootstrap with file
locking, conditional staging, response parsing) is too involved for that to
simplify anything.

## Variable groups

Variables are grouped by what they configure, not just alphabetically:

- **Workspace core**: `kasm_workspace_image`, `_name`, `_desc`, `_cores`,
  `_memory_gb`, `_privileged`, `_gpu_count`, `_session_time_limit`,
  `_category`, `_enabled`.
- **`_profile`** — the workspace's persistent home directory:
  `kasm_workspace_profile_path`. Must contain `{username}` or `{user_id}`;
  empty disables persistence.
- **`_group`** — zone/group-level Session Staging (pre-warms sessions ahead
  of time): `kasm_workspace_group_staging_enabled`, `_num_sessions`,
  `_expiration_hours`, `_zone_name`. Staging lives at the zone level in
  Kasm, not per workspace, which is why these are their own family instead
  of flat alongside the workspace-core variables. Requires the target zone
  to already have a fixed `proxy_hostname` configured (not `$request_host$`)
  — if not, the script skips staging with a warning instead of failing the
  whole workspace creation.
- **`state: absent` only**: `kasm_workspace_clean_all` (delete every
  registered workspace instead of one), `kasm_workspace_delete_persistent_data`
  (defaults to `true` — irreversible, see warning below).

## Deleting persistent data

`kasm_workspace_delete_persistent_data` defaults to `true` on purpose:
persistent profiles are indexed by `image_id`, not by workspace, so leaving
them behind can leak a previous image version's files into a new workspace
that reuses the same `image_id`. Set to `false` to keep them (e.g. when
reinstalling a workspace but keeping users' home directories).

## Example

```yaml
- hosts: ubuntu
  roles:
    - role: kasm_workspace
      vars:
        kasm_workspace_state: present
        kasm_workspace_image: "user/my-image:1.0"
        kasm_workspace_name: "My workspace"
        kasm_workspace_profile_path: "/opt/kasm_profiles/{user_id}/{image_id}"
```

```yaml
# Delete it again
- hosts: ubuntu
  roles:
    - role: kasm_workspace
      vars:
        kasm_workspace_state: absent
        kasm_workspace_image: "user/my-image:1.0"
```
