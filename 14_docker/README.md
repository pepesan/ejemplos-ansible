# Ejemplos para Docker
## Instalación de la colección
Para que funcionen correctamente estos ejemplos debemos instalar la colección community.docker 
### Comando
<code>$ ansible-galaxy collection install community.docker</code>
## Pares crear / deshacer
Los playbooks están en `tasks/` y trabajan sobre el grupo `docker` del inventario (Ubuntu 26.04 Resolute).
Con `community.docker` 5.x no hace falta instalar la librería Python `docker` en el servidor.
Ejecuta los comandos desde este directorio, por ejemplo `ansible-playbook tasks/docker_install.yaml`.

| Crea | Deshace | Qué hace |
|---|---|---|
| `docker_install.yaml` | `docker_uninstall.yaml` | Instala Docker CE y los plugins Compose/Buildx desde el repositorio oficial de Docker. Al desinstalar se purgan los paquetes y se borran el repositorio, la clave y los datos (`/var/lib/docker`, `/var/lib/containerd`, `/etc/docker`: se pierden imágenes y volúmenes). `curl` y `ca-certificates` se quitan solo si los instaló el ejemplo; si ya estaban en el sistema se respetan (quitarlos arrastraría `ubuntu-server`, `snapd`, etc.). |
| `docker_deploy.yaml` | `docker_undeploy.yaml` | Descarga `nginx` y arranca un contenedor con un volumen y el puerto 80. Deshacer borra el contenedor, el volumen y la imagen. |
| `docker_complete.yaml` | (comentado dentro del propio fichero) | Igual que el anterior pero con red propia y la imagen fija `nginx:1.23.2`. |
| `docker_compose_deploy.yaml` | `docker_compose_undeploy.yaml` | Copia `files/docker-compose.yaml` y levanta la pila (WordPress + MySQL) con `community.docker.docker_compose_v2`. Deshacer para los servicios sin eliminarlos. |

Ojo con los nombres: `docker_undeploy.yaml` borra los **contenedores**; `docker_uninstall.yaml` desinstala **Docker** del servidor.
Orden recomendado: `docker_install` → despliegues → `*_undeploy` → `docker_uninstall`.

## Uso
Debemos ejecutar docker donde pueda crear contenedore, no dentro de lxc, aunque hay una manera de hacerlo funcionar
Pero ejecutaremos los ejemplos en local
# Uso de LXC
Para usarlo en LXC debemos hacer que LXC permita el uso de docker:
$ lxc profile create docker
$ lxc profile set docker security.nesting "true"
$ lxc profile set docker linux.kernel_modules "overlay, nf_nat, br_netfilter"
Después debemos crear el contenedor usando ese perfil
lxc launch Ubuntu2004SSH prueba-docker -p default -p docker
## Uso remoto
Debemos conectar al host, por ejempo, con la variable de entorno DOCKER_HOST
