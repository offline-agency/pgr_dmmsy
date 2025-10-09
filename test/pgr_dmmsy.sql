-- Test suite for pgr_dmmsy extension

-- Create test table
CREATE TABLE test_edges (
    id BIGSERIAL PRIMARY KEY,
    source BIGINT NOT NULL,
    target BIGINT NOT NULL,
    cost FLOAT8 NOT NULL
);

-- Test case 1: Simple path
-- Graph: 1 -> 2 -> 3 -> 4
INSERT INTO test_edges (id, source, target, cost) VALUES
    (1, 1, 2, 1.0),
    (2, 2, 3, 2.0),
    (3, 3, 4, 3.0);

SELECT '-- Test 1: Simple directed path from 1 to 4' AS test;
SELECT * FROM pgr_dmmsy(
    'SELECT id, source, target, cost FROM test_edges',
    1,  -- source
    4   -- target
) ORDER BY path_seq;

-- Test case 2: Graph with branching
TRUNCATE test_edges;
INSERT INTO test_edges (id, source, target, cost) VALUES
    (1, 1, 2, 1.0),
    (2, 1, 3, 4.0),
    (3, 2, 3, 1.0),
    (4, 2, 4, 5.0),
    (5, 3, 4, 1.0);

SELECT '-- Test 2: Shortest path with branching (1 -> 2 -> 3 -> 4)' AS test;
SELECT * FROM pgr_dmmsy(
    'SELECT id, source, target, cost FROM test_edges',
    1,  -- source
    4   -- target
) ORDER BY path_seq;

-- Test case 3: Undirected graph
SELECT '-- Test 3: Undirected graph' AS test;
SELECT * FROM pgr_dmmsy(
    'SELECT id, source, target, cost FROM test_edges',
    4,  -- source
    1,  -- target
    FALSE  -- undirected
) ORDER BY path_seq;

-- Test case 4: More complex graph
TRUNCATE test_edges;
INSERT INTO test_edges (id, source, target, cost) VALUES
    (1, 1, 2, 7.0),
    (2, 1, 3, 9.0),
    (3, 1, 6, 14.0),
    (4, 2, 3, 10.0),
    (5, 2, 4, 15.0),
    (6, 3, 4, 11.0),
    (7, 3, 6, 2.0),
    (8, 4, 5, 6.0),
    (9, 5, 6, 9.0);

SELECT '-- Test 4: Complex graph - shortest path from 1 to 5' AS test;
SELECT * FROM pgr_dmmsy(
    'SELECT id, source, target, cost FROM test_edges',
    1,  -- source
    5   -- target
) ORDER BY path_seq;

-- Test case 5: Multiple shortest paths from source (no target)
TRUNCATE test_edges;
INSERT INTO test_edges (id, source, target, cost) VALUES
    (1, 1, 2, 1.0),
    (2, 1, 3, 2.0),
    (3, 2, 4, 1.0),
    (4, 3, 4, 1.0);

SELECT '-- Test 5: Source to specific target' AS test;
SELECT * FROM pgr_dmmsy(
    'SELECT id, source, target, cost FROM test_edges',
    1,  -- source
    4   -- target
) ORDER BY path_seq;

-- Test case 6: Disconnected graph (no path)
TRUNCATE test_edges;
INSERT INTO test_edges (id, source, target, cost) VALUES
    (1, 1, 2, 1.0),
    (2, 3, 4, 1.0);

SELECT '-- Test 6: Disconnected graph (should return empty)' AS test;
SELECT * FROM pgr_dmmsy(
    'SELECT id, source, target, cost FROM test_edges',
    1,  -- source
    4   -- target
) ORDER BY path_seq;

-- Test case 7: Self loop
TRUNCATE test_edges;
INSERT INTO test_edges (id, source, target, cost) VALUES
    (1, 1, 1, 0.0);

SELECT '-- Test 7: Self loop (1 -> 1)' AS test;
SELECT * FROM pgr_dmmsy(
    'SELECT id, source, target, cost FROM test_edges',
    1,  -- source
    1   -- target
) ORDER BY path_seq;

