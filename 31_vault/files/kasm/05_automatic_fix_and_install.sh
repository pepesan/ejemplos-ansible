#!/bin/bash

set -e

# Antes de ejecutarlo
# Revisa el init/fix_and_install_kasm.sh para ver qué hace exactamente este script

docker compose exec kasm bash /scripts/fix_and_install_kasm.sh

# Apunta los datos que saque
#Kasm UI Login Credentials
#
#------------------------------------
#  username: admin@kasm.local
#  password: Admin1234!
#------------------------------------
#  username: user@kasm.local
#  password: User1234!
#------------------------------------
#
#Kasm Database Credentials
#------------------------------------
#  username: kasmapp
#  password: 3bG8bwLf9JZ5FcWYvrxf
#------------------------------------
#
#Kasm Manager Token
#------------------------------------
#  password: k3nALgrRqX5fXBshJDOj
#------------------------------------
#
#Service Registration Token
#------------------------------------
#  password: Rz4Qf1ntrRcvgU9crocC
#------------------------------------