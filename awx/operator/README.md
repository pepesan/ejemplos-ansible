# AWX Operator en Minikube

Cómo montar AWX en un clúster Kubernetes local con **AWX Operator**. Es un laboratorio para aprender y probar, no una instalación para producción.

Guía oficial de referencia: <https://docs.ansible.com/projects/awx-operator/en/latest/>

## Lo aprendido, en resumen

- **El operador y la instancia son dos pasos distintos.** Primero se instala el operador (`10_operador`); después se declara un recurso `kind: AWX` (`20_instancia_awx`) y es el operador quien crea PostgreSQL, la migración, `web` y `task`.
- **Fija el mismo tag en `ref` y en `newTag`.** Si no coinciden, los manifiestos y la imagen del operador serán de versiones distintas.
- **Kustomize descarga los manifiestos de GitHub**, así que hace falta Internet y la versión se decide en el `kustomization.yaml`, no con un `git checkout` local.
- **No declares AWX hasta que el operador esté listo.** Y no mezcles `apply -k` con `make deploy`.
- **La contraseña de `admin` no se elige: la genera el operador** y vive en el secreto `<instancia>-admin-password`.
- **Estado real del operador en la prueba:** AWX funcionó aunque el controller-manager se quedó en `1/2` por una imagen del sidecar que ya no se descarga.
- **Los flags `--cpus/--memory/--disk-size` son un perfil solicitado, no una cuota** que Kubernetes refleje.
- **Guarda el binario, el perfil y el `kubeconfig` fuera de `/tmp`**: se pierden al reiniciar.

## Versiones usadas

| Pieza | Valor |
|---|---|
| Minikube | v1.39.0 con el driver `docker` |
| AWX Operator | **2.19.1** (tag fijado en `ref` y en `newTag`) |
| AWX desplegado | **24.6.1** (los pods de migración se llaman `awx-demo-migration-24.6.1-…`) |
| Perfil de recursos solicitado | 2 CPU, 4 GiB de RAM, 50 GiB de disco (no es un mínimo oficial del operador) |

Antes de repetirlo comprueba la página de releases del operador y cambia el tag si quieres otra versión.

## Requisitos

- Docker en marcha (el driver `docker` de Minikube lo necesita).
- Minikube instalado. No hace falta `kubectl` aparte: se puede usar `minikube kubectl -- <comando>`.
- Salida a Internet: Kustomize descarga los manifiestos del operador desde GitHub y el clúster baja las imágenes.

## Estructura

```
operator/
├── 10_operador/          # solo el operador
│   └── kustomization.yaml
└── 20_instancia_awx/     # operador + una instancia AWX (recurso AWX)
    ├── kustomization.yaml
    └── awx-demo.yml
```

Los manifiestos se validaron contra un clúster Minikube real con `minikube kubectl -- apply -k <carpeta> --dry-run=server`.

## Paso a paso

Los comandos usan `minikube kubectl --`. Si tienes `kubectl`, sustitúyelo.

### 1. Crear el clúster

```bash
minikube start --driver=docker --cpus=2 --memory=4g --disk-size=50g
```

Espera al mensaje de finalización antes de seguir.

### 2. Comprobar que está sano

```bash
minikube status
minikube kubectl -- get nodes
minikube kubectl -- get pods -A
```

Deben estar `Running` el host, `kubelet` y `apiserver`, el nodo en `Ready` y los pods de `kube-system` saludables.

### 3. Instalar el operador

```bash
cd 10_operador
minikube kubectl -- apply -k .
minikube kubectl -- get pods -n awx
```

Kustomize instala los manifiestos del operador en el namespace `awx`. La guía oficial también permite `make deploy`: no mezcles ambos caminos.

### 4. Desplegar una instancia AWX

La instancia es un recurso `kind: AWX` que el operador reconcilia:

```yaml
apiVersion: awx.ansible.com/v1beta1
kind: AWX
metadata:
  name: awx-demo
spec:
  service_type: nodeport
```