-- Test case 8: Triangle with different costs
TRUNCATE test_edges;
INSERT INTO test_edges (id, source, target, cost) VALUES
    (1, 1, 2, 1.0),
    (2, 2, 3, 1.0),
    (3, 1, 3, 10.0);

SELECT '-- Test 8: Triangle - verify shortest path (1 -> 2 -> 3 not 1 -> 3)' AS test;
SELECT * FROM pgr_dmmsy(
    'SELECT id, source, target, cost FROM test_edges',
    1,  -- source
    3   -- target
) ORDER BY path_seq;

-- Test case 9: Testing with max_levels parameter
TRUNCATE test_edges;
INSERT INTO test_edges (id, source, target, cost) VALUES
    (1, 1, 2, 1.0),
    (2, 2, 3, 1.0),
    (3, 3, 4, 1.0),
    (4, 4, 5, 1.0);

SELECT '-- Test 9: Max levels = 2 (should not reach 5)' AS test;
SELECT * FROM pgr_dmmsy(
    'SELECT id, source, target, cost FROM test_edges',
    1,     -- source
    5,     -- target
    TRUE,  -- directed
    TRUE,  -- output_predecessors
    2      -- max_levels
) ORDER BY path_seq;

-- Test case 10: Larger graph
TRUNCATE test_edges;
INSERT INTO test_edges (id, source, target, cost) VALUES
    (1, 1, 2, 1.0),
    (2, 1, 3, 4.0),
    (3, 2, 3, 2.0),
    (4, 2, 4, 5.0),
    (5, 3, 4, 1.0),
    (6, 3, 5, 3.0),
    (7, 4, 5, 2.0),
    (8, 4, 6, 1.0),
    (9, 5, 6, 4.0),
    (10, 1, 7, 10.0),
    (11, 7, 6, 1.0);

SELECT '-- Test 10: Larger graph - multiple paths from 1 to 6' AS test;
SELECT * FROM pgr_dmmsy(
    'SELECT id, source, target, cost FROM test_edges',
    1,  -- source
    6   -- target
) ORDER BY path_seq;

-- Test case 11: Large vertex IDs (sparse ID space)
TRUNCATE test_edges;
INSERT INTO test_edges (id, source, target, cost) VALUES
    (1, 1000, 2000, 5.5),
    (2, 2000, 3000, 3.3),
    (3, 3000, 4000, 2.2),
    (4, 1000, 4000, 15.0);

SELECT '-- Test 11: Large vertex IDs' AS test;
SELECT * FROM pgr_dmmsy(
    'SELECT id, source, target, cost FROM test_edges',
    1000,  -- source
    4000   -- target
) ORDER BY path_seq;

-- Test case 12: Fractional/decimal costs
TRUNCATE test_edges;
INSERT INTO test_edges (id, source, target, cost) VALUES
    (1, 1, 2, 0.123),
    (2, 2, 3, 0.456),
    (3, 3, 4, 0.789),
    (4, 1, 3, 0.6),
    (5, 2, 4, 1.0);

SELECT '-- Test 12: Fractional costs' AS test;
SELECT * FROM pgr_dmmsy(
    'SELECT id, source, target, cost FROM test_edges',
    1,
    4
) ORDER BY path_seq;

-- Test case 13: Cycle with shortest path going through
TRUNCATE test_edges;
INSERT INTO test_edges (id, source, target, cost) VALUES
    (1, 1, 2, 1.0),
    (2, 2, 3, 1.0),
    (3, 3, 4, 1.0),
    (4, 4, 2, 1.0),  -- Creates cycle 2->3->4->2
    (5, 4, 5, 1.0);

SELECT '-- Test 13: Graph with cycle' AS test;
SELECT * FROM pgr_dmmsy(
    'SELECT id, source, target, cost FROM test_edges',
    1,
    5
) ORDER BY path_seq;

