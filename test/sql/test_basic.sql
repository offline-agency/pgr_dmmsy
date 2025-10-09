-- Basic functionality tests

-- Setup
CREATE TABLE IF NOT EXISTS test_edges (
    id BIGSERIAL PRIMARY KEY,
    source BIGINT NOT NULL,
    target BIGINT NOT NULL,
    cost FLOAT8 NOT NULL
);

\echo 'Testing basic single-source shortest path...'

-- Test 1: Simple linear path
TRUNCATE test_edges;
INSERT INTO test_edges (id, source, target, cost) VALUES
    (1, 1, 2, 1.0),
    (2, 2, 3, 1.0),
    (3, 3, 4, 1.0);

SELECT '=== Test: Simple Linear Path ===' AS test_name;
SELECT * FROM pgr_dmmsy(
    'SELECT id, source, target, cost FROM test_edges',
    1, 4
) ORDER BY path_seq;

-- Test 2: Multiple paths - choose shortest
TRUNCATE test_edges;
INSERT INTO test_edges (id, source, target, cost) VALUES
    (1, 1, 2, 1.0),
    (2, 2, 4, 1.0),
    (3, 1, 3, 5.0),
    (4, 3, 4, 5.0);

SELECT '=== Test: Multiple Paths - Choose Shortest ===' AS test_name;
SELECT * FROM pgr_dmmsy(
    'SELECT id, source, target, cost FROM test_edges',
    1, 4
) ORDER BY path_seq;

-- Test 3: Single vertex (source = target)
TRUNCATE test_edges;
INSERT INTO test_edges (id, source, target, cost) VALUES
    (1, 1, 2, 1.0);

SELECT '=== Test: Source Equals Target ===' AS test_name;
SELECT * FROM pgr_dmmsy(
    'SELECT id, source, target, cost FROM test_edges',
    1, 1
) ORDER BY path_seq;

-- Test 4: No path exists
TRUNCATE test_edges;
INSERT INTO test_edges (id, source, target, cost) VALUES
    (1, 1, 2, 1.0),
    (2, 3, 4, 1.0);

SELECT '=== Test: No Path Exists ===' AS test_name;
SELECT * FROM pgr_dmmsy(
    'SELECT id, source, target, cost FROM test_edges',
    1, 4
) ORDER BY path_seq;

-- Cleanup
DROP TABLE test_edges;

\echo 'Basic tests completed.'

