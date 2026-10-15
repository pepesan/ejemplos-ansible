# ipv4_preference

Hace que glibc prefiera IPv4 sobre IPv6 cuando un nombre resuelve a ambas,
escribiendo `precedence ::ffff:0:0/96  100` en `/etc/gai.conf`.

Útil en VPS donde la ruta IPv6 aparece en el DNS pero no funciona de verdad:
`apt`, `curl` o `git` esperan entonces decenas de segundos a que IPv6 caduque
antes de recurrir a IPv4.

## Qué hace y qué no

- Cambia el *orden* de las direcciones en `getaddrinfo(3)`. **No** desactiva
  IPv6: un destino solo-IPv6 sigue funcionando.
- Solo afecta a programas que resuelven mediante glibc (`apt`, `curl`, `git`,
  Python...). Los binarios en Go — `dockerd` entre ellos — usan su propio
  resolvedor e ignoran `gai.conf`, así que un `docker pull` lento no lo
  arregla este rol.
- No llega a los contenedores: cada uno tiene su propio `/etc/gai.conf`.

## Variables

| Variable | Valor por defecto | Propósito |
|---|---|---|
| `ipv4_preference_enabled` | `true` | Poner a `false` para saltarse el rol por completo |
| `ipv4_preference_gai_conf` | `/etc/gai.conf` | Fichero a editar |
| `ipv4_preference_precedence` | `100` | Precedencia de las direcciones IPv4 mapeadas. El valor por defecto de glibc es 35, por debajo de IPv6 nativo (40); cualquier valor por encima de 40 invierte la preferencia |

## Idempotencia

Un único `lineinfile` anclado a la directiva *sin comentar*. El `gai.conf` de
fábrica la trae comentada, así que la primera ejecución añade una línea y las
siguientes encuentran esa misma línea y no cambian nada.

## Ejemplo

```yaml
- hosts: ubuntu
  roles:
    - role: ipv4_preference
```

El rol [`docker`](../docker/README.es.md) ya lo declara como su primera
dependencia, de modo que se ejecuta antes de que `geerlingguy.docker` instale
nada con `apt`; solo hace falta listarlo explícitamente en playbooks que no
usen `docker`.
