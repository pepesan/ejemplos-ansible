# E2E test plan — real Contabo machine

Validates the roles in this directory against the existing, real production
machine already serving students via `31_vault`, instead of only against
disposable VMs/containers. This is a live host with public DNS pointing at
it — treat it with the same care as a production deployment.

**Inventory**: `inventory-prueba-kasm-contabo` (copied from
`31_vault/inventory-prueba-kasm-contabo`; matches the `inventory-*` pattern
in `.gitignore`, so it's never committed). `node_name=kasmcontabo`,
`ansible_user=root`. **Never write the real IP into any git-tracked
file.**

**Domain**: `kasm_base_domain=kasm.cursosdedesarrollo.com` (already the
default in `../../31_vault/group_vars/all/vars.yml`). With
`node_name=kasmcontabo`, `kasm_domain` resolves to
`kasmcontabo.kasm.cursosdedesarrollo.com` — matches the real URL already
live, `https://kasmcontabo.kasm.cursosdedesarrollo.com/`.

Before running anything: this machine already has Kasm installed and in
real use — confirm whether to run against this already-live instance
(reinstall) or reserve a maintenance window first, since `kasm` is not
purely additive on top of an existing install of the same host.

## 1. Install Galaxy dependencies (once)

```bash
ansible-galaxy role install -r roles/requirements.yml
```

## 2. Full install (Docker, student user, Kasm with real TLS, group settings)

```bash
cd roles/examples
ansible-playbook -i inventory-prueba-kasm-contabo site-kasm.yml \
  -e kasm_base_domain=kasm.cursosdedesarrollo.com \
  -e letsencrypt_email=pepesan@gmail.com \
  2>&1 | tee /tmp/e2e-contabo-install.log
```

Follow progress live from another terminal with
`tail -f /tmp/e2e-contabo-install.log`.

## 3. Verify real HTTPS

```bash
curl -sk -o /dev/null -w "%{http_code}\n" https://kasmcontabo.kasm.cursosdedesarrollo.com/
```

Expect `200` or `302`. Confirm the certificate is real (not self-signed):

```bash
openssl s_client -connect kasmcontabo.kasm.cursosdedesarrollo.com:443 \
  -servername kasmcontabo.kasm.cursosdedesarrollo.com </dev/null 2>/dev/null \
  | openssl x509 -noout -issuer
```

## 4. Second pass (idempotence check)

Re-run the exact same command as step 2. Nothing should report `changed`,
except possibly the credentials CSV task if its content genuinely differs.

```bash
ansible-playbook -i inventory-prueba-kasm-contabo site-kasm.yml \
  -e kasm_base_domain=kasm.cursosdedesarrollo.com \
  -e letsencrypt_email=pepesan@gmail.com \
  2>&1 | tee /tmp/e2e-contabo-install-2.log
```

## 5. Create a test workspace

```bash
ansible-playbook -i inventory-prueba-kasm-contabo kasm-workspace.yml \
  -e kasm_workspace_state=present \
  -e kasm_docker_image_name=pepesan/mi-ubuntu-resolute-kasm:1.0 \
  -e kasm_workspace_image=pepesan/mi-ubuntu-resolute-kasm:1.0 \
  -e '{"kasm_workspace_name": "E2E test workspace"}' \
  2>&1 | tee /tmp/e2e-contabo-workspace.log
```

Confirm from the admin panel that the session reaches `running`.

## 6. Delete the test workspace (cleanup)

```bash
ansible-playbook -i inventory-prueba-kasm-contabo kasm-workspace.yml \
  -e kasm_workspace_state=absent \
  -e kasm_docker_image_name=pepesan/mi-ubuntu-resolute-kasm:1.0 \
  -e kasm_workspace_image=pepesan/mi-ubuntu-resolute-kasm:1.0 \
  2>&1 | tee /tmp/e2e-contabo-workspace-delete.log
```

## Reporting results

Mark each step simply as validated or not, with its log as evidence — no
"validated, pending human confirmation" nuance, just a plain pass/fail per
step.
