# pgr_dmmsy

[![CI](https://github.com/offline-agency/pgr_dmmsy/actions/workflows/ci.yml/badge.svg)](https://github.com/offline-agency/pgr_dmmsy/actions/workflows/ci.yml)
[![codecov](https://codecov.io/gh/offline-agency/pgr_dmmsy/branch/main/graph/badge.svg)](https://codecov.io/gh/offline-agency/pgr_dmmsy)
[![Latest Release](https://img.shields.io/github/v/release/offline-agency/pgr_dmmsy)](https://github.com/offline-agency/pgr_dmmsy/releases/latest)
[![Downloads](https://img.shields.io/github/downloads/offline-agency/pgr_dmmsy/total)](https://github.com/offline-agency/pgr_dmmsy/releases)

A PostgreSQL extension implementing the **DMMSY deterministic directed
single-source shortest-path algorithm** from:

> **"Breaking the Sorting Barrier for Directed Single-Source Shortest Paths"**
> — Duan, Mao, Mao, Shu, and Yin (2025)
> [arxiv.org/abs/2504.17033](https://arxiv.org/abs/2504.17033)

DMMSY achieves **O(m log²/³ n)** time complexity for single-source shortest
paths on directed graphs with non-negative weights, beating Dijkstra's
O(m + n log n) on large sparse graphs.

| | DMMSY | Dijkstra |
|---|---|---|
| Complexity | O(m log²/³ n) | O(m + n log n) |
| Deterministic | Yes | Yes |
| Negative weights | No | No |
| Best for | Large sparse graphs | General-purpose |

---

## Quick Start (Docker)

```bash
# 1. Build image — compiles extension + runs 38 C unit tests
docker compose build db

# 2. Start PostgreSQL with pgrouting + pgr_dmmsy pre-loaded
docker compose up -d db

# 3. Connect
psql -h localhost -U postgres -d pgr_dmmsy_test

# 4. Run the full verification suite
bash docker/run_tests.sh

# 5. Stop
docker compose down
```

For building from source, platform-specific instructions, and project
integration see **[COMPILE.md](COMPILE.md)**.

---

## Installation

### Prerequisites

- PostgreSQL 14 or later
- pgRouting 3.x (required dependency)
- PostgreSQL development headers
- GCC or Clang, GNU Make

### Build and install

```bash
make
sudo make install
```

### Enable in a database

```sql
CREATE EXTENSION pgrouting;   -- required first
CREATE EXTENSION pgr_dmmsy;
```

---

## Usage

### Function signature

```sql
pgr_dmmsy(
    edges_sql           TEXT,
    source              BIGINT,
    target              BIGINT  DEFAULT NULL,
    directed            BOOLEAN DEFAULT TRUE,
    output_predecessors BOOLEAN DEFAULT TRUE,
    max_levels          INTEGER DEFAULT NULL,
    param_k             INTEGER DEFAULT NULL,
    param_t             INTEGER DEFAULT NULL,
    constant_degree     BOOLEAN DEFAULT FALSE
)
RETURNS TABLE (
    seq       INT,
    path_seq  INT,
    node      BIGINT,
    edge      BIGINT,
    cost      FLOAT8,
    agg_cost  FLOAT8
)
```

### Parameters

| Parameter | Type | Default | Description |
|---|---|---|---|
| `edges_sql` | TEXT | required | SQL returning `id BIGINT, source BIGINT, target BIGINT, cost FLOAT8` |
| `source` | BIGINT | required | Source vertex |
| `target` | BIGINT | NULL | Target vertex; NULL = all reachable vertices |
| `directed` | BOOLEAN | TRUE | Directed graph |
| `output_predecessors` | BOOLEAN | TRUE | Include predecessor info |
| `max_levels` | INTEGER | NULL | Cap number of phases |
| `param_k` | INTEGER | NULL | BF rounds per phase (auto if NULL) |
| `param_t` | INTEGER | NULL | Phase-width exponent (auto if NULL) |
| `constant_degree` | BOOLEAN | FALSE | Constant-degree optimisation hint |

### Return columns

| Column | Type | Description |
|---|---|---|
| `seq` | INT | Sequential result number |
| `path_seq` | INT | Position in path (1 = start) |
| `node` | BIGINT | Vertex ID |
| `edge` | BIGINT | Outgoing edge ID (−1 for last node) |
| `cost` | FLOAT8 | Cost of the outgoing edge (0 for last node) |
| `agg_cost` | FLOAT8 | Cumulative cost from source to this node |

### Example

```sql
CREATE TABLE edges (id SERIAL, source BIGINT, target BIGINT, cost FLOAT8);
INSERT INTO edges VALUES (1, 1, 2, 1.5), (2, 2, 3, 2.0), (3, 3, 4, 0.5);

SELECT seq, path_seq, node, edge, cost, agg_cost
FROM pgr_dmmsy('SELECT id, source, target, cost FROM edges', 1, 4)
ORDER BY path_seq;

 seq | path_seq | node | edge | cost | agg_cost
-----+----------+------+------+------+----------
   1 |        1 |    1 |    1 |  1.5 |      0.0
   2 |        2 |    2 |    2 |  2.0 |      1.5
   3 |        3 |    3 |    3 |  0.5 |      3.5
   4 |        4 |    4 |   -1 |  0.0 |      4.0
```

### Distance map (all reachable vertices)

```sql
SELECT node, agg_cost
FROM pgr_dmmsy('SELECT id, source, target, cost FROM edges', 1)
ORDER BY agg_cost;
```

---

## Algorithm parameters

| Parameter | Default | Effect |
|---|---|---|
| `param_k` | ceil(log n)^(2/3) | BF rounds per phase — higher = more thorough relaxation |
| `param_t` | ceil(log n)^(1/3) | Phase-width exponent — higher = smaller blocks |
| `max_levels` | unlimited | Cap phases (useful for time-bounded queries) |

Set `param_k=1, param_t=1` to approximate Dijkstra-equivalent behaviour for
baseline comparison.

---

## Testing

Three independent layers — run in order during development:

```bash
# Layer 1: C unit tests (no PostgreSQL needed, runs in seconds)
cd test/c && make clean && make run

# Layer 2: pgxs regression tests
make installcheck

# Layer 3: SQL verification suite (compares against pgr_dijkstra)
bash verify/tests/run_all.sh mydb
```

See **[COMPILE.md](COMPILE.md)** for the full test guide.

---

## Downloads

Pre-built binaries are attached to each [GitHub Release](https://github.com/offline-agency/pgr_dmmsy/releases):

| Platform | File |
|---|---|
| Linux x86_64 (PG 14) | `pgr_dmmsy-linux-pg14-x86_64.tar.gz` |
| Linux x86_64 (PG 15) | `pgr_dmmsy-linux-pg15-x86_64.tar.gz` |
| Linux x86_64 (PG 16) | `pgr_dmmsy-linux-pg16-x86_64.tar.gz` |
| macOS arm64 (PG 16)  | `pgr_dmmsy-macos-pg16-arm64.tar.gz` |

Each archive contains the `.so`/`.dylib`, the SQL file, and the `.control`
file. Copy them into your PostgreSQL `pkglibdir` / `sharedir/extension`
directories, then `CREATE EXTENSION pgr_dmmsy`.

---

## References

- Paper: [arxiv.org/abs/2504.17033](https://arxiv.org/abs/2504.17033)
- pgRouting: [pgrouting.org](https://pgrouting.org/)
- PostgreSQL extensions: [postgresql.org/docs](https://www.postgresql.org/docs/current/extend-pgxs.html)

---
