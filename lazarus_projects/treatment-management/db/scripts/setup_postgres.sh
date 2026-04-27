#!/usr/bin/env bash
# Treatment Management System - Local Postgres setup
#
# Bootstraps a local PostgreSQL instance for development:
#   1. Ensures wal_level = logical and friends (so the Prolog port can
#      subscribe via logical decoding).
#   2. Creates the tm_app role and treatment_mgmt database.
#   3. Runs migrations in db/migrations/ in numeric order.
#
# Tested against PostgreSQL 16 on Ubuntu 24.04. Requires sudo for the
# postgresql.conf edit and service restart.

set -euo pipefail

DB_NAME="${DB_NAME:-treatment_mgmt}"
DB_USER="${DB_USER:-tm_app}"
DB_PASS="${DB_PASS:-tm_app_dev_password}"
PG_VERSION="${PG_VERSION:-16}"
PG_CONF="/etc/postgresql/${PG_VERSION}/main/postgresql.conf"
MIGRATIONS_DIR="$(cd "$(dirname "$0")/../migrations" && pwd)"

say() { echo "[setup_postgres] $*"; }

# 1. Configure postgresql.conf for logical replication ----------------------
if [[ -f "$PG_CONF" ]]; then
    say "Ensuring logical replication settings in $PG_CONF"
    sudo sed -i \
        -e "s/^#*\s*wal_level\s*=.*/wal_level = logical/" \
        -e "s/^#*\s*max_wal_senders\s*=.*/max_wal_senders = 10/" \
        -e "s/^#*\s*max_replication_slots\s*=.*/max_replication_slots = 10/" \
        "$PG_CONF"
    say "Restarting postgresql service"
    sudo systemctl restart "postgresql@${PG_VERSION}-main" \
        || sudo service postgresql restart
else
    say "WARNING: $PG_CONF not found; skipping wal_level configuration."
    say "         Set wal_level=logical manually before running the Prolog port."
fi

# 2. Create role + database -------------------------------------------------
say "Ensuring role '$DB_USER' exists"
sudo -u postgres psql -v ON_ERROR_STOP=1 <<SQL
DO \$\$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = '${DB_USER}') THEN
        CREATE ROLE ${DB_USER} LOGIN PASSWORD '${DB_PASS}' REPLICATION;
    END IF;
END
\$\$;
SQL

say "Ensuring database '$DB_NAME' exists"
if ! sudo -u postgres psql -tAc "SELECT 1 FROM pg_database WHERE datname='${DB_NAME}'" | grep -q 1; then
    sudo -u postgres createdb -O "$DB_USER" "$DB_NAME"
fi

# 3. Run migrations ---------------------------------------------------------
say "Running migrations from $MIGRATIONS_DIR"
export PGPASSWORD="$DB_PASS"
for sql in "$MIGRATIONS_DIR"/*.sql; do
    say "  -> $(basename "$sql")"
    psql -h localhost -U "$DB_USER" -d "$DB_NAME" -v ON_ERROR_STOP=1 -f "$sql"
done

say "Done. Connection string:"
say "  host=localhost port=5432 dbname=${DB_NAME} user=${DB_USER}"
