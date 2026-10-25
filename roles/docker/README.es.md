# docker

Wrapper fino alrededor de [`geerlingguy.docker`](https://galaxy.ansible.com/ui/standalone/roles/geerlingguy/docker/)
(incluido desde `tasks/main.yml`) que añade lo que ese rol no cubre pero que
Kasm necesita: los módulos de kernel `overlay` / `br_netfilter`, los valores
sysctl `net.ipv4.ip_forward` / `net.bridge.bridge-nf-call-iptables`, y una
preferencia de IPv4 sobre IPv6 en la resolución de nombres aplicada *antes* de
instalar nada.

## Orden de ejecución

1. **Preferir IPv4 sobre IPv6** (`/etc/gai.conf`).
2. `geerlingguy.docker`, mediante `include_role`.
3. Módulos de kernel, valores sysctl y `python3-docker`.

`geerlingguy.docker` se incluye a propósito desde las tareas y **no** como
dependencia de `meta`: las dependencias siempre se ejecutan antes que las
tareas propias del rol, y el paso 1 tiene que ir antes de los `apt` del
paso 2.

## Preferencia IPv4

Escribe `precedence ::ffff:0:0/96  100` en `/etc/gai.conf`, de modo que glibc
ordena IPv4 por encima de IPv6 cuando un nombre resuelve a ambas. Útil en VPS
que anuncian una ruta IPv6 que no funciona (`apt`, `curl` o `git` esperan
decenas de segundos a que IPv6 caduque antes de usar IPv4).

- **No** desactiva IPv6: un destino solo-IPv6 sigue funcionando.
- Solo afecta a programas que resuelven mediante glibc. Los binarios en Go,
  como `dockerd`, tienen su propio resolvedor e ignoran `gai.conf`, así que un
  `docker pull` lento no lo arregla esto.
- No llega a los contenedores (cada uno tiene su propio `/etc/gai.conf`).
- Idempotente: el `gai.conf` de fábrica trae la directiva comentada, así que
  la primera ejecución añade una línea y las siguientes no cambian nada.

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
| `docker_prefer_ipv4` | `true` | Aplica la preferencia IPv4 descrita arriba. `false` mantiene el valor de la distribución |
| `docker_prefer_ipv4_gai_conf` | `/etc/gai.conf` | Fichero a editar |
| `docker_prefer_ipv4_precedence` | `100` | Precedencia de las direcciones IPv4 mapeadas (glibc: 35; IPv6 nativo: 40; por encima de 40 invierte la preferencia) |
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
