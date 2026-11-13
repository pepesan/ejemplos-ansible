# AWX

Material de apoyo para desplegar y probar [AWX](https://github.com/ansible/awx) en local.

| Carpeta | Contenido |
|---|---|
| [`operator/`](operator/README.md) | Montar AWX en Kubernetes con **AWX Operator** sobre Minikube: pasos, manifiestos Kustomize y problemas encontrados |
| [`docker/`](docker/README.md) | Referencias a los laboratorios de **Docker Compose** del repositorio `docker-twitch` (`49_awx`, `50_awx_scalable` y `56_awx_stable`) |

Todos son entornos de **laboratorio**, no instalaciones para producción.

## Playbooks para usar con AWX

Los playbooks de este repositorio que se ejecutan desde AWX tienen en cuenta dos limitaciones:

- AWX **no lista** los playbooks de un directorio llamado `tasks/`. Por eso `14_docker/awx/` contiene envoltorios con una línea `import_playbook: ../tasks/<nombre>.yaml`. Más detalle en [`14_docker/README.md`](../14_docker/README.md).
- La imagen de ejecución no incluye `community.docker`; [`collections/requirements.yml`](../collections/requirements.yml) la declara y AWX la instala al sincronizar el proyecto.
