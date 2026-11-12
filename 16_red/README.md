# Ejemplos de configuración de red (netplan)

Dos formas de configurar la red de una máquina Ubuntu con netplan: copiando un fichero ya escrito (`tasks.yaml`)
o con un rol de Ansible Galaxy que lo genera a partir de variables (`ejecuta_rol.yaml`).
Los dos trabajan sobre el grupo `red` de `mi-inventario`.

## Instalación previa (obligatoria para `ejecuta_rol.yaml`)

`ejecuta_rol.yaml` usa el rol `mrlesmithjr.netplan`, que **no viene con Ansible** y hay que descargar de Ansible Galaxy
antes de ejecutarlo. Si no está instalado, el playbook falla con `the role 'mrlesmithjr.netplan' was not found`.

### Comando

```bash
ansible-galaxy role install mrlesmithjr.netplan
```

Se instala en `~/.ansible/roles`. Para comprobarlo:

```bash
ansible-galaxy role list | grep netplan
```

Versión: la última publicada en Galaxy es la `v0.4.3` (8 de abril de 2026). Para fijarla, o para actualizar una anterior:

```bash
ansible-galaxy role install mrlesmithjr.netplan,v0.4.3 --force
```

`tasks.yaml` no necesita nada más: solo usa módulos incluidos en Ansible.

## Los dos playbooks

Ejecuta los comandos desde este directorio (`ansible.cfg` selecciona `mi-inventario` y conecta como root).

| Playbook | Qué hace |
|---|---|
| `tasks.yaml` | Muestra varios *facts* de red (`ansible_facts`, `default_ipv4`, su dirección y `ansible_hostname`), pone el hostname `u1`, copia el fichero `50-cloud-init.yaml` a `/etc/netplan/50-cloud-init.yaml` y, **solo si el fichero cambió**, ejecuta `netplan apply` mediante un handler. |
| `ejecuta_rol.yaml` | Aplica el rol `mrlesmithjr.netplan` con `become: true`. En vez de copiar un fichero, el rol construye el YAML de netplan a partir de la variable `netplan_configuration` y lo escribe en `netplan_config_file`. |

```bash
ansible-playbook tasks.yaml
ansible-playbook ejecuta_rol.yaml
```

### `tasks.yaml` en detalle

- Los tres primeros `debug` sirven para ver los datos de red que Ansible descubre (`ansible_facts.default_ipv4.address` es la IP con la que sale a Internet).
- `hostname` cambia el nombre de la máquina. Es persistente: sobrevive a un reinicio.
- `copy` sube `50-cloud-init.yaml` (la configuración deseada: IP fija, puerta de enlace y DNS) con propietario root y permisos `0600` (netplan avisa si el fichero es legible por otros).
- `notify: start netplan` activa el handler solo cuando el fichero cambió, así que una segunda ejecución no vuelve a aplicar la red.

### `ejecuta_rol.yaml` en detalle

Variables del rol que usa el ejemplo:

| Variable | Valor | Significado |
|---|---|---|
| `netplan_enabled` | `true` | Activa la gestión de netplan por el rol. |
| `netplan_config_file` | `/etc/netplan/50-cloud-init.yaml` | Fichero que escribe el rol. |
| `netplan_renderer` | `networkd` | Servicio que aplica la red (`networkd` o `NetworkManager`). |
| `netplan_configuration` | diccionario `network:` | Contenido del fichero, con la misma estructura que el YAML de netplan. |

El rol guarda una copia de seguridad del fichero anterior junto al original (fichero `50-cloud-init.yaml.<número>.<fecha>~`).

## Precauciones

Estos playbooks **cambian la red de la máquina**; si la configuración es incorrecta, se pierde la conexión SSH y Ansible ya no puede alcanzar el servidor.

- **Comprueba el nombre de la interfaz.** Los ejemplos usan `enp5s0`, que es el nombre en una VM de LXD con Ubuntu 26.04. En otra máquina puede ser distinto (`eth0`, `ens3`...): míralo con `ip -br link` y cámbialo en `50-cloud-init.yaml` y en `ejecuta_rol.yaml`. Si el nombre no coincide, netplan no configura la interfaz real y la IP puede perderse al reiniciar.
- **Usa tu propia IP, puerta de enlace y DNS.** Los valores del repositorio son los de una VM concreta (`addresses`, `gateway4`, `nameservers`).
- `gateway4` está obsoleto en netplan reciente (avisa por pantalla); la alternativa actual es declarar una ruta por defecto en `routes`.
- Prueba primero en una máquina desechable, o con acceso por consola, y no lo lances contra un servidor remoto sin otra vía de acceso.
- Para deshacerlo, restaura el fichero de copia de seguridad `*~` de `/etc/netplan/` y ejecuta `netplan apply`, o vuelve a lanzar el playbook con la configuración original.
