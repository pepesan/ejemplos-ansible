#!/bin/bash
# Creates (or reuses, if it already exists) a workspace in Kasm, without
# touching the rest of the deployment (does not reinstall Kasm, does not
# touch swapfile/docker compose). Parameterised generalisation of the
# original one-off workspace setup script, so additional workspaces can be
# created on top of an already-deployed Kasm instance.

set -e

KASM_URL="https://127.0.0.1:443"
IMAGE_NAME="${KASM_IMAGE:?ERR: KASM_IMAGE is required (e.g. user/image:1.0)}"
[[ "$IMAGE_NAME" != *:* ]] && IMAGE_NAME="${IMAGE_NAME}:latest"

WORKSPACE_NAME="${KASM_WORKSPACE_NAME:?ERR: KASM_WORKSPACE_NAME is required}"
WORKSPACE_DESC="${KASM_WORKSPACE_DESC:-$WORKSPACE_NAME}"

case "${KASM_PRIVILEGED:-false}" in
  true|True|TRUE|yes|1)  PRIVILEGED="True" ;;
  false|False|FALSE|no|0) PRIVILEGED="False" ;;
  *)
    echo "ERR invalid KASM_PRIVILEGED value: '${KASM_PRIVILEGED}' (use true or false)" >&2
    exit 1
    ;;
esac

CORES="${KASM_CORES:-4}"
MEMORY_GB="${KASM_MEMORY_GB:-8}"
MEMORY=$(( MEMORY_GB * 1024 * 1024 * 1024 ))
GPU_COUNT="${KASM_GPU_COUNT:-0}"
SESSION_TIME_LIMIT="${KASM_SESSION_TIME_LIMIT:-}"
CATEGORY="${KASM_CATEGORY:-}"
ENABLED="${KASM_ENABLED:-true}"
case "$ENABLED" in
  true|True|TRUE|yes|1)  ENABLED_PY="True" ;;
  false|False|FALSE|no|0) ENABLED_PY="False" ;;
  *) echo "ERR invalid KASM_ENABLED value" >&2; exit 1 ;;
esac

# Path on the HOST (inside Kasm's DinD) mounted as the user's persistent home
# directory across sessions. Must contain {username} or {user_id}. Empty = no
# persistence. Grouped under the "profile" family of settings.
PERSISTENT_PROFILE_PATH="${KASM_PERSISTENT_PROFILE_PATH:-}"

# Session Staging (optional): pre-warms N containers of this workspace so
# they're ready before a user connects, instead of a cold start on request.
# There is no documented public endpoint for this (it's
# "AdminApi.create_staging_config", part of the internal, session-authenticated
# admin API, not the public api_key one) — uses the same direct-Postgres
# pattern as create/delete workspace. Grouped under the "group" family
# (zone/group-level settings), since staging is configured per zone, not per
# workspace alone.
STAGING_ENABLED="${KASM_STAGING_ENABLED:-false}"
STAGING_NUM_SESSIONS="${KASM_STAGING_NUM_SESSIONS:-1}"
STAGING_EXPIRATION_HOURS="${KASM_STAGING_EXPIRATION_HOURS:-24}"
STAGING_ZONE_NAME="${KASM_STAGING_ZONE_NAME:-default}"

# Autostart (optional): launches one session of this workspace for a given
# Kasm user right after creating/reusing the workspace, so that user's first
# login finds a session already running instead of a cold start.
AUTOSTART_ENABLED="${KASM_AUTOSTART_ENABLED:-false}"
AUTOSTART_USER="${KASM_AUTOSTART_USER:-user@kasm.local}"
AUTOSTART_TIMEOUT_SECONDS="${KASM_AUTOSTART_TIMEOUT_SECONDS:-600}"

echo ">> Waiting for the Kasm service at ${KASM_URL}..."
until curl -sk --fail "${KASM_URL}" -o /dev/null; do
  echo "Waiting for Kasm..."
  sleep 5
