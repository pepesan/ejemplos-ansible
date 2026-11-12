# 20_async

Ejemplo de tareas asíncronas (`async` / `poll` / `async_status`). Solo ejecuta `sleep` en la VM de
`mi-inventario`; no cambia nada. Ejecuta los comandos desde este directorio.

```bash
ansible-playbook tasks.yaml                          # todo
ansible-playbook tasks.yaml --tags sincrona          # async con poll: espera a que acabe
ansible-playbook tasks.yaml --tags segundo_plano     # poll 0 + async_status
ansible-playbook tasks.yaml --tags timeout           # se supera el tiempo de async y falla (controlado)
```

| Parámetro | Efecto |
|---|---|
| `async: N` | Tiempo máximo que puede tardar la tarea; si lo supera, falla. |
| `poll: N` | Cada cuántos segundos comprueba Ansible si terminó (`N > 0`: espera). |
| `poll: 0` | No espera: la tarea sigue en segundo plano y se comprueba luego con `async_status`. |
| `async_status` | Consulta un job id (`ansible_job_id`) hasta que `finished` sea verdadero. |
