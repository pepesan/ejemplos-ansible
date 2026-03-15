USER="root"   # cambia por el usuario remoto si no es root

# una ip por linea
IPS=(
X.X.X.X
)

KEY="$HOME/.ssh/id_ed25519.pub"

# Pedir contraseña por consola sin mostrarla
read -s -p "Introduce la contraseña SSH: " PASSWORD

for ip in "${IPS[@]}"; do
    echo "Copiando clave a $ip..."
    sshpass -p "$PASSWORD" \
        ssh-copy-id \
        -i "$KEY" \
        -o StrictHostKeyChecking=no \
        -o UserKnownHostsFile="$HOME/.ssh/known_hosts" \
        "$USER@$ip"
done
