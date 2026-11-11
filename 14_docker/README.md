# Ejemplos para Docker

## Instalación de la colección

Para que funcionen correctamente estos ejemplos debemos instalar la colección `community.docker`:

### Comando

```bash
ansible-galaxy collection install community.docker
```

## Pares crear / deshacer

Los playbooks están en `tasks/` y trabajan sobre el grupo `docker` del inventario (Ubuntu 26.04 Resolute en `mi-inventario`).
Con `community.docker` 5.x no hace falta instalar la librería Python `docker` en el servidor.
Ejecuta los comandos desde este directorio, por ejemplo `ansible-playbook tasks/docker_install.yaml`.

| Crea | Deshace | Qué hace |
|---|---|---|
| `docker_install.yaml` | `docker_uninstall.yaml` | Instala Docker CE y los plugins Compose/Buildx desde el repositorio oficial de Docker. Al desinstalar se purgan los paquetes y se borran el repositorio, la clave y los datos (`/var/lib/docker`, `/var/lib/containerd`, `/etc/docker`: se pierden imágenes y volúmenes). `curl` y `ca-certificates` se quitan solo si los instaló el ejemplo; si ya estaban en el sistema se respetan. |
| `docker_deploy.yaml` | `docker_undeploy.yaml` | Descarga `nginx` y arranca un contenedor con volumen persistente en el puerto **81:80** (para evitar conflictos si el puerto 80 del host ya está ocupado). Deshacer borra el contenedor, el volumen y la imagen. |
| `docker_deploy_mariadb.yaml` | `docker_undeploy_mariadb.yaml` | Descarga `mariadb:latest` y arranca un contenedor MariaDB con volumen persistente (`mariadb-data-volume`) y puerto **3306:3306**. Deshacer borra el contenedor, el volumen y la imagen. |
| `docker_complete.yaml` | (comentado dentro del propio fichero) | Despliegue de Nginx con red propia y la imagen fija `nginx:1.23.2`. |
| `docker_compose_deploy.yaml` | `docker_compose_undeploy.yaml` | Copia `files/compose.yaml` y levanta la pila con WordPress en el puerto **81:80** y MySQL 5.7 con `community.docker.docker_compose_v2`. Deshacer para los servicios sin eliminarlos. |
| `docker_compose_deploy_mariadb.yaml` | `docker_compose_undeploy_mariadb.yaml` | Copia `files/compose.mariadb.yaml` y levanta la pila MariaDB (puerto **3306**) con interfaz web Adminer (puerto **8080:8080**) con `community.docker.docker_compose_v2`. Deshacer para los servicios sin eliminarlos. |

> Ojo con los nombres: los `*_undeploy.yaml` borran o paran los **contenedores/servicios**; `docker_uninstall.yaml` desinstala **Docker** del servidor.
> Orden recomendado: `docker_install` → despliegues (`docker_deploy*` / `docker_compose_deploy*`) → `*_undeploy` → `docker_uninstall`.

## Ficheros Compose (`files/`)

- `files/compose.yaml`: Pila de WordPress (mapeado al puerto **81:80** para no colisionar con el puerto 80 del host) + base de datos MySQL 5.7.
- `files/compose.mariadb.yaml`: Pila de MariaDB (puerto **3306**) con interfaz web Adminer (puerto **8080:8080**).

### Nota sobre puertos en el host

Tanto el contenedor individual de Nginx (`docker_deploy.yaml`) como la aplicación WordPress en Compose (`compose.yaml`) exponen sus servicios en el puerto **81 del host (`81:80`)**. Esto evita fallos de tipo *address already in use* en máquinas que ya tengan el puerto 80 en uso por otros servicios o servidores web (por ejemplo, el Nginx del ejemplo 15).

## Uso

Debemos ejecutar Docker donde pueda crear contenedores (en la máquina virtual LXD o en local).
Para contenedores LXC (no VMs) se requiere activar anidamiento:

```bash
lxc profile create docker
lxc profile set docker security.nesting "true"
lxc profile set docker linux.kernel_modules "overlay, nf_nat, br_netfilter"
lxc launch Ubuntu2604 prueba-docker -p default -p docker
```
