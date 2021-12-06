# Ejemplos para Docker
## Instalación
Para que funcionen correctamente estos ejemplos debemos instalar la colección community.docker 
### Comando
<code>$ ansible-galaxy collection install community.docker</code>
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