done
echo ">> Kasm is ready. Proceeding..."

PSQL() {
  docker exec kasm docker exec kasm_db psql -U kasmapp -d kasm "$@"
}

# Staging (create_staging_config/update_staging_config) DOES have a
# documented public API endpoint, unlike create/check/delete workspace — but
# it also needs a zone_id, and there is no documented public "get_zones"
# endpoint to resolve STAGING_ZONE_NAME into one, so this step still falls
# back to direct SQL for that lookup. The INSERT itself is intentionally
# kept rather than switched to the public endpoint: its exact request
# schema hasn't been verified against a running instance, and guessing it
# wrong would misconfigure staging silently instead of failing loudly. Left
# as a documented follow-up once that's confirmed (see role README).
configure_staging() {
  local IMAGE_ID="$1"
  [ "$STAGING_ENABLED" != "true" ] && return 0

  echo ""
  echo ">> Configuring Session Staging (${STAGING_NUM_SESSIONS} pre-warmed session(s))..."
  local ZONE_ID ZONE_PROXY_HOSTNAME
  ZONE_ID=$(PSQL -t -c "SELECT zone_id FROM zones WHERE zone_name = '${STAGING_ZONE_NAME}';" | tr -d ' \n')
  if [ -z "$ZONE_ID" ]; then
    echo "WARNING Zone '${STAGING_ZONE_NAME}' does not exist. Staging not configured." >&2
    return 0
  fi

  ZONE_PROXY_HOSTNAME=$(PSQL -t -c "SELECT proxy_hostname FROM zones WHERE zone_id = '${ZONE_ID}';" | sed 's/^ *//;s/ *$//')
  if [ "$ZONE_PROXY_HOSTNAME" = '$request_host$' ]; then
    echo "WARNING Zone '${STAGING_ZONE_NAME}' still uses proxy_hostname=\$request_host\$." >&2
    echo "        Kasm documents that staged sessions need a fixed domain configured" >&2
    echo "        on the zone (not \$request_host\$). This does not change that global" >&2
    echo "        setting automatically from here (it affects every workspace, not just" >&2
    echo "        this one). To enable staging, set a fixed domain on the zone first from" >&2
    echo "        the admin panel (Zones -> ${STAGING_ZONE_NAME} -> Hostname), or request" >&2
    echo "        that change explicitly. Workspace created, but WITHOUT staging." >&2
    return 0
  fi

  local EXPIRATION_SECONDS=$(( STAGING_EXPIRATION_HOURS * 3600 ))
  PSQL -c "
    INSERT INTO staging_configs (zone_id, image_id, num_sessions, expiration)
    VALUES ('${ZONE_ID}', '${IMAGE_ID}', ${STAGING_NUM_SESSIONS}, ${EXPIRATION_SECONDS})
    ON CONFLICT (zone_id, image_id) DO UPDATE SET
      num_sessions = EXCLUDED.num_sessions,
      expiration = EXCLUDED.expiration;
  "
  echo "OK Staging configured: ${STAGING_NUM_SESSIONS} pre-warmed session(s), expiration ${STAGING_EXPIRATION_HOURS}h."
}

