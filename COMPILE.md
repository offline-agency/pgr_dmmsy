# Building & Integrating pgr_dmmsy

This guide covers everything a developer or operator needs to build, test, and integrate
`pgr_dmmsy` — from compiling on bare metal to embedding it as a dependency in another
PostgreSQL extension or application.

---

## Contents

1. [Prerequisites](#1-prerequisites)
2. [Building from Source](#2-building-from-source)
3. [Running the Test Suite](#3-running-the-test-suite)
4. [Docker Workflow (recommended for local dev)](#4-docker-workflow)
5. [Integrating into Your Project](#5-integrating-into-your-project)
6. [Troubleshooting](#6-troubleshooting)

---

## 1. Prerequisites

| Dependency | Minimum | Notes |
|---|---|---|
| PostgreSQL | 14 | With server development headers |
| pgRouting | 3.x | Required extension dependency |
| GCC or Clang | — | C99 support |
| GNU Make | — | For PGXS build |

### Linux (Debian / Ubuntu)

```bash
# Add the PGDG apt repository (one-time)
sudo sh -c 'echo "deb https://apt.postgresql.org/pub/repos/apt $(lsb_release -cs)-pgdg main" \
  > /etc/apt/sources.list.d/pgdg.list'
curl -fsSL https://www.postgresql.org/media/keys/ACCC4CF8.asc \
  | sudo gpg --dearmor -o /etc/apt/trusted.gpg.d/pgdg.gpg
sudo apt-get update

# Install PostgreSQL 16, pgRouting, and build tools
sudo apt-get install -y \
  postgresql-16 \
  postgresql-server-dev-16 \
  postgresql-16-pgrouting \
  build-essential
```

Replace `16` with your target PostgreSQL major version (14, 15, or 16).

### macOS (Homebrew, Apple Silicon)

```bash
brew install postgresql@16 pgrouting
brew link postgresql@16 --force

# Verify pg_config is on PATH
pg_config --version
```

> **Architecture note:** On Apple Silicon (M1/M2/M3) use the arm64 Homebrew prefix
> `/opt/homebrew/opt/postgresql@16/bin/pg_config`. On older Intel Macs the prefix is
> `/usr/local/opt/postgresql@16/bin/pg_config`.

---

## 2. Building from Source

```bash
# Clone
git clone https://github.com/<owner>/pgr_dmmsy.git
cd pgr_dmmsy

# Build the shared library
make

# Install into the active PostgreSQL installation
sudo make install

# Enable in a database
psql -d mydb -c "CREATE EXTENSION pgrouting;"
psql -d mydb -c "CREATE EXTENSION pgr_dmmsy;"
```

To target a specific PostgreSQL version when multiple are installed:

```bash
make PG_CONFIG=/usr/lib/postgresql/15/bin/pg_config
sudo make install PG_CONFIG=/usr/lib/postgresql/15/bin/pg_config
```

To uninstall:

```bash
psql -d mydb -c "DROP EXTENSION pgr_dmmsy;"
sudo make uninstall
```

---

## 3. Running the Test Suite

`pgr_dmmsy` has three independent test layers. Run them in order during development.

### Layer 1 — C Unit Tests (no PostgreSQL required)

These 38 tests exercise the core algorithm, graph, min-heap, and edge-case logic entirely
in C with no PostgreSQL dependency. They compile and run in seconds.

```bash
cd test/c
make clean && make run
# Expected: "✅ All C unit tests completed!" with no FAILs
```

### Layer 2 — Regression Tests (PGXS `installcheck`)

```bash
# From the project root, with PostgreSQL running:
make installcheck
# Diffs (if any) are written to regression.diffs
```

### Layer 3 — SQL Verification Suite

The `verify/` suite compares results against `pgr_dijkstra`, tests topology edge cases,
weight handling, integration, and DMMSY-specific invariants.

```bash
# Load the verify schema (one-time per database)
psql -d mydb \
  -f verify/sql/00_setup.sql \
  -f verify/sql/01_generators.sql \
  -f verify/sql/02_stub.sql

# Run all suites; exits with failure count (0 = all passed)
bash verify/tests/run_all.sh mydb
```

Mandatory suites (01–05, 07) must all pass. Suites 06 (performance) and 08 (invariants)
are informational; failures are reported as warnings but do not affect the exit code.

---

## 4. Docker Workflow

Docker is the easiest way to get a reproducible test environment without touching your
local PostgreSQL installation.

### First-time setup

```bash
# Build the image
# C unit tests run at build time — the build fails if any test fails
docker compose build db
```

### Start a development database

```bash
docker compose up -d db
# PostgreSQL starts with pgrouting + pgr_dmmsy already loaded

# Connect with psql
psql -h localhost -U postgres -d pgr_dmmsy_test

# Stop when done
docker compose down
```

### Run the full verification suite

```bash
# Convenience script (build → start → load verify schema → run suite → stop)
bash docker/run_tests.sh

# Keep the container running after tests (useful for debugging failures):
bash docker/run_tests.sh --keep-db

# Or use compose directly:
docker compose --profile test run --rm test
```

### Test against a different PostgreSQL version

```bash
docker build --build-arg PG_MAJOR=15 -t pgr_dmmsy:pg15 .
docker run --rm \
  -e POSTGRES_PASSWORD=postgres \
  -p 5432:5432 \
  pgr_dmmsy:pg15
```

---

## 5. Integrating into Your Project

### As an extension dependency

If you are writing your own PostgreSQL extension that calls `pgr_dmmsy`, declare the
dependency in your `.control` file:

```
requires = 'pgrouting, pgr_dmmsy'
```

PostgreSQL will then enforce installation order automatically.

### From application SQL

```sql
-- Full distance map from source vertex 1
SELECT node, agg_cost
FROM pgr_dmmsy(
    'SELECT id, source, target, cost FROM my_edges',
    source  => 1,
    target  => NULL,   -- NULL = all reachable vertices
    directed => true
)
ORDER BY agg_cost;

-- Shortest path from 1 → 500
SELECT seq, node, edge, cost, agg_cost
FROM pgr_dmmsy(
    'SELECT id, source, target, cost FROM my_edges',
    source  => 1,
    target  => 500
);
```

Your edge query must return at minimum:
- `id BIGINT` — unique edge identifier
- `source BIGINT` — start vertex
- `target BIGINT` — end vertex
- `cost FLOAT8` — non-negative edge weight

### From Python (psycopg2)

```python
import psycopg2

conn = psycopg2.connect("dbname=mydb user=postgres")
cur = conn.cursor()

cur.execute("""
    SELECT node, agg_cost
    FROM pgr_dmmsy(
        'SELECT id, source, target, cost FROM roads',
        %s, %s
    )
""", (source_id, target_id))

rows = cur.fetchall()
```

### From Node.js (node-postgres)

```javascript
const { Pool } = require('pg');
const pool = new Pool({ database: 'mydb' });

const { rows } = await pool.query(
    `SELECT node, agg_cost
     FROM pgr_dmmsy(
       'SELECT id, source, target, cost FROM roads',
       $1, $2
     )`,
    [sourceId, targetId]
);
```

### Check installed version

```sql
SELECT extversion FROM pg_extension WHERE extname = 'pgr_dmmsy';
```

### Tuning parameters

| Parameter | Default | Effect |
|---|---|---|
| `param_k` | `ceil(log(n)^(2/3))` | BF rounds per phase — higher = more thorough relaxation |
| `param_t` | `ceil(log(n)^(1/3))` | Phase-width exponent — higher = smaller blocks |
| `max_levels` | unlimited (`-1`) | Cap number of phases (useful for time-bounded queries) |

For most workloads the defaults are optimal. Set `param_k=1` and `param_t=1` to revert to
Dijkstra-equivalent behaviour for baseline comparison.

---

## 6. Troubleshooting

### `pg_config: command not found`

Add PostgreSQL's `bin/` directory to your PATH:

```bash
# Debian/Ubuntu (PG 16)
export PATH="/usr/lib/postgresql/16/bin:$PATH"

# macOS Homebrew (Apple Silicon)
export PATH="/opt/homebrew/opt/postgresql@16/bin:$PATH"
```

### Architecture mismatch on macOS

```
ld: warning: ignoring file '...postgres': found architecture 'x86_64', required 'arm64'
```

Reinstall PostgreSQL for the correct architecture:

```bash
arch -arm64 brew reinstall postgresql@16
```

### `ERROR: required extension "pgrouting" is not installed`

Install pgRouting first:

```sql
CREATE EXTENSION pgrouting;
CREATE EXTENSION pgr_dmmsy;
```

Or install the OS package and then create the extension:

```bash
# Debian/Ubuntu
sudo apt-get install postgresql-16-pgrouting

# macOS
brew install pgrouting
```

### `ERROR: function pgr_dmmsy(...) does not exist`

The extension may not be installed in the current database:

```sql
SELECT * FROM pg_available_extensions WHERE name = 'pgr_dmmsy';
CREATE EXTENSION pgr_dmmsy;
```

### Regression test diffs

If `make installcheck` produces diffs, compare `results/pgr_dmmsy.out` against
`test/expected/pgr_dmmsy.out`. Distances should be identical to the reference; if they
differ, run the C unit tests first to isolate algorithm-level regressions:

```bash
cd test/c && make clean && make run
```
