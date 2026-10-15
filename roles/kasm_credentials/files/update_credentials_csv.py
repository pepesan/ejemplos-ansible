#!/usr/bin/env python3
"""Creates/updates a row (keyed by IP) in the Kasm deployment credentials CSV.

Runs on the Ansible control node (delegate_to: localhost), never on the
remote host. Passwords are passed via environment variables, not command
line arguments, so they never show up in the process list (ps aux) or shell
history.

Safe for concurrent runs: with forks>1 (or several separate runs close in
time) multiple inventory hosts can invoke this script almost simultaneously,
all delegating to the same control node. A blocking flock covers both the
decision of which CSV file to use/create and the full read-modify-write
cycle, and the final write is atomic (temp file + os.replace) so the CSV is
never left half-written if the process is interrupted.
"""
import csv
import fcntl
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


def sanitize_prefix(proyecto_formativo):
    """Turns the course/cohort name into a filesystem-safe slug (no spaces
    or special characters)."""
    if not proyecto_formativo:
        return ""
    slug = "".join(c if c.isalnum() else "-" for c in proyecto_formativo.strip())
    while "--" in slug:
        slug = slug.replace("--", "-")
    return slug.strip("-").lower()


def resolve_csv_path(directory, proyecto_formativo=""):
    """Legacy naming, used only when no explicit --csv-name is given: always
    the file dated with the day of the run, datos-acceso[-<course>]-<date>.csv.
    A new day starts a new file, so the date in the name is always the day the
    rows were written (it used to reuse the oldest existing file, whose date
    then misled). The course/cohort prefix keeps credentials from different
    courses deployed in parallel from mixing in the same CSV. Must always be
    called with the lock already held."""
    prefix = sanitize_prefix(proyecto_formativo)
    today = date.today().isoformat()
    name = f"datos-acceso-{prefix}-{today}.csv" if prefix else f"datos-acceso-{today}.csv"
    return os.path.join(directory, name)


def safe_csv_name(name):
    """Validates an explicit CSV file name: a bare file name (no directories)
    made of letters, digits, '.', '_' and '-', ending in .csv. Raises
    SystemExit otherwise, so a bad value can never write outside --csv-dir."""
    allowed = set("abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789._-")
    if (
        not name
        or name != os.path.basename(name)
        or name.startswith(".")
        or not name.endswith(".csv")
        or any(c not in allowed for c in name)
    ):
        raise SystemExit(
            f"--csv-name {name!r} is not a plain *.csv file name "
            "(letters, digits, '.', '_' and '-' only, no directories)"
        )
    return name


def update_row(csv_path, ip, row):
    """Returns True if the file was actually rewritten (the row is new or
    differs from what was already there), False if the existing row already
    matched and nothing was written — this lets the caller report accurate
    changed/unchanged status instead of always claiming a change."""
    rows_by_ip = {}
    if os.path.exists(csv_path):
        with open(csv_path, newline="") as f:
            reader = csv.DictReader(f)
            for existing_row in reader:
                rows_by_ip[existing_row["ip"]] = existing_row

    existing_row = rows_by_ip.get(ip)
    if existing_row == row:
        return False

    rows_by_ip[ip] = row

    tmp_path = csv_path + ".tmp"
    with open(tmp_path, "w", newline="") as f:
        writer = csv.DictWriter(f, fieldnames=COLUMNS)
        writer.writeheader()
        for ip_key in rows_by_ip:
            writer.writerow(rows_by_ip[ip_key])
    os.chmod(tmp_path, 0o600)
    os.replace(tmp_path, csv_path)  # atomic within the same filesystem
    return True


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
        help="Optional prefix (course/cohort) so credentials from different "
             "courses deployed in parallel don't mix in the same CSV. "
             "Without this argument the classic filename is used "
             "(datos-acceso-<date>.csv, dated with the day of the run).",
    )
    parser.add_argument(
        "--csv-name",
        default="",
        help="Exact CSV file name inside --csv-dir (e.g. "
             "datos-acceso-inventory-mi-curso.csv). When given it takes "
             "precedence over --proyecto-formativo and over the "
             "dated naming: that one file is used as is.",
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

    prefix = sanitize_prefix(args.proyecto_formativo)

    os.makedirs(args.csv_dir, exist_ok=True)
    explicit_name = safe_csv_name(args.csv_name) if args.csv_name else ""
    if explicit_name:
        lock_name = f".{explicit_name}.lock"
    else:
        lock_name = f".datos-acceso-{prefix}.lock" if prefix else ".datos-acceso.lock"
    lock_path = os.path.join(args.csv_dir, lock_name)
    with open(lock_path, "w") as lock_file:
        fcntl.flock(lock_file, fcntl.LOCK_EX)  # blocking: waits its turn
        try:
            if explicit_name:
                csv_path = os.path.join(args.csv_dir, explicit_name)
            else:
                csv_path = resolve_csv_path(args.csv_dir, args.proyecto_formativo)
            changed = update_row(csv_path, args.ip, row)
        finally:
            fcntl.flock(lock_file, fcntl.LOCK_UN)

    if changed:
        print(f"CHANGED row for {args.ip} updated in {csv_path}")
    else:
        print(f"OK row for {args.ip} already up to date in {csv_path}")


if __name__ == "__main__":
    sys.exit(main())
