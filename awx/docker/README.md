# AWX con Docker Compose: referencias

Estos laboratorios **no se copian aquí**: viven en el repositorio [`pepesan/docker-twitch`](https://github.com/pepesan/docker-twitch), carpeta `compose/`. Esta página dice cuál usar y en qué se diferencian.

| Laboratorio | Qué es | Versión de AWX |
|---|---|---|
| [`49_awx`](https://github.com/pepesan/docker-twitch/tree/main/compose/49_awx) | Un único contenedor «híbrido» que hace de control y de ejecución | Rama `devel` |
| [`50_awx_scalable`](https://github.com/pepesan/docker-twitch/tree/main/compose/50_awx_scalable) | Control node, un **hop node** de Receptor y uno o más **execution nodes** (se pueden añadir en caliente) | Rama `devel` |
| [`56_awx_stable`](https://github.com/pepesan/docker-twitch/tree/main/compose/56_awx_stable) | Copia de `49_awx` fijada a un **tag publicado**, con scripts que crean recursos y lanzan despliegues por API | Tag publicado `24.6.1` |

## Cuál elegir

- **Aprender AWX con una versión estable y reproducible:** `56_awx_stable`. Dos construcciones en fechas distintas dan la misma versión.
- **Ver la ejecución distribuida** (control, hop y nodos de ejecución): `50_awx_scalable`.
- **Probar lo último de AWX:** `49_awx`.

`49_awx` y `50_awx_scalable` construyen desde `devel`, la rama de desarrollo activo, que no es una release: puede romperse entre una construcción y la siguiente. En una prueba, la interfaz y la API de `devel` quedaron desincronizadas y el detalle de un proyecto devolvía `Bad Request` (error de `django-ansible-base`, no de la configuración local).

## Cómo se usan (resumen)

Los tres siguen el mismo orden de scripts. Desde su carpeta:

```bash
./00_init.sh            # genera secrets.env, clona AWX y compila la imagen
./01_launch_compose.sh  # levanta los contenedores
./02_create_admin.sh    # fija la contraseña de admin (cuando admin ya existe)
./08_build_ui.sh        # compila la interfaz web
```

| | `49_awx` | `56_awx_stable` |
|---|---|---|
| URL de la interfaz | `https://localhost:8043/` | `https://localhost:8044/` |
| Contenedores | `awx`, `awx_postgres`, `awx_redis` | `awx_stable`, `awx_stable_postgres`, `awx_stable_redis` |
| Compilar la interfaz | `make ui` (lo hace `08_build_ui.sh`) | `make ui-devel` (lo hace `08_build_ui.sh`) |

Los puertos distintos permiten tener ambos a la vez. La contraseña de `admin` está en `secrets.env` de cada laboratorio (no se versiona).

## Notas de `56_awx_stable`

- Para reconstruir el tag 24.6.1 hay que quitar la versión fija de `openssl` en su `Dockerfile` y fijar al commit de la fecha de la release las dependencias que instala desde `@devel` (`scripts/pins/24.6.1.txt`). Los scripts lo hacen solos.
- Sus scripts numerados crean el usuario, la credencial Machine, el proyecto Git, el inventario y las plantillas (`10`–`17`) y ejecutan el ciclo servidor web → Docker → contenedor → Compose sobre una máquina destino por SSH (`18`–`25`, `90`). `97` borra de AWX lo que crearon, `98` deja AWX y el destino como recién instalados y `99` destruye el laboratorio. Usan los playbooks de este repositorio (`03_servidorweb` y `14_docker/awx`).

## Relación con Kubernetes

Para desplegar AWX en Kubernetes con AWX Operator, mira [`../operator/`](../operator/README.md).
