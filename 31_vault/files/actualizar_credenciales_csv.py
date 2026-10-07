#!/usr/bin/env python3
"""Crea/actualiza una fila (por IP) en el CSV de credenciales de despliegues Kasm.

Se ejecuta en el controlador de Ansible (delegate_to: localhost), nunca en el
host remoto. Las contraseñas se pasan por variables de entorno, no por
argumentos de línea de comandos, para no dejarlas visibles en la lista de
procesos (ps aux) ni en el historial de shell.

Seguro para ejecuciones concurrentes: con forks>1 (o varios pases por
separado en días distintos) varias máquinas del inventario pueden lanzar este
script casi a la vez delegando en el mismo controlador. Se usa un fichero de
lock (flock, bloqueante) que cubre tanto la decisión de qué CSV usar/crear
como el ciclo de lectura-modificación-escritura completo, y la escritura final
es atómica (fichero temporal + os.replace) para no dejar el CSV a medias si
el proceso se interrumpe.
"""
import csv
import fcntl
import glob
import os
import sys
import argparse
from datetime import date

COLUMNS = [
    "ip",
    "alumno_password",
    "kasm_url",
    "kasm_admin_user",
    "kasm_admin_password",
    "kasm_user_user",
    "kasm_user_password",
]


def resolver_csv_path(directorio):
    """Reutiliza el fichero datos-acceso-<fecha>.csv ya existente (el de
    creación más antigua, por si hubiera varios) en vez de crear uno nuevo
    cada día. Solo si no existe ninguno, crea datos-acceso-<hoy>.csv.
    Debe llamarse siempre con el lock ya adquirido."""
    existentes = sorted(glob.glob(os.path.join(directorio, "datos-acceso-*.csv")))
    if existentes:
        return existentes[0]
    hoy = date.today().isoformat()
    return os.path.join(directorio, f"datos-acceso-{hoy}.csv")


def actualizar_fila(csv_path, ip, row):
    rows_by_ip = {}
    if os.path.exists(csv_path):
        with open(csv_path, newline="") as f:
            reader = csv.DictReader(f)
            for existing_row in reader:
                rows_by_ip[existing_row["ip"]] = existing_row

    rows_by_ip[ip] = row

    tmp_path = csv_path + ".tmp"
    with open(tmp_path, "w", newline="") as f:
        writer = csv.DictWriter(f, fieldnames=COLUMNS)
        writer.writeheader()
        for ip_key in rows_by_ip:
            writer.writerow(rows_by_ip[ip_key])
    os.chmod(tmp_path, 0o600)
    os.replace(tmp_path, csv_path)  # atómico dentro del mismo filesystem


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--csv-dir", required=True)
    parser.add_argument("--ip", required=True)
    parser.add_argument("--kasm-url", required=True)
    parser.add_argument("--kasm-admin-user", required=True)
    parser.add_argument("--kasm-user-user", required=True)
    args = parser.parse_args()

    row = {
        "ip": args.ip,
        "alumno_password": os.environ.get("ALUMNO_PASSWORD", ""),
        "kasm_url": args.kasm_url,
        "kasm_admin_user": args.kasm_admin_user,
        "kasm_admin_password": os.environ.get("KASM_ADMIN_PASSWORD", ""),
        "kasm_user_user": args.kasm_user_user,
        "kasm_user_password": os.environ.get("KASM_USER_PASSWORD", ""),
    }

    os.makedirs(args.csv_dir, exist_ok=True)
    lock_path = os.path.join(args.csv_dir, ".datos-acceso.lock")
    with open(lock_path, "w") as lock_file:
        fcntl.flock(lock_file, fcntl.LOCK_EX)  # bloqueante: espera su turno
        try:
            csv_path = resolver_csv_path(args.csv_dir)
            actualizar_fila(csv_path, args.ip, row)
        finally:
            fcntl.flock(lock_file, fcntl.LOCK_UN)

    print(f"OK Fila de {args.ip} actualizada en {csv_path}")


if __name__ == "__main__":
    sys.exit(main())