-- Test case 14: Star topology (one central node)
TRUNCATE test_edges;
INSERT INTO test_edges (id, source, target, cost) VALUES
    (1, 1, 100, 1.0),  -- Center is 100
    (2, 2, 100, 2.0),
    (3, 3, 100, 3.0),
    (4, 4, 100, 4.0),
    (5, 5, 100, 5.0),
    (6, 100, 999, 1.0);

SELECT '-- Test 14: Star topology (1 -> 100 -> 999)' AS test;
SELECT * FROM pgr_dmmsy(
    'SELECT id, source, target, cost FROM test_edges',
    1,
    999
) ORDER BY path_seq;

-- Test case 15: Grid-like graph (4x4)
TRUNCATE test_edges;
INSERT INTO test_edges (id, source, target, cost) VALUES
    -- Row 1
    (1, 1, 2, 1.0), (2, 2, 3, 1.0), (3, 3, 4, 1.0),
    -- Row 2
    (4, 5, 6, 1.0), (5, 6, 7, 1.0), (6, 7, 8, 1.0),
    -- Row 3
    (7, 9, 10, 1.0), (8, 10, 11, 1.0), (9, 11, 12, 1.0),
    -- Row 4
    (10, 13, 14, 1.0), (11, 14, 15, 1.0), (12, 15, 16, 1.0),
    -- Vertical connections
    (13, 1, 5, 1.0), (14, 5, 9, 1.0), (15, 9, 13, 1.0),
    (16, 2, 6, 1.0), (17, 6, 10, 1.0), (18, 10, 14, 1.0),
    (19, 3, 7, 1.0), (20, 7, 11, 1.0), (21, 11, 15, 1.0),
    (22, 4, 8, 1.0), (23, 8, 12, 1.0), (24, 12, 16, 1.0);

SELECT '-- Test 15: 4x4 Grid (1 to 16)' AS test;
SELECT * FROM pgr_dmmsy(
    'SELECT id, source, target, cost FROM test_edges',
    1,
    16
) ORDER BY path_seq;

-- Test case 16: Multiple disconnected components
TRUNCATE test_edges;
INSERT INTO test_edges (id, source, target, cost) VALUES
    -- Component 1
    (1, 1, 2, 1.0),
    (2, 2, 3, 1.0),
    -- Component 2
    (3, 10, 11, 1.0),
    (4, 11, 12, 1.0),
    -- Component 3
    (5, 20, 21, 1.0);

SELECT '-- Test 16: Multiple components (1 to 2, 10 unreachable)' AS test;
SELECT * FROM pgr_dmmsy(
    'SELECT id, source, target, cost FROM test_edges',
    1,
    2
) ORDER BY path_seq;

SELECT '-- Test 16b: Unreachable component' AS test;
SELECT * FROM pgr_dmmsy(
    'SELECT id, source, target, cost FROM test_edges',
    1,
    10
) ORDER BY path_seq;

-- Test case 17: Long chain
TRUNCATE test_edges;
INSERT INTO test_edges (id, source, target, cost) VALUES
    (1, 1, 2, 1.0), (2, 2, 3, 1.0), (3, 3, 4, 1.0),
    (4, 4, 5, 1.0), (5, 5, 6, 1.0), (6, 6, 7, 1.0),
    (7, 7, 8, 1.0), (8, 8, 9, 1.0), (9, 9, 10, 1.0),
    (10, 10, 11, 1.0), (11, 11, 12, 1.0), (12, 12, 13, 1.0),
    (13, 13, 14, 1.0), (14, 14, 15, 1.0), (15, 15, 16, 1.0);

SELECT '-- Test 17: Long chain (1 to 16)' AS test;
SELECT * FROM pgr_dmmsy(
    'SELECT id, source, target, cost FROM test_edges',
    1,
    16
) ORDER BY path_seq;

-- Test case 18: Parallel edges (multiple edges between same vertices)
TRUNCATE test_edges;
INSERT INTO test_edges (id, source, target, cost) VALUES
    (1, 1, 2, 10.0),  -- Expensive path
    (2, 1, 2, 2.0),   -- Cheaper parallel edge
    (3, 1, 2, 5.0),   -- Medium cost parallel edge
    (4, 2, 3, 1.0);

