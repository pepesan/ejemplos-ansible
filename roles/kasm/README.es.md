# kasm

Instala Kasm Workspaces sin registrar ningún workspace todavía (eso lo hace
[`kasm_workspace`](../kasm_workspace/README.es.md)): ajuste sysctl,
`/opt/kasm`, docker compose, el script de fix-e-instalación, modo de pruning
de imágenes a nivel de servidor, bloqueo de impresión en nginx y, por
defecto, un certificado real de Let's Encrypt. Los timeouts de sesión y el
bastionado por grupo los configura por separado
[`kasm_group`](../kasm_group/README.es.md), ejecutado
después de este rol.

No cubierto por ningún rol de Galaxy mantenido (se valoró
`monolithprojects.kasm_server` y se descartó — último commit en 2021, y aun
así solo cubría una instalación básica). Este rol se escribe desde cero, pero
delega las dos piezas genéricas que necesita en roles de Galaxy mantenidos
en vez de reimplementarlas:

- **Swap**: [`geerlingguy.swap`](https://github.com/geerlingguy/ansible-role-swap)
  (dependencia en `meta/main.yml`) — el instalador de Kasm necesita swap
  presente o falla.
- **Let's Encrypt**: [`geerlingguy.certbot`](https://github.com/geerlingguy/ansible-role-certbot)
  (dependencia) gestiona instalar certbot, emitir el cert inicial y el cron
  de renovación. `tasks/letsencrypt.yml` solo añade lo específico de Kasm:
  localizar su directorio real de certs dentro del contenedor, copiar ahí el
  cert emitido por certbot, reiniciar `kasm_proxy`, instalar el deploy-hook
  de renovación y verificar que HTTPS responde.

## TLS activado por defecto

`kasm_letsencrypt_enabled: true`. Requiere que `kasm_domain`
(`{{ node_name }}.{{ kasm_base_domain }}`) ya resuelva a este host y que el
puerto 80 esté libre para el challenge HTTP-01. Para entornos
locales/sin DNS, desactivar explícitamente:

```
-e kasm_letsencrypt_enabled=false
```

Kasm queda accesible con su certificado autofirmado.

## Variables

| Variable | Valor por defecto | Propósito |
|---|---|---|
| `kasm_dir` | `/opt/kasm` | Directorio de instalación |
| `kasm_version` / `kasm_image_tag` | `1.19.0` / `1.19.0-ls148` | Versión de Kasm / tag de la imagen del contenedor |
| `kasm_base_domain` | `example.com` (placeholder, sin valor por defecto sensato fuera de este proyecto) | Dominio base; fijarlo explícitamente por despliegue |
| `kasm_domain` | `{{ node_name }}.{{ kasm_base_domain }}` | Dominio completo por nodo |
| `kasm_letsencrypt_enabled` | `true` | Activar/desactivar TLS real |
| `letsencrypt_email` | `admin@{{ kasm_base_domain }}` | Email de la cuenta de certbot |
| `kasm_admin_password` / `kasm_user_password` | — | Las aporta [`kasm_credentials`](../kasm_credentials/README.es.md); ejecuta ese rol antes o fíjalas tú mismo |

## Dependencias

- `geerlingguy.swap`, `geerlingguy.certbot` (Galaxy, fijados en `roles/requirements.yml`)
- `community.docker` (compose, container exec)
- Requiere que `kasm_admin_password`/`kasm_user_password` ya estén definidas
  — normalmente ejecutando antes [`kasm_credentials`](../kasm_credentials/README.es.md).

## Ejemplo

```yaml
- hosts: ubuntu
  roles:
    - docker
    - kasm_credentials
    - role: kasm
      vars:
        kasm_base_domain: midominio.example.com
    - kasm_group
```
