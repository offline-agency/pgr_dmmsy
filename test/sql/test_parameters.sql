-- Parameter testing

CREATE TABLE IF NOT EXISTS test_edges (
    id BIGSERIAL PRIMARY KEY,
    source BIGINT NOT NULL,
    target BIGINT NOT NULL,
    cost FLOAT8 NOT NULL
);

\echo 'Testing different parameter combinations...'

-- Setup a test graph
TRUNCATE test_edges;
INSERT INTO test_edges (id, source, target, cost) VALUES
    (1, 1, 2, 1.0),
    (2, 2, 3, 1.0),
    (3, 3, 4, 1.0),
    (4, 4, 5, 1.0),
    (5, 1, 3, 3.0),
    (6, 2, 4, 3.0);

-- Test 1: Directed = TRUE
SELECT '=== Test: Directed TRUE ===' AS test_name;
SELECT * FROM pgr_dmmsy(
    'SELECT id, source, target, cost FROM test_edges',
    1, 5,
    TRUE  -- directed
) ORDER BY path_seq;

-- Test 2: Directed = FALSE (undirected)
SELECT '=== Test: Directed FALSE (undirected) ===' AS test_name;
SELECT * FROM pgr_dmmsy(
    'SELECT id, source, target, cost FROM test_edges',
    5, 1,
    FALSE  -- undirected
) ORDER BY path_seq;

-- Test 3: max_levels = 2
SELECT '=== Test: max_levels = 2 ===' AS test_name;
SELECT * FROM pgr_dmmsy(
    'SELECT id, source, target, cost FROM test_edges',
    1, 5,
    TRUE,  -- directed
    TRUE,  -- output_predecessors
    2      -- max_levels
) ORDER BY path_seq;

-- Test 4: max_levels = 10 (more than needed)
SELECT '=== Test: max_levels = 10 ===' AS test_name;
SELECT * FROM pgr_dmmsy(
    'SELECT id, source, target, cost FROM test_edges',
    1, 5,
    TRUE,  -- directed
    TRUE,  -- output_predecessors
    10     -- max_levels
) ORDER BY path_seq;

-- Test 5: param_k = 5
SELECT '=== Test: param_k = 5 ===' AS test_name;
SELECT * FROM pgr_dmmsy(
    'SELECT id, source, target, cost FROM test_edges',
    1, 5,
    TRUE,  -- directed
    TRUE,  -- output_predecessors
    NULL,  -- max_levels
    5      -- param_k
) ORDER BY path_seq;

-- Test 6: param_t = 3
SELECT '=== Test: param_t = 3 ===' AS test_name;
SELECT * FROM pgr_dmmsy(
    'SELECT id, source, target, cost FROM test_edges',
    1, 5,
    TRUE,  -- directed
    TRUE,  -- output_predecessors
    NULL,  -- max_levels
    NULL,  -- param_k
    3      -- param_t
) ORDER BY path_seq;

-- Test 7: Both param_k and param_t
SELECT '=== Test: param_k = 10, param_t = 5 ===' AS test_name;
SELECT * FROM pgr_dmmsy(
    'SELECT id, source, target, cost FROM test_edges',
    1, 5,
    TRUE,  -- directed
    TRUE,  -- output_predecessors
    NULL,  -- max_levels
    10,    -- param_k
    5      -- param_t
) ORDER BY path_seq;

-- Test 8: target = NULL (would compute all paths, but we don't show all here)
SELECT '=== Test: target = NULL (returns empty in current impl) ===' AS test_name;
SELECT * FROM pgr_dmmsy(
    'SELECT id, source, target, cost FROM test_edges',
    1, NULL
) ORDER BY path_seq LIMIT 5;

-- Test 9: All default parameters
SELECT '=== Test: All Default Parameters ===' AS test_name;
SELECT * FROM pgr_dmmsy(
    'SELECT id, source, target, cost FROM test_edges',
    1, 5
) ORDER BY path_seq;

-- Test 10: constant_degree parameter (currently not used, but test it doesn't break)
SELECT '=== Test: constant_degree = TRUE ===' AS test_name;
SELECT * FROM pgr_dmmsy(
    'SELECT id, source, target, cost FROM test_edges',
    1, 5,
    TRUE,  -- directed
    TRUE,  -- output_predecessors
    NULL,  -- max_levels
    NULL,  -- param_k
    NULL,  -- param_t
    TRUE   -- constant_degree
) ORDER BY path_seq;

-- Cleanup
DROP TABLE test_edges;

\echo 'Parameter tests completed.'

