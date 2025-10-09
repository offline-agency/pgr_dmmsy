-- Performance tests

CREATE TABLE IF NOT EXISTS test_edges (
    id BIGSERIAL PRIMARY KEY,
    source BIGINT NOT NULL,
    target BIGINT NOT NULL,
    cost FLOAT8 NOT NULL
);

\echo 'Testing performance with larger graphs...'

-- Test 1: Linear chain of 100 vertices
TRUNCATE test_edges;
INSERT INTO test_edges (id, source, target, cost)
SELECT i, i, i+1, random() * 10
FROM generate_series(1, 99) i;

\echo '=== Test: Linear Chain (100 vertices) ==='
\timing on
SELECT COUNT(*) as path_length FROM pgr_dmmsy(
    'SELECT id, source, target, cost FROM test_edges',
    1, 100
);
\timing off

-- Test 2: Dense graph (complete graph K10)
TRUNCATE test_edges;
INSERT INTO test_edges (id, source, target, cost)
SELECT row_number() OVER (), i, j, random() * 10
FROM generate_series(1, 10) i,
     generate_series(1, 10) j
WHERE i <> j;

\echo '=== Test: Complete Graph K10 (90 edges) ==='
\timing on
SELECT COUNT(*) as path_length FROM pgr_dmmsy(
    'SELECT id, source, target, cost FROM test_edges',
    1, 10
);
\timing off

-- Test 3: Star topology (one central node, 50 spokes)
TRUNCATE test_edges;
INSERT INTO test_edges (id, source, target, cost)
SELECT i, i, 100, random() * 10
FROM generate_series(1, 50) i
UNION ALL
SELECT i + 50, 100, i + 100, random() * 10
FROM generate_series(1, 50) i;

\echo '=== Test: Star Topology (50 spokes, 100 edges) ==='
\timing on
SELECT COUNT(*) as path_length FROM pgr_dmmsy(
    'SELECT id, source, target, cost FROM test_edges',
    1, 150
);
\timing off

-- Test 4: Grid graph 10x10
TRUNCATE test_edges;
WITH grid AS (
    SELECT i/10 as row, i%10 as col, i as vertex
    FROM generate_series(0, 99) i
)
INSERT INTO test_edges (id, source, target, cost)
-- Horizontal edges
SELECT row_number() OVER (), 
       g1.vertex, g2.vertex, 1.0
FROM grid g1
JOIN grid g2 ON g1.row = g2.row AND g2.col = g1.col + 1
UNION ALL
-- Vertical edges
SELECT row_number() OVER () + 90,
       g1.vertex, g2.vertex, 1.0
FROM grid g1
JOIN grid g2 ON g1.col = g2.col AND g2.row = g1.row + 1;

\echo '=== Test: Grid 10x10 (180 edges) ==='
\timing on
SELECT COUNT(*) as path_length FROM pgr_dmmsy(
    'SELECT id, source, target, cost FROM test_edges',
    0, 99
);
\timing off

-- Test 5: Random graph (200 vertices, 500 edges)
TRUNCATE test_edges;
INSERT INTO test_edges (id, source, target, cost)
SELECT i,
       1 + floor(random() * 200)::int,
       1 + floor(random() * 200)::int,
       random() * 10
FROM generate_series(1, 500) i
WHERE 1 + floor(random() * 200)::int <> 1 + floor(random() * 200)::int;

\echo '=== Test: Random Graph (200 vertices, ~500 edges) ==='
\timing on
SELECT COUNT(*) as path_length FROM pgr_dmmsy(
    'SELECT id, source, target, cost FROM test_edges',
    1, 200
);
\timing off

-- Test 6: Sparse graph with large IDs
TRUNCATE test_edges;
INSERT INTO test_edges (id, source, target, cost)
SELECT i, i * 10000, (i+1) * 10000, random() * 10
FROM generate_series(1, 50) i;

\echo '=== Test: Sparse Graph (large vertex IDs) ==='
\timing on
SELECT COUNT(*) as path_length FROM pgr_dmmsy(
    'SELECT id, source, target, cost FROM test_edges',
    10000, 510000
);
\timing off

-- Cleanup
DROP TABLE test_edges;

\echo 'Performance tests completed.'