SELECT '-- Test 18: Parallel edges (should choose cheapest)' AS test;
SELECT * FROM pgr_dmmsy(
    'SELECT id, source, target, cost FROM test_edges',
    1,
    3
) ORDER BY path_seq;

-- Test case 19: Zero-cost edges
TRUNCATE test_edges;
INSERT INTO test_edges (id, source, target, cost) VALUES
    (1, 1, 2, 0.0),
    (2, 2, 3, 0.0),
    (3, 3, 4, 1.0),
    (4, 1, 4, 2.0);

SELECT '-- Test 19: Zero-cost edges' AS test;
SELECT * FROM pgr_dmmsy(
    'SELECT id, source, target, cost FROM test_edges',
    1,
    4
) ORDER BY path_seq;

-- Test case 20: Custom k and t parameters
TRUNCATE test_edges;
INSERT INTO test_edges (id, source, target, cost) VALUES
    (1, 1, 2, 1.0),
    (2, 2, 3, 2.0),
    (3, 3, 4, 3.0),
    (4, 1, 3, 5.0),
    (5, 2, 4, 4.0);

SELECT '-- Test 20: Custom k=10, t=5 parameters' AS test;
SELECT * FROM pgr_dmmsy(
    'SELECT id, source, target, cost FROM test_edges',
    1,     -- source
    4,     -- target
    TRUE,  -- directed
    TRUE,  -- output_predecessors
    NULL,  -- max_levels
    10,    -- param_k
    5      -- param_t
) ORDER BY path_seq;

-- Test case 21: Dense graph (complete graph K5)
TRUNCATE test_edges;
INSERT INTO test_edges (id, source, target, cost) VALUES
    -- All pairs with varying costs
    (1, 1, 2, 2.0), (2, 1, 3, 5.0), (3, 1, 4, 7.0), (4, 1, 5, 10.0),
    (5, 2, 1, 2.0), (6, 2, 3, 3.0), (7, 2, 4, 4.0), (8, 2, 5, 6.0),
    (9, 3, 1, 5.0), (10, 3, 2, 3.0), (11, 3, 4, 2.0), (12, 3, 5, 4.0),
    (13, 4, 1, 7.0), (14, 4, 2, 4.0), (15, 4, 3, 2.0), (16, 4, 5, 3.0),
    (17, 5, 1, 10.0), (18, 5, 2, 6.0), (19, 5, 3, 4.0), (20, 5, 4, 3.0);

SELECT '-- Test 21: Dense graph K5 (1 to 5)' AS test;
SELECT * FROM pgr_dmmsy(
    'SELECT id, source, target, cost FROM test_edges',
    1,
    5
) ORDER BY path_seq;

-- Test case 22: High-degree central vertex
TRUNCATE test_edges;
INSERT INTO test_edges (id, source, target, cost) VALUES
    (1, 1, 50, 1.0),
    -- Node 50 connects to many nodes
    (2, 50, 101, 1.0), (3, 50, 102, 1.0), (4, 50, 103, 1.0),
    (5, 50, 104, 1.0), (6, 50, 105, 1.0), (7, 50, 106, 1.0),
    (8, 50, 107, 1.0), (9, 50, 108, 1.0), (10, 50, 109, 1.0),
    (11, 50, 110, 1.0),
    -- One of them leads to target
    (12, 105, 999, 1.0);

SELECT '-- Test 22: High-degree vertex (1 -> 50 -> 105 -> 999)' AS test;
SELECT * FROM pgr_dmmsy(
    'SELECT id, source, target, cost FROM test_edges',
    1,
    999
) ORDER BY path_seq;

-- Test case 23: Diamond pattern with equal costs
TRUNCATE test_edges;
INSERT INTO test_edges (id, source, target, cost) VALUES
    (1, 1, 2, 1.0),
    (2, 1, 3, 1.0),
    (3, 2, 4, 1.0),
    (4, 3, 4, 1.0);