# Launches a session of this workspace for AUTOSTART_USER through the public
# request_kasm API (the persistent API key already holds permission 100, see
# below) and waits until it is "running". Idempotent: a row in "kasms" for
# the same user+image means a session already exists (Kasm deletes the row as
# soon as a session is destroyed), so nothing is launched twice. Never fails
# the workspace creation: problems here are warnings, like staging.
# Must be called after API_KEY/API_KEY_SECRET are set.
autostart_session() {
  [ "$AUTOSTART_ENABLED" != "true" ] && return 0

  echo ""
  echo ">> Autostart: launching a session of '${IMAGE_NAME}' for ${AUTOSTART_USER}..."
  local USER_ID IMAGE_ID EXISTING RESPONSE KASM_ID STATUS ELAPSED=0
  USER_ID=$(PSQL -t -c "SELECT user_id FROM users WHERE username = '${AUTOSTART_USER}';" | tr -d ' \n')
  if [ -z "$USER_ID" ]; then
    echo "WARNING Autostart: user '${AUTOSTART_USER}' does not exist. No session launched." >&2
    return 0
  fi

  # Canonical (dashed) image_id straight from the DB, whichever form the API
  # returned it in.
  IMAGE_ID=$(PSQL -t -c "SELECT image_id FROM images WHERE name = '${IMAGE_NAME}';" | tr -d ' \n')
  if [ -z "$IMAGE_ID" ]; then
    echo "WARNING Autostart: image '${IMAGE_NAME}' is not registered. No session launched." >&2
    return 0
  fi

  EXISTING=$(PSQL -t -c "SELECT kasm_id FROM kasms WHERE user_id = '${USER_ID}' AND image_id = '${IMAGE_ID}' LIMIT 1;" | tr -d ' \n')
  if [ -n "$EXISTING" ]; then
    echo "OK Autostart: ${AUTOSTART_USER} already has a session of this workspace (${EXISTING}). Autostart session already running."
    return 0
  fi

  RESPONSE=$(curl -sk -X POST "${KASM_URL}/api/public/request_kasm" \
    -H "Content-Type: application/json" \
    -d "{\"api_key\": \"${API_KEY}\", \"api_key_secret\": \"${API_KEY_SECRET}\", \"user_id\": \"${USER_ID}\", \"image_id\": \"${IMAGE_ID}\"}") \
    || RESPONSE="curl failed (code $?)"

  KASM_ID=$(echo "$RESPONSE" | python3 -c 'import sys,json; print(json.load(sys.stdin).get("kasm_id",""))' 2>/dev/null || true)
  if [ -z "$KASM_ID" ]; then
    # Never print the raw response on success (it carries a session token),
    # only on failure, where it is the error payload.
    echo "WARNING Autostart: request_kasm did not return a kasm_id. Response: ${RESPONSE}" >&2
    return 0
  fi

  echo ">> Autostart: session ${KASM_ID} requested, waiting for it to be running (max ${AUTOSTART_TIMEOUT_SECONDS}s)..."
  while [ "$ELAPSED" -lt "$AUTOSTART_TIMEOUT_SECONDS" ]; do
    STATUS=$(PSQL -t -c "SELECT operational_status FROM kasms WHERE kasm_id = '${KASM_ID}';" | tr -d ' \n')
    if [ "$STATUS" = "running" ]; then
      echo "OK Autostart session started: ${KASM_ID} for ${AUTOSTART_USER} (${ELAPSED}s)."
      return 0
    fi
    sleep 5
    ELAPSED=$(( ELAPSED + 5 ))
  done
  echo "WARNING Autostart: session ${KASM_ID} is not running after ${AUTOSTART_TIMEOUT_SECONDS}s (last status: '${STATUS:-unknown}')." >&2
}

# Persistent API key: generated once per server and reused on later workspace
# creations, instead of creating and destroying a new one each time (avoids
# churn in api_configs/group_permissions and lets other admin tooling, e.g.
# launching test sessions, reuse the same credential). Persisted outside the
# container, on the host, in a root-only-readable file; the plaintext secret
# only ever lives here (the DB only stores its hash, which is why it must be
# saved the first time).
API_KEY_FILE="${KASM_DIR:-/opt/kasm}/.kasm_api_key.json"
API_KEY_LOCK="${API_KEY_FILE}.lock"
API_KEY_NAME="ansible-managed-kasm-api"

