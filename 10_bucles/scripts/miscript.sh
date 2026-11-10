#!/bin/bash
# Cuenta cuántas veces se ha ejecutado. El fichero contador se pasa como primer argumento.
file="${1:-/tmp/count.cnt}"

if [ -e "${file}" ]; then
    count=$(cat "${file}")
else
    count=0
fi

((count++))

echo "${count}" > "${file}"

echo "Loaded ${count} times"
