#!/bin/sh
set -e

# --- Environment Variable Check ---
# Support both AIRFLOW__DATABASE__SQL_ALCHEMY_CONN and DATABASE_URL (Aiven service integration)
if [ -n "$AIRFLOW__DATABASE__SQL_ALCHEMY_CONN" ]; then
    echo "Using AIRFLOW__DATABASE__SQL_ALCHEMY_CONN for database connection."
elif [ -n "$DATABASE_URL" ]; then
    # Aiven exposes PostgreSQL as DATABASE_URL; convert to Airflow's expected format
    # postgres:// -> postgresql+psycopg2:// for SQLAlchemy/psycopg2
    AIRFLOW__DATABASE__SQL_ALCHEMY_CONN=$(echo "$DATABASE_URL" | sed 's|^postgres://|postgresql+psycopg2://|;s|^postgresql://|postgresql+psycopg2://|')
    export AIRFLOW__DATABASE__SQL_ALCHEMY_CONN
    echo "Using DATABASE_URL (Aiven service integration) for database connection."
else
    echo "ERROR: Database connection required. Set either:"
    echo "  - AIRFLOW__DATABASE__SQL_ALCHEMY_CONN (postgresql+psycopg2://user:pass@host:port/db)"
    echo "  - DATABASE_URL (auto-set when connecting PostgreSQL in Aiven)"
    exit 1
fi
echo "Database configuration found. Proceeding with application startup."
echo "---"

# --- Webserver binding: must listen on 0.0.0.0 for proxy/load balancer access ---
export AIRFLOW__WEBSERVER__WEB_SERVER_HOST="${AIRFLOW__WEBSERVER__WEB_SERVER_HOST:-0.0.0.0}"

# --- Port configuration (Aiven App Runtime may inject PORT) ---
if [ -n "$PORT" ]; then
    export AIRFLOW__WEBSERVER__WEB_SERVER_PORT="$PORT"
fi

# --- Base URL for proxy deployments (optional) ---
# Set BASE_URL to your external URL if you see redirect or cookie issues behind a proxy
if [ -n "$BASE_URL" ]; then
    export AIRFLOW__WEBSERVER__BASE_URL="$BASE_URL"
fi

# --- Run migrations on startup (idempotent) ---
# Airflow's entrypoint uses _AIRFLOW_DB_MIGRATE. Aiven rejects keys starting with _,
# so we accept AIRFLOW_DB_MIGRATE and map it.
_AIRFLOW_DB_MIGRATE="${_AIRFLOW_DB_MIGRATE:-${AIRFLOW_DB_MIGRATE:-true}}"
export _AIRFLOW_DB_MIGRATE

# --- Map Aiven-compatible vars to Airflow's _-prefixed vars ---
# Aiven requires keys to match ^[a-zA-Z][a-zA-Z0-9_]*$ (no leading underscore)
[ -n "$AIRFLOW_WWW_USER_CREATE" ] && export _AIRFLOW_WWW_USER_CREATE="$AIRFLOW_WWW_USER_CREATE"
[ -n "$AIRFLOW_WWW_USER_USERNAME" ] && export _AIRFLOW_WWW_USER_USERNAME="$AIRFLOW_WWW_USER_USERNAME"
[ -n "$AIRFLOW_WWW_USER_PASSWORD" ] && export _AIRFLOW_WWW_USER_PASSWORD="$AIRFLOW_WWW_USER_PASSWORD"

# --- Exec into Airflow's entrypoint ---
# Pass through all arguments (default: standalone)
exec /entrypoint "$@"