# Same reasoning as the credentials CSV (update_credentials_csv.py): with
# forks>1 or several playbooks launched almost simultaneously against the
# same host, two runs could both see "file doesn't exist" at once and insert
# two API keys in parallel. A blocking flock serialises the check-or-create
# so only one wins and the rest reuse its result.
(
  flock -x 200
  if [ -f "$API_KEY_FILE" ]; then
    echo ">> Reusing persistent API key (${API_KEY_FILE})"
  else
    echo ">> No persistent API key yet: generating a new one..."
    NEW_API_KEY=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | head -c 12)
    NEW_API_KEY_SECRET=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | head -c 32)
    SALT=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9-' | head -c 36)
    HASH=$(echo -n "${NEW_API_KEY_SECRET}${SALT}" | sha256sum | cut -d' ' -f1)

    echo ">> Removing any leftovers of a previous API key with the same name, if any..."
    docker exec kasm docker exec kasm_db psql -U kasmapp -d kasm -c \
      "DELETE FROM api_configs WHERE name='${API_KEY_NAME}';"

    echo ">> Inserting the API key into the database..."
    docker exec kasm docker exec kasm_db psql -U kasmapp -d kasm -c "
      INSERT INTO api_configs (name, api_key, api_key_secret_hash, salt, enabled, read_only, created)
      VALUES ('${API_KEY_NAME}', '${NEW_API_KEY}', '${HASH}', '${SALT}', true, false, now());
    "
    API_ID=$(docker exec kasm docker exec kasm_db psql -U kasmapp -d kasm -t -c \
      "SELECT api_id FROM api_configs WHERE name='${API_KEY_NAME}';" | tr -d ' ')
    # Permission 200 ("Administrators", create_image/get_images) to create
    # workspaces, and permission 100 ("All Users",
    # request_kasm/get_kasm_status/destroy_kasm) so this same key can also
    # validate that a real session comes up after creating the workspace.
    # Both are group-level permissions.
    docker exec kasm docker exec kasm_db psql -U kasmapp -d kasm -c "
      INSERT INTO group_permissions (permission_id, api_id) VALUES (200, '${API_ID}');
      INSERT INTO group_permissions (permission_id, api_id) VALUES (100, '${API_ID}');
    "

    TMP_API_KEY_FILE="${API_KEY_FILE}.tmp"
    python3 -c "import json; json.dump({'api_key': '${NEW_API_KEY}', 'api_key_secret': '${NEW_API_KEY_SECRET}'}, open('${TMP_API_KEY_FILE}', 'w'))"
    chmod 600 "$TMP_API_KEY_FILE"
    mv "$TMP_API_KEY_FILE" "$API_KEY_FILE"  # atomic within the same filesystem

    sleep 2
  fi
) 200>"$API_KEY_LOCK"

API_KEY=$(python3 -c "import json; print(json.load(open('${API_KEY_FILE}'))['api_key'])")
API_KEY_SECRET=$(python3 -c "import json; print(json.load(open('${API_KEY_FILE}'))['api_key_secret'])")

