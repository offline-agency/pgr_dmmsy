#!/usr/bin/env bash
# =============================================================
# pgr_dmmsy Verification Suite — Shell Runner
# =============================================================
# Usage:
#   ./run_all.sh [dbname] [extra psql options...]
#
# Prerequisites:
#   - PostgreSQL running and accessible
#   - pgr_dmmsy extension installed in the target database
#   - pgRouting extension installed (for pgr_dijkstra reference)
#
# Exit code: number of test failures (0 = all passed)
# =============================================================

set -euo pipefail

DB="${1:-postgres}"
shift 2>/dev/null || true   # remaining args passed to psql
PSQL_OPTS="$*"
PSQL="psql -d $DB $PSQL_OPTS -v ON_ERROR_STOP=0 -q"

VERIFY_DIR="$(cd "$(dirname "$0")/.." && pwd)"

# ANSI colour codes (suppressed if not a terminal)
if [ -t 1 ]; then
    RED='\033[0;31m' GREEN='\033[0;32m' YELLOW='\033[0;33m'
    BOLD='\033[1m' RESET='\033[0m'
else
    RED='' GREEN='' YELLOW='' BOLD='' RESET=''
fi

banner() {
    echo -e "${BOLD}═══════════════════════════════════════════════════${RESET}"
    echo -e "${BOLD}  pgr_dmmsy Verification Suite${RESET}"
    echo -e "${BOLD}  Database : $DB${RESET}"
    echo -e "${BOLD}  Time     : $(date)${RESET}"
    echo -e "${BOLD}═══════════════════════════════════════════════════${RESET}"
    echo ""
}

run_sql() {
    local label="$1" file="$2"
    printf "  %-40s" "$label"
    if $PSQL -f "$file" >/dev/null 2>&1; then
        echo -e "${GREEN}OK${RESET}"
    else
        echo -e "${RED}ERROR (psql)${RESET}"
    fi
}

banner

echo -e "${BOLD}[ Setup ]${RESET}"
run_sql "00_setup.sql (schema + helpers)"  "$VERIFY_DIR/sql/00_setup.sql"
run_sql "01_generators.sql (14 generators)" "$VERIFY_DIR/sql/01_generators.sql"
run_sql "02_stub.sql (wrappers)"           "$VERIFY_DIR/sql/02_stub.sql"
echo ""

# Mandatory suites (failure here counts towards exit code)
MANDATORY_SUITES=(
    "01_correctness.sql"
    "02_predecessors.sql"
    "03_negative.sql"
    "04_topology.sql"
    "05_weights.sql"
    "07_integration.sql"
    "09_api_contract.sql"
)

# Informational suites (warnings only, do not affect exit code)
INFO_SUITES=(
    "06_performance.sql"
    "08_invariants.sql"
)

echo -e "${BOLD}[ Mandatory test suites ]${RESET}"
for f in "${MANDATORY_SUITES[@]}"; do
    run_sql "$f" "$VERIFY_DIR/tests/$f"
done
echo ""

echo -e "${BOLD}[ Informational suites (warnings only) ]${RESET}"
for f in "${INFO_SUITES[@]}"; do
    run_sql "$f" "$VERIFY_DIR/tests/$f"
done
echo ""

# ------- Summary -------
echo -e "${BOLD}[ Summary ]${RESET}"
SUMMARY=$($PSQL -At -c "
    SELECT suite || '  ' ||
           passed::TEXT || '/' || total::TEXT || ' passed'
           || CASE WHEN failed > 0 THEN '  ← ' || failed || ' FAILED' ELSE '' END
    FROM dmmsy_verify.summary()
    ORDER BY suite;
" 2>/dev/null || echo "(could not read summary)")

echo "$SUMMARY"
echo ""

FAILURES=$($PSQL -At -c "SELECT dmmsy_verify.overall_failures();" 2>/dev/null || echo "999")

echo -e "${BOLD}═══════════════════════════════════════════════════${RESET}"
if [ "$FAILURES" -eq 0 ]; then
    echo -e "${GREEN}${BOLD}  ALL TESTS PASSED${RESET}"
else
    echo -e "${RED}${BOLD}  $FAILURES TEST(S) FAILED${RESET}"
    echo ""
    echo "  Failing tests:"
    $PSQL -c "
        SELECT '    ✗ ' || suite || '.' || test_name ||
               CASE WHEN details IS NOT NULL
                    THEN ' — ' || LEFT(details, 80) ELSE '' END
        FROM dmmsy_verify.test_results
        WHERE NOT passed
        ORDER BY run_at;" 2>/dev/null || true
fi
echo -e "${BOLD}═══════════════════════════════════════════════════${RESET}"

exit "$FAILURES"
