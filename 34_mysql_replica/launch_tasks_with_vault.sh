#!/bin/bash
# Comprobacion de conexión  (hecho)
ansible-playbook 00_ping.yaml
# actualización de sistema (hecho)
ansible-playbook 07_system_update.yaml
# reinicio de la máquina
ansible-playbook 20_reboot.yaml
# Instalación de mysql server y client (hecho)
ansible-playbook 21_install_mysql_server_client.yaml
# Configuración de mysql source (hecho)
ansible-playbook 22_config_mysql_source.yaml
# Añadimos usuario replica en mysql source (hecho)
ansible-playbook 23_config_replica_user_on_mysql_source.yaml
# comprobamos que podemos conectar con usuario replica en mysql source (hecho)
ansible-playbook 24_config_mysql_replica.yaml
# Configura la replicación en mysql replica (hecho)
ansible-playbook 25_config_replica_on_mysql_replica.yaml
# Mete bbdd tabla y registros mysql source (hecho)
ansible-playbook 26_add_data_on_mysql_source.yaml
# Comprueba que los datos se han replicado en mysql replica (hecho)
ansible-playbook 27_check_data_on_mysql_replica.yaml