# Existence check via Kasm's public get_images API (Images View permission,
# already granted to this key via permission 200 above) instead of a direct
# SQL query — get_images has no server-side name filter documented, so the
# match is done client-side in Python over the full list.
echo ">> Checking whether the workspace already exists..."
EXISTING_IMAGE_ID=$(curl -sk -X POST "${KASM_URL}/api/public/get_images" \
  -H "Content-Type: application/json" \
  -d "{\"api_key\": \"${API_KEY}\", \"api_key_secret\": \"${API_KEY_SECRET}\"}" \
  | IMAGE_NAME="${IMAGE_NAME}" python3 -c '
import sys, json, os
data = json.load(sys.stdin)
target = os.environ["IMAGE_NAME"]
for image in data.get("images", []):
    if image.get("name") == target:
        print(image["image_id"])
        break
')

if [ -n "$EXISTING_IMAGE_ID" ]; then
  echo "OK Workspace with image ${IMAGE_NAME} is already configured. Skipping creation."
  configure_staging "$EXISTING_IMAGE_ID"
  autostart_session
  exit 0
fi

echo ">> Creating workspace '${WORKSPACE_NAME}' (image ${IMAGE_NAME}, cores=${CORES}, memory=${MEMORY_GB}GB, privileged=${PRIVILEGED})..."
PAYLOAD=$(PERSISTENT_PROFILE_PATH="${PERSISTENT_PROFILE_PATH}" \
  SESSION_TIME_LIMIT="${SESSION_TIME_LIMIT}" \
  CATEGORY="${CATEGORY}" \
  python3 - <<PYEOF
import json, os
payload = {
    "api_key": "${API_KEY}",
    "api_key_secret": "${API_KEY_SECRET}",
    "target_image": {
        "name": "${IMAGE_NAME}",
        "friendly_name": "${WORKSPACE_NAME}",
        "description": "${WORKSPACE_DESC}",
        "image_type": "Container",
        "cores": ${CORES},
        "memory": ${MEMORY},
        "gpu_count": ${GPU_COUNT},
        "enabled": ${ENABLED_PY},
        "docker_registry": "https://index.docker.io/v1/",
        "run_config": json.dumps({
            "privileged": ${PRIVILEGED},
            "environment": {
                "KASM_SVC_SEND_CUT_TEXT": "-SendCutText 0",
                "KASM_SVC_ACCEPT_CUT_TEXT": "-AcceptCutText 0",
                "KASM_SVC_PRINTER": "0"
            }
        }),
        "exec_config": json.dumps({
            "first_launch": {
                "user": "root",
                "cmd": (
                    "chmod -R 000 /home/kasm-user/Desktop/Downloads /home/kasm-user/Desktop/Uploads"
                    " && chown -R root:root /home/kasm-user/Desktop/Downloads /home/kasm-user/Desktop/Uploads"
                    " && systemctl stop cups 2>/dev/null; systemctl disable cups 2>/dev/null"
                )
            }
        })
    }
}

persistent_profile_path = os.environ.get("PERSISTENT_PROFILE_PATH", "").strip()
if persistent_profile_path:
    payload["target_image"]["persistent_profile_path"] = persistent_profile_path

session_time_limit = os.environ.get("SESSION_TIME_LIMIT", "").strip()
if session_time_limit:
    payload["target_image"]["session_time_limit"] = int(session_time_limit)

category = os.environ.get("CATEGORY", "").strip()
if category:
    payload["target_image"]["categories"] = [category]
    payload["target_image"]["default_category"] = category

print(json.dumps(payload))
PYEOF
)
RESPONSE=$(curl -sk -X POST "${KASM_URL}/api/public/create_image" \
  -H "Content-Type: application/json" \
  -d "${PAYLOAD}") || RESPONSE="curl failed (code $?)"

echo "Response: ${RESPONSE}"

CREATE_OK=true
if echo "$RESPONSE" | grep -q "image_id"; then
  echo "OK Workspace '${WORKSPACE_NAME}' created successfully"
  NEW_IMAGE_ID=$(echo "$RESPONSE" | python3 -c 'import sys,json; print(json.load(sys.stdin)["image"]["image_id"])' 2>/dev/null || true)
  if [ -n "$NEW_IMAGE_ID" ]; then
    # The API returns image_id without dashes; Postgres uuid columns accept
    # it as-is (Postgres normalises the format), no need to reformat it.
    configure_staging "$NEW_IMAGE_ID"
    autostart_session
  fi
else
  ERROR_DETAIL=$(echo "$RESPONSE" | python3 -c '
import sys, json
raw = sys.stdin.read().strip()
try:
    data = json.loads(raw)
    print(data.get("error_message") or data.get("message") or raw)
except Exception:
    print(raw or "empty response")
')
  echo "ERROR creating workspace '${WORKSPACE_NAME}' (image ${IMAGE_NAME}): ${ERROR_DETAIL}" >&2
  CREATE_OK=false
fi

if [ "$CREATE_OK" != "true" ]; then
  exit 1
fi
