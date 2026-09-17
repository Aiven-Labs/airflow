#!/bin/sh
set -e

# Airflow after 3.0.5 no longer includes the FAB auth manager. The Simple
# Auth Manager that _is_ included does not support setting username and
# password from environment variables - it uses a file instead.
# (The documentation, by the way, emphasises that a production deployment
# of airflow should be using a more sophisticated auth manager than either
# FAB _or_ this newer Simple Auth Manager).
#
# If no username/password is provided, then an admin user with a random
# password is generated, and this is logged in the runtime log - for
# instance
#     Simple auth manager | Password for user 'admin': 5vdQkTqhCsY7e3yY
#
# Let's define where the password file should be
PASSWORDS_FILE=/opt/airflow/passwords.json"
export AIRFLOW__CORE__SIMPLE_AUTH_MANAGER_PASSWORDS_FILE="$PASSWORDS_FILE"

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

# If the user has supplied both USERNAME and PASSWORD, then we'll write them
# to the passwords file
if [ -n "$AIRFLOW_WWW_USER_USERNAME" -a -n "$AIRFLOW_WWW_USER_PASSWORD" ]; then
  echo "Setting username $AIRFLOW_WWW_USER_USERNAME with password $AIRFLOW_WWW_USER_PASSWORD"
  echo "{ \"$AIRFLOW_WWW_USER_USERNAME\": \"$AIRFLOW_WWW_USER_PASSWORD\" }" > $PASSWORDS_FILE
  echo "Password file $PASSWORDS_FILE contains:"
  echo "$(cat $PASSWORDS_FILE)"
fi

# --- Exec into Airflow's entrypoint ---
# Pass through all arguments (default: standalone)
exec /entrypoint "$@"
