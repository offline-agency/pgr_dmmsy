-- Stress and large graph tests

CREATE TABLE IF NOT EXISTS test_edges (
    id BIGSERIAL PRIMARY KEY,
    source BIGINT NOT NULL,
    target BIGINT NOT NULL,
    cost FLOAT8 NOT NULL
);

\echo 'Running stress tests...'

-- Test 1: Large linear chain (500 vertices)
TRUNCATE test_edges;
INSERT INTO test_edges (id, source, target, cost)
SELECT i, i, i+1, random() * 10
FROM generate_series(1, 499) i;

\echo '=== Test: Large Linear Chain (500 vertices) ==='
\timing on
SELECT COUNT(*) as path_length FROM pgr_dmmsy(
    'SELECT id, source, target, cost FROM test_edges',
    1, 500
);
\timing off

-- Test 2: Large complete graph K20 (380 edges)
TRUNCATE test_edges;
INSERT INTO test_edges (id, source, target, cost)
SELECT row_number() OVER (), i, j, random() * 10 + 1
FROM generate_series(1, 20) i,
     generate_series(1, 20) j
WHERE i < j;

\echo '=== Test: Complete Graph K20 (380 edges) ==='
\timing on
SELECT COUNT(*) as path_length FROM pgr_dmmsy(
    'SELECT id, source, target, cost FROM test_edges',
    1, 20
);
\timing off

-- Test 3: Large grid 20x20 (760 edges)
TRUNCATE test_edges;
WITH grid AS (
    SELECT i/20 as row, i%20 as col, i as vertex
    FROM generate_series(0, 399) i
)
INSERT INTO test_edges (id, source, target, cost)
SELECT row_number() OVER (), 
       g1.vertex, g2.vertex, 1.0
FROM grid g1
JOIN grid g2 ON (g1.row = g2.row AND g2.col = g1.col + 1)
              OR (g1.col = g2.col AND g2.row = g1.row + 1);

\echo '=== Test: Grid 20x20 (400 vertices, 760 edges) ==='
\timing on
SELECT COUNT(*) as path_length FROM pgr_dmmsy(
    'SELECT id, source, target, cost FROM test_edges',
    0, 399
);
\timing off

-- Test 4: Random sparse graph (1000 vertices, 2000 edges)
TRUNCATE test_edges;
INSERT INTO test_edges (id, source, target, cost)
SELECT i,
       1 + floor(random() * 1000)::int,
       1 + floor(random() * 1000)::int,
       random() * 10 + 0.1
FROM generate_series(1, 2000) i
WHERE 1 + floor(random() * 1000)::int <> 1 + floor(random() * 1000)::int;

\echo '=== Test: Random Sparse Graph (1000 vertices, ~2000 edges) ==='
\timing on
SELECT COUNT(*) as result_count FROM pgr_dmmsy(
    'SELECT id, source, target, cost FROM test_edges WHERE cost > 0',
    1, 1000
);
\timing off

-- Test 5: Star topology with 100 spokes
TRUNCATE test_edges;
INSERT INTO test_edges (id, source, target, cost)
SELECT i, i, 500, random() * 10
FROM generate_series(1, 100) i
UNION ALL
SELECT i + 100, 500, i + 500, random() * 10
FROM generate_series(1, 100) i;

\echo '=== Test: Star Topology (100 spokes, 200 edges) ==='
\timing on
SELECT COUNT(*) as path_length FROM pgr_dmmsy(
    'SELECT id, source, target, cost FROM test_edges',
    1, 600
);
\timing off

-- Test 6: Deep tree (binary tree, 7 levels, 127 vertices)
TRUNCATE test_edges;
INSERT INTO test_edges (id, source, target, cost)
SELECT i, i, 2*i, 1.0 FROM generate_series(1, 63) i
UNION ALL
SELECT i + 63, i, 2*i+1, 1.0 FROM generate_series(1, 63) i;

\echo '=== Test: Binary Tree (7 levels, 127 vertices) ==='
\timing on
SELECT COUNT(*) as path_length FROM pgr_dmmsy(
    'SELECT id, source, target, cost FROM test_edges',
    1, 127
);
\timing off

-- Test 7: Multiple disconnected components (10 components of 10 vertices each)
TRUNCATE test_edges;
INSERT INTO test_edges (id, source, target, cost)
SELECT row_number() OVER (),
       i*10 + j,
       i*10 + ((j % 10) + 1),
       random() * 5 + 1
FROM generate_series(0, 9) i,
     generate_series(1, 10) j;

\echo '=== Test: 10 Disconnected Components (100 vertices) ==='
\timing on
SELECT COUNT(*) as result_count FROM pgr_dmmsy(
    'SELECT id, source, target, cost FROM test_edges',
    1, 91  -- From component 0 to component 9
);
\timing off

-- Test 8: Graph with varying density
TRUNCATE test_edges;
-- Dense part (1-50): many edges
INSERT INTO test_edges (id, source, target, cost)
SELECT row_number() OVER (), i, j, random() * 3
FROM generate_series(1, 50) i,
     generate_series(1, 50) j
WHERE i <> j AND random() < 0.3;  -- 30% density

-- Sparse part (51-100): few edges
INSERT INTO test_edges (id, source, target, cost)
SELECT (SELECT MAX(id) FROM test_edges) + row_number() OVER (),
       i, i+1, random() * 5
FROM generate_series(51, 99) i;

\echo '=== Test: Mixed Density Graph (dense + sparse) ==='
\timing on
SELECT COUNT(*) as path_length FROM pgr_dmmsy(
    'SELECT id, source, target, cost FROM test_edges WHERE cost > 0',
    1, 100
);
\timing off

-- Test 9: Path with many equal-cost alternatives
TRUNCATE test_edges;
WITH RECURSIVE levels(lvl, node) AS (
    SELECT 0, 1
    UNION ALL
    SELECT lvl + 1, node * 3 + i
    FROM levels, generate_series(0, 2) i
    WHERE lvl < 4
)
INSERT INTO test_edges (id, source, target, cost)
SELECT row_number() OVER (),
       node, node * 3 + i, 1.0
FROM levels, generate_series(0, 2) i
WHERE lvl < 4;

\echo '=== Test: Ternary Tree (many equal paths) ==='
\timing on
SELECT COUNT(*) as path_length FROM pgr_dmmsy(
    'SELECT id, source, target, cost FROM test_edges',
    1, 121  -- Bottom level
);
\timing off

-- Test 10: Very high degree vertex (hub with 200 connections)
TRUNCATE test_edges;
INSERT INTO test_edges (id, source, target, cost)
SELECT i, i, 10000, random() * 5
FROM generate_series(1, 200) i
UNION ALL
SELECT i + 200, 10000, i + 10000, random() * 5
FROM generate_series(1, 200) i;

\echo '=== Test: High Degree Hub (degree 400) ==='
\timing on
SELECT COUNT(*) as path_length FROM pgr_dmmsy(
    'SELECT id, source, target, cost FROM test_edges',
    1, 10100
);
\timing off

-- Cleanup
DROP TABLE test_edges;

\echo 'Stress tests completed.'

