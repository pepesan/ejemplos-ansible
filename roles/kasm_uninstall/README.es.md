# kasm_uninstall

Desinstala Kasm Workspaces de forma limpia: detiene y elimina el contenedor
DinD `kasm` (junto con sus redes/volúmenes internos), borra los datos
persistidos (base de datos, certificados autofirmados de Kasm, marker de
instalación, perfiles de sesión) y opcionalmente elimina el certificado real
de Let's Encrypt del host. Permite que el rol [`kasm`](../kasm/README.es.md)
vuelva a ejecutarse como una instalación realmente nueva, en vez de arreglar
a mano por SSH un servidor a medio romper.

No hay ningún rol de Galaxy que cubra esto, y el propio `install.sh` de Kasm
no tiene opción `--uninstall` — confirmado haciendo grep directamente sobre
un host real.

## Variables

| Variable | Valor por defecto | Propósito |
|---|---|---|
| `kasm_dir` | `/opt/kasm` | Debe coincidir con la misma variable usada por el rol `kasm` |
| `kasm_uninstall_remove_data` | `true` | Borra `kasm_dir/data` (BD, certs propios de Kasm, marker de instalación, perfiles) |
| `kasm_uninstall_remove_all` | `true` | También elimina `kasm_dir` entero (`compose.yaml`, `init/`) — inofensivo, `kasm` los recrea |
| `kasm_uninstall_remove_letsencrypt_certs` | `false` | Elimina `/etc/letsencrypt/live/<kasm_domain>` en el host. Desactivado por defecto: fuerza pedir un certificado nuevo en la siguiente instalación, y Let's Encrypt limita esas peticiones por dominio |
| `kasm_domain` | `{{ node_name }}.{{ kasm_base_domain }}` | Solo se lee si `kasm_uninstall_remove_letsencrypt_certs` es true |

## Idempotencia

Cada task es un `state: absent`, protegido por una comprobación previa de
existencia (`stat` sobre el compose file). Ejecutarlo dos veces seguidas no
hace nada la segunda vez.

## Ejemplo

```yaml
- hosts: ubuntu
  roles:
    - role: kasm_uninstall
```

Para forzar también un certificado TLS nuevo en la siguiente instalación:

```yaml
- hosts: ubuntu
  roles:
    - role: kasm_uninstall
      vars:
        kasm_uninstall_remove_letsencrypt_certs: true
        node_name: kasmcontabo
        kasm_base_domain: cursosdedesarrollo.com
```
