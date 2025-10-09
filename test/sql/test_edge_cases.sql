-- Edge case tests

CREATE TABLE IF NOT EXISTS test_edges (
    id BIGSERIAL PRIMARY KEY,
    source BIGINT NOT NULL,
    target BIGINT NOT NULL,
    cost FLOAT8 NOT NULL
);

\echo 'Testing edge cases...'

-- Test 1: Very small costs
TRUNCATE test_edges;
INSERT INTO test_edges (id, source, target, cost) VALUES
    (1, 1, 2, 0.000001),
    (2, 2, 3, 0.000002),
    (3, 3, 4, 0.000003);

SELECT '=== Test: Very Small Costs ===' AS test_name;
SELECT * FROM pgr_dmmsy(
    'SELECT id, source, target, cost FROM test_edges',
    1, 4
) ORDER BY path_seq;

-- Test 2: Very large costs
TRUNCATE test_edges;
INSERT INTO test_edges (id, source, target, cost) VALUES
    (1, 1, 2, 1000000.0),
    (2, 2, 3, 2000000.0);

SELECT '=== Test: Very Large Costs ===' AS test_name;
SELECT * FROM pgr_dmmsy(
    'SELECT id, source, target, cost FROM test_edges',
    1, 3
) ORDER BY path_seq;

-- Test 3: Single edge graph
TRUNCATE test_edges;
INSERT INTO test_edges (id, source, target, cost) VALUES
    (1, 100, 200, 5.5);

SELECT '=== Test: Single Edge Graph ===' AS test_name;
SELECT * FROM pgr_dmmsy(
    'SELECT id, source, target, cost FROM test_edges',
    100, 200
) ORDER BY path_seq;

-- Test 4: Many parallel edges
TRUNCATE test_edges;
INSERT INTO test_edges (id, source, target, cost) VALUES
    (1, 1, 2, 10.0),
    (2, 1, 2, 5.0),
    (3, 1, 2, 7.0),
    (4, 1, 2, 3.0),
    (5, 1, 2, 15.0);

SELECT '=== Test: Many Parallel Edges (should pick 3.0) ===' AS test_name;
SELECT * FROM pgr_dmmsy(
    'SELECT id, source, target, cost FROM test_edges',
    1, 2
) ORDER BY path_seq;

-- Test 5: Graph with self-loops
TRUNCATE test_edges;
INSERT INTO test_edges (id, source, target, cost) VALUES
    (1, 1, 1, 1.0),
    (2, 1, 2, 2.0),
    (3, 2, 2, 1.0),
    (4, 2, 3, 3.0);

SELECT '=== Test: Graph With Self-Loops ===' AS test_name;
SELECT * FROM pgr_dmmsy(
    'SELECT id, source, target, cost FROM test_edges',
    1, 3
) ORDER BY path_seq;

-- Test 6: Vertex IDs in reverse order
TRUNCATE test_edges;
INSERT INTO test_edges (id, source, target, cost) VALUES
    (1, 1000, 900, 1.0),
    (2, 900, 800, 1.0),
    (3, 800, 700, 1.0);

SELECT '=== Test: Decreasing Vertex IDs ===' AS test_name;
SELECT * FROM pgr_dmmsy(
    'SELECT id, source, target, cost FROM test_edges',
    1000, 700
) ORDER BY path_seq;

-- Test 7: Negative vertex IDs (valid in PostgreSQL BIGINT)
TRUNCATE test_edges;
INSERT INTO test_edges (id, source, target, cost) VALUES
    (1, -10, -5, 2.0),
    (2, -5, 0, 3.0),
    (3, 0, 10, 4.0);

SELECT '=== Test: Negative Vertex IDs ===' AS test_name;
SELECT * FROM pgr_dmmsy(
    'SELECT id, source, target, cost FROM test_edges',
    -10, 10
) ORDER BY path_seq;

-- Cleanup
DROP TABLE test_edges;

\echo 'Edge case tests completed.'

