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


def sanitizar_prefijo(proyecto_formativo):
    """Convierte el nombre de proyecto formativo en un slug seguro para
    nombre de fichero (sin espacios ni caracteres raros)."""
    if not proyecto_formativo:
        return ""
    slug = "".join(c if c.isalnum() else "-" for c in proyecto_formativo.strip())
    while "--" in slug:
        slug = slug.replace("--", "-")
    return slug.strip("-").lower()


def resolver_csv_path(directorio, proyecto_formativo=""):
    """Reutiliza el fichero datos-acceso[-<proyecto>]-<fecha>.csv ya
    existente (el de creación más antigua, por si hubiera varios) en vez de
    crear uno nuevo cada día. Solo si no existe ninguno, crea uno con la
    fecha de hoy. El prefijo de proyecto formativo evita mezclar en el mismo
    CSV credenciales de cursos distintos desplegados en paralelo; sin
    prefijo se mantiene el nombre de fichero clásico (compatibilidad con
    CSV generados antes de que existiera este parámetro).
    Debe llamarse siempre con el lock ya adquirido."""
    prefijo = sanitizar_prefijo(proyecto_formativo)
    if prefijo:
        patron = f"datos-acceso-{prefijo}-*.csv"
    else:
        # Sin prefijo: solo ficheros "datos-acceso-<fecha>.csv" clásicos,
        # nunca los de otro proyecto formativo (que llevan su propio prefijo
        # intercalado antes de la fecha).
        patron = "datos-acceso-[0-9]*.csv"
    existentes = sorted(glob.glob(os.path.join(directorio, patron)))
    if existentes:
        return existentes[0]
    hoy = date.today().isoformat()
    nombre = f"datos-acceso-{prefijo}-{hoy}.csv" if prefijo else f"datos-acceso-{hoy}.csv"
    return os.path.join(directorio, nombre)


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
    parser.add_argument(
        "--proyecto-formativo",
        default="",
        help="Prefijo opcional (curso/proyecto formativo) para no mezclar "
             "en el mismo CSV credenciales de cursos distintos desplegados "
             "en paralelo. Sin este argumento se usa el nombre de fichero "
             "clásico (datos-acceso-<fecha>.csv).",
    )
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

    prefijo = sanitizar_prefijo(args.proyecto_formativo)

    os.makedirs(args.csv_dir, exist_ok=True)
    lock_name = f".datos-acceso-{prefijo}.lock" if prefijo else ".datos-acceso.lock"
    lock_path = os.path.join(args.csv_dir, lock_name)
    with open(lock_path, "w") as lock_file:
        fcntl.flock(lock_file, fcntl.LOCK_EX)  # bloqueante: espera su turno
        try:
            csv_path = resolver_csv_path(args.csv_dir, args.proyecto_formativo)
            actualizar_fila(csv_path, args.ip, row)
        finally:
            fcntl.flock(lock_file, fcntl.LOCK_UN)

    print(f"OK Fila de {args.ip} actualizada en {csv_path}")


if __name__ == "__main__":
    sys.exit(main())
