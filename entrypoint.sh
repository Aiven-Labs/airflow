#!/bin/sh
set -e

# --- Airflow configuration for stateless App Runtime ---
export AIRFLOW__CORE__EXECUTOR="LocalExecutor"
export AIRFLOW__WEBSERVER__EXPOSE_CONFIG="false"
export AIRFLOW__CORE__LOAD_EXAMPLES="false"

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

# --- Username and Password setup ---
# Specify where the Simple Auth Manager password file should live
PASSWORDS_FILE="/opt/airflow/passwords.json"
export AIRFLOW__CORE__SIMPLE_AUTH_MANAGER_PASSWORDS_FILE="$PASSWORDS_FILE"
# If the user has supplied both USERNAME and PASSWORD, then we'll write them
# to the passwords file. Otherwise, the Simple Auth Manager will create a
# default username and password, and write them to the runtime logs
if [ -n "$AIRFLOW_USERNAME" -a -n "$AIRFLOW_PASSWORD" ]; then
  echo "Setting up user $AIRFLOW_USERNAME"
  echo "{ \"$AIRFLOW_USERNAME\": \"$AIRFLOW_PASSWORD\" }" > $PASSWORDS_FILE
  echo "$PASSWORDS_FILE contains $(cat $PASSWORDS_FILE)"
fi

# --- Exec into Airflow's entrypoint ---
# Pass through all arguments (default: standalone)
exec /entrypoint "$@"
