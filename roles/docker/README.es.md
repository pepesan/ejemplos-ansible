# docker

Wrapper fino alrededor de [`geerlingguy.docker`](https://galaxy.ansible.com/ui/standalone/roles/geerlingguy/docker/)
(declarado como dependencia en `meta/main.yml`) que añade solo lo que ese rol
no cubre pero que la red de contenedores de Kasm necesita: los módulos de
kernel `overlay` / `br_netfilter`, y los valores sysctl
`net.ipv4.ip_forward` / `net.bridge.bridge-nf-call-iptables`.

## Por qué no reimplementar la instalación de Docker

`geerlingguy.docker` está activamente mantenido (v8.0.0, ene-2026) y ya
instala Docker Engine, el repo oficial, el plugin de Compose, gestiona el
servicio y añade usuarios al grupo `docker`. Reimplementar eso sería pura
duplicación.

## Variables

| Variable | Valor por defecto | Propósito |
|---|---|---|
| `docker_kernel_modules` | `[overlay, br_netfilter]` | Módulos de kernel cargados vía `modprobe` |
| `docker_sysctl_values` | ip_forward + bridge-nf-call-iptables | Valores sysctl necesarios para la red de contenedores |
| `docker_edition` | `ce` | Se pasa tal cual a `geerlingguy.docker` |
| `docker_users` | `["{{ ansible_user_id }}"]` | Usuarios añadidos al grupo `docker` |

Para la lista completa de variables de `geerlingguy.docker`, ver su
[README](https://github.com/geerlingguy/ansible-role-docker).

## Dependencias

- `geerlingguy.docker` (Galaxy, fijado en `roles/requirements.yml`)
- `community.general` (modprobe), `ansible.posix` (sysctl)

## Ejemplo

```yaml
- hosts: ubuntu
  roles:
    - docker
```
