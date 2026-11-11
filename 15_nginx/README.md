# Ejemplos de Nginx

Despliegue y configuración automatizada de un servidor web Nginx con endpoint de métricas (`stub_status`), página personalizada y reglas de cortafuegos UFW.

Los playbooks trabajan sobre el grupo `webservers` del inventario (apuntando a la máquina virtual Ubuntu 26.04 Resolute en `mi-inventario`).

## Requisitos

Requiere la colección `community.general` (para los módulos `ufw` y `nginx_status_info`):

```bash
ansible-galaxy collection install community.general
```

## Pares crear / deshacer

Ejecuta los comandos desde este directorio. `ansible.cfg` selecciona `./mi-inventario` y conecta como usuario `root`.

| Crear | Deshacer | Qué hace |
|---|---|---|
| `tasks.yaml` | `undo.yaml` | Instala `nginx` y `elinks`, abre puertos (22, 80, 443) y activa UFW, copia la configuración del virtual host `default` con `/nginx_status`, despliega `index.html`, asegura el servicio arrancado y consulta estadísticas HTTP con `community.general.nginx_status_info`. La desinstalación detiene el servicio, purga paquetes creados por el ejemplo, restaura la configuración original y devuelve UFW a su estado previo. |

### Ejecución

```bash
# Aplicar instalación y configuración
ansible-playbook tasks.yaml

# Segunda pasada para comprobar idempotencia (changed=0)
ansible-playbook tasks.yaml

# Revertir todos los cambios y restaurar el estado original
ansible-playbook undo.yaml
```

## Verificación manual

Desde el host o dentro de la máquina se puede verificar la respuesta del servidor web y las estadísticas:

```bash
# Página de bienvenida
curl http://10.207.154.161/

# Estadísticas del módulo stub_status (solo local por seguridad)
ssh root@10.207.154.161 'curl http://127.0.0.1/nginx_status'
```
