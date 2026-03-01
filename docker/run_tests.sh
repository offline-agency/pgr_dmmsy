#!/usr/bin/env bash
# =============================================================
# pgr_dmmsy — Docker test runner
# =============================================================
# Builds the image (if needed), starts the DB container, runs
# the full verify/ SQL suite, and optionally tears down.
#
# Usage:
#   bash docker/run_tests.sh           # run tests, stop container
#   bash docker/run_tests.sh --keep-db # keep container running
#
# Prerequisites:
#   docker, docker compose
# =============================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
KEEP_DB=false

for arg in "$@"; do
    case "$arg" in
        --keep-db) KEEP_DB=true ;;
        *) echo "Unknown argument: $arg"; exit 1 ;;
    esac
done

cd "$PROJECT_DIR"

# ANSI colours when connected to a terminal
if [ -t 1 ]; then
    BOLD='\033[1m' GREEN='\033[0;32m' RED='\033[0;31m' RESET='\033[0m'
else
    BOLD='' GREEN='' RED='' RESET=''
fi

echo -e "${BOLD}=== pgr_dmmsy Docker test runner ===${RESET}"
echo ""

# ---- 1. Build (or reuse cached) image --------------------------------
echo -e "${BOLD}[1/5] Building Docker image (C unit tests run at build time)...${RESET}"
docker compose build db
echo ""

# ---- 2. Start the DB container ----------------------------------------
echo -e "${BOLD}[2/5] Starting database container...${RESET}"
docker compose up -d db

echo -n "      Waiting for PostgreSQL to be ready"
until docker compose exec -T db pg_isready -U postgres -d pgr_dmmsy_test \
        >/dev/null 2>&1; do
    echo -n "."
    sleep 1
done
echo " ready."
echo ""

# ---- 3. Ensure extensions are loaded (idempotent) ---------------------
# Runs even if the initdb scripts were skipped on an existing volume.
echo -e "${BOLD}[3/5] Ensuring extensions are installed...${RESET}"
docker compose exec -T \
    -e PGPASSWORD=postgres \
    db \
    psql -U postgres -d pgr_dmmsy_test -q -c "
        CREATE EXTENSION IF NOT EXISTS postgis;
        CREATE EXTENSION IF NOT EXISTS pgrouting;
        CREATE EXTENSION IF NOT EXISTS pgr_dmmsy;
    "
docker compose exec -T \
    -e PGPASSWORD=postgres \
    db \
    psql -U postgres -d pgr_dmmsy_test -tAc \
    "SELECT string_agg(extname, ', ' ORDER BY extname)
     FROM pg_extension WHERE extname IN ('postgis','pgrouting','pgr_dmmsy');" \
| xargs -I{} echo "      Loaded: {}"
echo ""

# ---- 4. Load verify schema --------------------------------------------
echo -e "${BOLD}[4/5] Loading verify schema and generators...${RESET}"
docker compose exec -T \
    -e PGPASSWORD=postgres \
    db \
    psql -U postgres -d pgr_dmmsy_test \
        -f /pgr_dmmsy/verify/sql/00_setup.sql \
        -f /pgr_dmmsy/verify/sql/01_generators.sql \
        -f /pgr_dmmsy/verify/sql/02_stub.sql \
    -q
echo ""

# ---- 5. Run the verification suite ------------------------------------
echo -e "${BOLD}[5/5] Running verification suite...${RESET}"
set +e
docker compose exec -T \
    -e PGPASSWORD=postgres \
    db \
    bash /pgr_dmmsy/verify/tests/run_all.sh pgr_dmmsy_test -U postgres
FAILURES=$?
set -e

echo ""

# ---- teardown ---------------------------------------------------------
if [ "$KEEP_DB" = false ]; then
    echo -e "${BOLD}Stopping containers...${RESET}"
    docker compose down
fi

# ---- result -----------------------------------------------------------
if [ "$FAILURES" -eq 0 ]; then
    echo -e "${GREEN}${BOLD}All tests passed.${RESET}"
else
    echo -e "${RED}${BOLD}$FAILURES test(s) failed.${RESET}"
fi

exit "$FAILURES"
