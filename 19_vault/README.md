# Ejemplo de Vault
# creación de variable cifrada
ansible-vault encrypt_string --vault-password-file a_password_file 'foobar' --name 'the_secret'
# Ejecución del tasks con vault integrado
ansible-playbook edit tasks.yaml --ask-vault-pass
## cifrado de fichero tasks.yaml
ansible-vault encrypt tasks.yaml
## Uso de variable cifrada
ansible-playbook -i inventory tasks.yaml -vvvv --vault-password-file ./.vault_pass.txt
## Usando el ansible.cfg
ansible-playbook tasks.yaml
