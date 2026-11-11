# 13_paquetes_apt

Examples target Ubuntu 26.04 Resolute on the LXD VM in `mi-inventario`.
Run commands from this directory; `ansible.cfg` selects that inventory and connects as root. `ansible.cfg` and the VM entry are shared with `12_ficheros`.

Install the required collection before using account creation:

```bash
ansible-galaxy collection install ansible.posix
```

## Apply / reverse pairs

| Apply | Reverse | Scope / safety |
|---|---|---|
| `ubuntu.yaml` | `ubuntu-undeploy.yaml` | Replaces the stock Ubuntu 26.04 deb822 source while active; backs it up and restores it byte-for-byte on reverse. Resolute only. |
| `docker-install.yaml` | `docker-undeploy.yaml` | Installs Docker CE and Compose/Buildx plugins. The reverse removes these packages, its source and key; it deliberately keeps `/var/lib/docker` data and generic prerequisites (`curl`, `ca-certificates`). |
| `account-create.yaml` | `account-delete.yaml` | Creates `juan`, password `mipassword`, and a local Ed25519 key at `~/.ssh/id_ed25519_13_paquetes_apt`; authorizes its public key and verifies SSH login as `juan`. Reverse deletes `juan` and `/home/juan`, not the local private key. It assumes SSH already works for Ansible; it does not install an SSH server. |
| `sdkman-install.yaml` | `sdkman-uninstall.yaml` | Requires the existing `alumno` account and refuses to overwrite an SDKMAN installation not owned by this example. Installs SDKMAN, Java, Gradle and Maven. Reverse removes the owned SDKMAN tree and restores `alumno`'s original `.bashrc`; system prerequisites stay installed. |
| `xrdp-install.yaml` | `xrdp-uninstall.yaml` | Requires the existing `juan` account created by `account-create.yaml`. Installs the Ubuntu desktop meta-package and XRDP, configures RDP TCP/3389 only when UFW is active, and saves prior state for reversal. The reverse removes the owned meta-packages, purges XRDP config, and restores prior service/firewall/startwm state; auto-installed dependencies are left to avoid removing packages predating this example. It does not delete the account. |
| `upgrade-reboot.yaml` | `upgrade-reboot-undo.yaml` | Takes/replaces the dedicated LXD snapshot `ansible-13-before-upgrade`, upgrades Ubuntu and reboots if packages changed. Reverse restores the VM snapshot and discards **all VM changes made since that snapshot**. Requires `lxc` on the control host and the VM name `lxd-vm-auto`. |

Example:

```bash
ansible-playbook ubuntu.yaml
ansible-playbook ubuntu-undeploy.yaml
```

## XRDP client on the host

`conectar-rdp.sh [host-or-ip]` opens Remmina as `juan`; enter the password in Remmina. It defaults to the VM IP in `mi-inventario` and does not store credentials.

```bash
./conectar-rdp.sh
./conectar-rdp.sh 10.207.154.161
```

Create the account and install XRDP before connecting; reverse them in the opposite order:

```bash
ansible-playbook account-create.yaml
ansible-playbook xrdp-install.yaml
./conectar-rdp.sh

ansible-playbook xrdp-uninstall.yaml
ansible-playbook account-delete.yaml
```

`upgrade-reboot.yaml` is intentionally not a package-by-package downgrade:
the LXD snapshot is its real rollback.