`service_type: nodeport` expone el servicio en un puerto del nodo. `20_instancia_awx/kustomization.yaml` añade `awx-demo.yml` a los recursos del operador:

```bash
cd ../20_instancia_awx
minikube kubectl -- apply -k .
```

### 5. Seguir el progreso

```bash
minikube kubectl -- get pods -l app.kubernetes.io/managed-by=awx-operator -n awx
minikube kubectl -- get svc  -l app.kubernetes.io/managed-by=awx-operator -n awx
minikube kubectl -- logs -f deployments/awx-operator-controller-manager -c awx-manager -n awx
```

Primero aparece PostgreSQL, después la migración (`Completed`) y por último los pods `awx-demo-web` y `awx-demo-task`. Detén el seguimiento de logs con `Ctrl+C`.

### 6. Entrar en AWX

URL de acceso (la dirección depende del driver y de la red):

```bash
minikube service -n awx awx-demo-service --url
```

El usuario es `admin`. El operador guarda su contraseña en el secreto `awx-demo-admin-password` (se llama `<nombre de la instancia>-admin-password`):

```bash
minikube kubectl -- get secret awx-demo-admin-password -n awx \
  -o jsonpath='{.data.password}' | base64 -d; echo
```

No la copies en ficheros del repositorio.

### 7. Borrar el laboratorio

```bash
minikube delete
```

Si usas un perfil con nombre, añade `-p <perfil>`.

## Resultado observado

En la prueba, con los manifiestos de esta carpeta:

| Recurso | Estado |
|---|---|
| `awx-demo-postgres-15-0` | `1/1` Running |
| `awx-demo-web` | `3/3` Running |
| `awx-demo-task` | `4/4` Running |
| `awx-demo-migration-24.6.1-…` | `Completed` |
| Interfaz web (NodePort) | responde HTTP 200 |
| `awx-operator-controller-manager` | `1/2`, con un contenedor en `ErrImagePull` (ver abajo) |

## Problemas encontrados

### El controller-manager no llega a `2/2`

El pod `awx-operator-controller-manager` queda en `1/2` porque el sidecar `gcr.io/kubebuilder/kube-rbac-proxy:v0.15.0` falla con `ErrImagePull` (la imagen ya no se encuentra en ese registro). El contenedor `awx-manager` sí funcionó y AWX se desplegó. No se probó ninguna sustitución de esa imagen.

### Los flags de recursos no limitan lo que ve el nodo

Con `--cpus=2 --memory=4g --disk-size=50g`, `minikube kubectl -- describe node` anuncia los recursos de la máquina anfitriona (en la prueba, 32 CPU y unos 129 GiB), y `minikube ssh -- df -h /` muestra el disco del anfitrión. Lo que sí se aplicó fue un límite de CPU (un conjunto de 2 CPU) y de memoria (4 GiB) sobre el contenedor Docker que hace de nodo; Kubernetes no lo refleja en lo que anuncia. Trata `2/4/50` como perfil solicitado y no como cuota garantizada. Para comprobarlo en tu equipo: `docker inspect <contenedor del nodo> --format '{{.HostConfig.CpusetCpus}} {{.HostConfig.Memory}}'`.

### `kubectl` pide usuario: `Please enter Username: error: EOF`

El `kubeconfig` no apunta al clúster. Regenera el contexto del perfil:

```bash
minikube -p <perfil> update-context
```

Si usas un `MINIKUBE_HOME` o un `KUBECONFIG` distintos de los de por defecto, exporta **las mismas variables en cada comando**.

### Un binario o un perfil en `/tmp` desaparece al reiniciar

En muchos sistemas `/tmp` es `tmpfs`. Si guardas ahí el binario de Minikube, el perfil y el `kubeconfig`, se pierden al reiniciar y el clúster deja de poder gestionarse. Usa un directorio persistente (por ejemplo, bajo `~/.local/share`).

## Relación con los laboratorios de Docker Compose

Para AWX sin Kubernetes (un único proceso con todo dentro), mira [`../docker/`](../docker/README.md).
