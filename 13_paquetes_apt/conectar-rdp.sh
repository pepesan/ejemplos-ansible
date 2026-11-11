#!/bin/sh
set -eu

usage() {
    printf 'Uso: %s [HOST_O_DIRECCION_IP]\n' "$0" >&2
    printf 'Abre una conexión RDP como juan; introduce la contraseña en Remmina.\n' >&2
}

if [ "$#" -gt 1 ]; then
    usage
    exit 2
fi

address=${1:-10.207.154.161}
case "$address" in
    ''|-*|*[!A-Za-z0-9.:%_\[\]-]*)
        printf 'Dirección no válida.\n' >&2
        usage
        exit 2
        ;;
esac

if ! command -v remmina >/dev/null 2>&1; then
    printf 'No se encuentra Remmina; instálalo en el host antes de continuar.\n' >&2
    exit 127
fi

exec remmina -c "rdp://juan@${address}"