SELECT '-- Test 23: Diamond with equal costs (either path valid)' AS test;
SELECT * FROM pgr_dmmsy(
    'SELECT id, source, target, cost FROM test_edges',
    1,
    4
) ORDER BY path_seq;

-- Test case 24: Single edge
TRUNCATE test_edges;
INSERT INTO test_edges (id, source, target, cost) VALUES
    (1, 100, 200, 42.5);

SELECT '-- Test 24: Single edge graph' AS test;
SELECT * FROM pgr_dmmsy(
    'SELECT id, source, target, cost FROM test_edges',
    100,
    200
) ORDER BY path_seq;

-- Test case 25: Unweighted vs weighted comparison
TRUNCATE test_edges;
INSERT INTO test_edges (id, source, target, cost) VALUES
    (1, 1, 2, 1.0),
    (2, 2, 3, 1.0),
    (3, 3, 4, 1.0),
    (4, 1, 4, 2.5);  -- Shorter in hops but more expensive

SELECT '-- Test 25: Weighted path selection' AS test;
SELECT * FROM pgr_dmmsy(
    'SELECT id, source, target, cost FROM test_edges',
    1,
    4
) ORDER BY path_seq;

-- Test case 26: Very sparse graph (single path through many nodes)
TRUNCATE test_edges;
INSERT INTO test_edges (id, source, target, cost) VALUES
    (1, 1, 10, 1.0),
    (2, 10, 20, 2.0),
    (3, 20, 30, 3.0),
    (4, 30, 40, 4.0),
    (5, 40, 50, 5.0);

SELECT '-- Test 26: Sparse graph with large ID gaps' AS test;
SELECT * FROM pgr_dmmsy(
    'SELECT id, source, target, cost FROM test_edges',
    1,
    50
) ORDER BY path_seq;

-- Test case 27: Bottleneck path
TRUNCATE test_edges;
INSERT INTO test_edges (id, source, target, cost) VALUES
    (1, 1, 2, 0.1),
    (2, 2, 3, 0.1),
    (3, 3, 4, 100.0),  -- Bottleneck
    (4, 4, 5, 0.1),
    (5, 5, 6, 0.1);

SELECT '-- Test 27: Bottleneck path' AS test;
SELECT * FROM pgr_dmmsy(
    'SELECT id, source, target, cost FROM test_edges',
    1,
    6
) ORDER BY path_seq;

-- Test case 28: Reverse direction undirected
TRUNCATE test_edges;
INSERT INTO test_edges (id, source, target, cost) VALUES
    (1, 5, 4, 1.0),
    (2, 4, 3, 2.0),
    (3, 3, 2, 3.0),
    (4, 2, 1, 4.0);

SELECT '-- Test 28: Reverse traversal undirected' AS test;
SELECT * FROM pgr_dmmsy(
    'SELECT id, source, target, cost FROM test_edges',
    1,
    5,
    FALSE  -- undirected
) ORDER BY path_seq;

-- Test case 29: Max levels with reachable target
TRUNCATE test_edges;
INSERT INTO test_edges (id, source, target, cost) VALUES
    (1, 1, 2, 1.0),
    (2, 2, 3, 1.0),
    (3, 3, 4, 1.0);

SELECT '-- Test 29: Max levels = 5 (target at level 3, should succeed)' AS test;
SELECT * FROM pgr_dmmsy(
    'SELECT id, source, target, cost FROM test_edges',
    1,
    4,
    TRUE,
    TRUE,
    5  -- max_levels
) ORDER BY path_seq;

-- Test case 30: Alternative equal-cost paths
TRUNCATE test_edges;
INSERT INTO test_edges (id, source, target, cost) VALUES
    (1, 1, 2, 5.0),
    (2, 1, 3, 5.0),
    (3, 2, 4, 5.0),
    (4, 3, 4, 5.0);

SELECT '-- Test 30: Multiple equal-cost paths' AS test;
SELECT * FROM pgr_dmmsy(
    'SELECT id, source, target, cost FROM test_edges',
    1,
    4
) ORDER BY path_seq;

-- Clean up
DROP TABLE test_edges;
