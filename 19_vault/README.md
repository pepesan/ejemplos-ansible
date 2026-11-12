# 19_vault

Ejemplos de `ansible-vault`. Los ficheros cifrados del repositorio usan la contraseña de ejemplo
de `.vault_pass.txt.example` (es solo para el ejemplo; **en proyectos reales nunca subas la contraseña**).

## Preparación
```bash
cp .vault_pass.txt.example .vault_pass.txt    # ansible.cfg la lee de aquí; el fichero está en .gitignore
```

## Ejecutar
```bash
ansible-playbook simple.yaml          # variable cifrada dentro del playbook (encrypt_string)
ansible-playbook tasks.yaml           # el playbook entero está cifrado
ansible-playbook main.yaml            # ficheros cifrados: vars.yaml (vars_files) y vault.yaml (copy)
ansible-playbook main_uninstall.yaml  # borra lo que creó main.yaml
```
Sin `vault_password_file` en `ansible.cfg`, usa `--ask-vault-pass` o `--vault-password-file ./.vault_pass.txt`.

## Comandos de ansible-vault
```bash
ansible-vault encrypt_string --vault-password-file .vault_pass.txt 'foobar' --name 'the_secret'  # variable cifrada
ansible-vault encrypt tasks.yaml      # cifrar un fichero
ansible-vault view tasks.yaml         # verlo sin descifrarlo en disco
ansible-vault edit tasks.yaml         # editarlo
ansible-vault decrypt tasks.yaml      # dejarlo en claro
ansible-vault rekey tasks.yaml        # cambiar su contraseña
```

## Buenas prácticas
- El nombre de una tarea siempre se imprime: nunca pongas un secreto ahí. Usa `no_log: true` en las tareas que lo manejen.
- `.vault_pass.txt` no se sube al repositorio (`.gitignore`).
