-- Error handling and validation tests

CREATE TABLE IF NOT EXISTS test_edges (
    id BIGSERIAL PRIMARY KEY,
    source BIGINT NOT NULL,
    target BIGINT NOT NULL,
    cost FLOAT8 NOT NULL
);

\echo 'Testing error handling and validation...'

-- Test 1: Source vertex not in graph
TRUNCATE test_edges;
INSERT INTO test_edges (id, source, target, cost) VALUES
    (1, 10, 20, 1.0),
    (2, 20, 30, 1.0);

SELECT '=== Test: Source Not In Graph (returns empty) ===' AS test_name;
SELECT COUNT(*) as result_count FROM pgr_dmmsy(
    'SELECT id, source, target, cost FROM test_edges',
    999, 30  -- 999 doesn't exist
);

-- Test 2: Target vertex not in graph
SELECT '=== Test: Target Not In Graph (returns empty) ===' AS test_name;
SELECT COUNT(*) as result_count FROM pgr_dmmsy(
    'SELECT id, source, target, cost FROM test_edges',
    10, 999  -- 999 doesn't exist
);

-- Test 3: Both source and target not in graph
SELECT '=== Test: Both Source And Target Not In Graph ===' AS test_name;
SELECT COUNT(*) as result_count FROM pgr_dmmsy(
    'SELECT id, source, target, cost FROM test_edges',
    888, 999
);

-- Test 4: Empty graph (no edges, but valid query)
TRUNCATE test_edges;
SELECT '=== Test: Empty Graph ===' AS test_name;
SELECT COUNT(*) as result_count FROM pgr_dmmsy(
    'SELECT id, source, target, cost FROM test_edges',
    1, 2
);

-- Test 5: Graph with only one vertex (source = target in data)
TRUNCATE test_edges;
INSERT INTO test_edges (id, source, target, cost) VALUES
    (1, 100, 100, 0.0);

SELECT '=== Test: Single Vertex Loop ===' AS test_name;
SELECT * FROM pgr_dmmsy(
    'SELECT id, source, target, cost FROM test_edges',
    100, 100
) ORDER BY path_seq;

-- Test 6: Very long path (15 hops)
TRUNCATE test_edges;
INSERT INTO test_edges (id, source, target, cost)
SELECT i, i, i+1, 1.0
FROM generate_series(1, 15) i;

SELECT '=== Test: Very Long Path (15 hops) ===' AS test_name;
SELECT COUNT(*) as path_length FROM pgr_dmmsy(
    'SELECT id, source, target, cost FROM test_edges',
    1, 16
);

-- Test 7: output_predecessors = FALSE (though it may not affect output much)
TRUNCATE test_edges;
INSERT INTO test_edges (id, source, target, cost) VALUES
    (1, 1, 2, 1.0),
    (2, 2, 3, 1.0);

SELECT '=== Test: output_predecessors FALSE ===' AS test_name;
SELECT * FROM pgr_dmmsy(
    'SELECT id, source, target, cost FROM test_edges',
    1, 3,
    TRUE,   -- directed
    FALSE   -- output_predecessors
) ORDER BY path_seq;

-- Test 8: Graph with high connectivity (every vertex connects to every other)
TRUNCATE test_edges;
INSERT INTO test_edges (id, source, target, cost)
SELECT row_number() OVER (), i, j, random() * 5 + 1
FROM generate_series(1, 7) i,
     generate_series(1, 7) j
WHERE i <> j;

SELECT '=== Test: Fully Connected K7 (42 edges) ===' AS test_name;
SELECT COUNT(*) as path_length FROM pgr_dmmsy(
    'SELECT id, source, target, cost FROM test_edges',
    1, 7
);

-- Test 9: Multiple queries in sequence (ensure no state leakage)
TRUNCATE test_edges;
INSERT INTO test_edges (id, source, target, cost) VALUES
    (1, 1, 2, 1.0),
    (2, 2, 3, 1.0);

SELECT '=== Test: Sequential Queries (run 1) ===' AS test_name;
SELECT * FROM pgr_dmmsy('SELECT id, source, target, cost FROM test_edges', 1, 3) ORDER BY path_seq;

SELECT '=== Test: Sequential Queries (run 2) ===' AS test_name;
SELECT * FROM pgr_dmmsy('SELECT id, source, target, cost FROM test_edges', 1, 3) ORDER BY path_seq;

-- Test 10: Different edge ID ordering
TRUNCATE test_edges;
INSERT INTO test_edges (id, source, target, cost) VALUES
    (100, 1, 2, 1.0),
    (50, 2, 3, 1.0),
    (200, 3, 4, 1.0);

SELECT '=== Test: Non-Sequential Edge IDs ===' AS test_name;
SELECT * FROM pgr_dmmsy(
    'SELECT id, source, target, cost FROM test_edges',
    1, 4
) ORDER BY path_seq;

-- Test 11: Max levels = 0 (should return empty or just source)
TRUNCATE test_edges;
INSERT INTO test_edges (id, source, target, cost) VALUES
    (1, 1, 2, 1.0);

SELECT '=== Test: max_levels = 0 ===' AS test_name;
SELECT COUNT(*) as result_count FROM pgr_dmmsy(
    'SELECT id, source, target, cost FROM test_edges',
    1, 2,
    TRUE, TRUE,
    0  -- max_levels = 0
);

-- Test 12: Max levels = 1
SELECT '=== Test: max_levels = 1 ===' AS test_name;
SELECT * FROM pgr_dmmsy(
    'SELECT id, source, target, cost FROM test_edges',
    1, 2,
    TRUE, TRUE,
    1  -- max_levels = 1
) ORDER BY path_seq;

-- Test 13: Large param_k and param_t
TRUNCATE test_edges;
INSERT INTO test_edges (id, source, target, cost) VALUES
    (1, 1, 2, 1.0),
    (2, 2, 3, 1.0);

SELECT '=== Test: Large param_k=100, param_t=50 ===' AS test_name;
SELECT * FROM pgr_dmmsy(
    'SELECT id, source, target, cost FROM test_edges',
    1, 3,
    TRUE, TRUE, NULL,
    100, 50  -- param_k, param_t
) ORDER BY path_seq;

-- Test 14: constant_degree = TRUE
SELECT '=== Test: constant_degree TRUE ===' AS test_name;
SELECT * FROM pgr_dmmsy(
    'SELECT id, source, target, cost FROM test_edges',
    1, 3,
    TRUE, TRUE, NULL, NULL, NULL,
    TRUE  -- constant_degree
) ORDER BY path_seq;

-- Test 15: Very small max_levels with long path
TRUNCATE test_edges;
INSERT INTO test_edges (id, source, target, cost)
SELECT i, i, i+1, 1.0
FROM generate_series(1, 20) i;

SELECT '=== Test: max_levels=3 with long path (21 vertices) ===' AS test_name;
SELECT COUNT(*) as result_count FROM pgr_dmmsy(
    'SELECT id, source, target, cost FROM test_edges',
    1, 21,
    TRUE, TRUE,
    3  -- max_levels
);

-- Cleanup
DROP TABLE test_edges;

\echo 'Error handling tests completed.'

