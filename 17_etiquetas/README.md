# Ejemplos de uso de Etiquetas en Ansible

# Uso
ansible-playbook -i inventory --tags copia
ansible-playbook -i inventory --tags copia,hostname
ansible-playbook -i inventory --skip-tags copia
ansible-playbook -i inventory --tags untagged
