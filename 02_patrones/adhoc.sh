#!/bin/bash
# mostrando el fichero de config
cat ansible.cfg
# mostrando el intenrory dns
cat inventory-dns
# ejecutando el módulo ping
ansible all -m ping
#ejecutando el módulo copy
ansible all -m copy -a "dest=/tmp/hosts src=/etc/hosts"
# ejercutando el módulo file
ansible all -m file -a "state=absent path=/tmp/hosts"