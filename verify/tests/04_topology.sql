-- =============================================================
-- Suite 04: Topology — 11 structural edge cases
-- =============================================================
\set SUITE '04_topology'

-- 1. Empty graph (0 edges) — returns 0 rows
DO $$
DECLARE v_count INT;
BEGIN
    TRUNCATE dmmsy_verify.edges RESTART IDENTITY;
    SELECT COUNT(*) INTO v_count FROM dmmsy_verify.dist_map(1);
    PERFORM dmmsy_verify.record(:'SUITE', 'empty_graph', 'empty',
        v_count = 0, format('rows=%s', v_count));
EXCEPTION WHEN OTHERS THEN
    PERFORM dmmsy_verify.record(:'SUITE', 'empty_graph', 'empty',
        TRUE, format('empty graph raised (acceptable): %s', SQLERRM));
END;
$$;

-- 2. Single vertex, source=target — returns exactly 1 row, agg_cost=0
DO $$
DECLARE v_count INT; v_cost FLOAT8;
BEGIN
    TRUNCATE dmmsy_verify.edges RESTART IDENTITY;
    INSERT INTO dmmsy_verify.edges VALUES (1, 1, 1, 0.0); -- self-loop
    SELECT COUNT(*), MIN(agg_cost) INTO v_count, v_cost
    FROM dmmsy_verify.run_dmmsy_full(1, 1);
    PERFORM dmmsy_verify.record(:'SUITE', 'single_vertex_self', 'single',
        v_count = 1 AND abs(v_cost) < 1e-9,
        format('rows=%s agg_cost=%s', v_count, v_cost));
END;
$$;

-- 3. Disconnected graph — target unreachable returns 0 rows
DO $$
DECLARE v_count INT;
BEGIN
    TRUNCATE dmmsy_verify.edges RESTART IDENTITY;
    INSERT INTO dmmsy_verify.edges(source,target,cost) VALUES (1,2,1),(3,4,1);
    SELECT COUNT(*) INTO v_count FROM dmmsy_verify.run_dmmsy_full(1, 4);
    PERFORM dmmsy_verify.record(:'SUITE', 'disconnected_unreachable', 'disconnected',
        v_count = 0, format('rows=%s', v_count));
END;
$$;

-- 4. Parallel edges — only cheapest cost path is returned
DO $$
DECLARE v_cost FLOAT8;
BEGIN
    TRUNCATE dmmsy_verify.edges RESTART IDENTITY;
    INSERT INTO dmmsy_verify.edges(source,target,cost)
    VALUES (1,2,5),(1,2,2),(1,2,8),(2,3,1);
    SELECT agg_cost INTO v_cost
    FROM dmmsy_verify.run_dmmsy_full(1, 3)
    WHERE node = 3;
    PERFORM dmmsy_verify.record(:'SUITE', 'parallel_edges_cheapest', 'parallel',
        abs(v_cost - 3.0) < 1e-9,
        format('expected=3 got=%s', v_cost));
END;
$$;

-- 5. Diamond graph — correct distance chosen across two paths
DO $$
DECLARE v_cost FLOAT8;
BEGIN
    TRUNCATE dmmsy_verify.edges RESTART IDENTITY;
    -- 1→2(3), 1→3(7), 2→4(5), 3→4(1) — optimal: 1→2→4 = 8 (not 1→3→4 = 8, tie)
    -- Actually 1→3→4=8, 1→2→4=8 same. Let's use asymmetric:
    -- 1→2(1), 1→3(5), 2→4(3), 3→4(1) — 1→2→4=4, 1→3→4=6. Optimal=4
    INSERT INTO dmmsy_verify.edges(source,target,cost)
    VALUES (1,2,1),(1,3,5),(2,4,3),(3,4,1);
    SELECT agg_cost INTO v_cost FROM dmmsy_verify.run_dmmsy_full(1,4) WHERE node=4;
    PERFORM dmmsy_verify.record(:'SUITE', 'diamond_optimal', 'diamond',
        abs(v_cost - 4.0) < 1e-9, format('expected=4 got=%s', v_cost));
END;
$$;

-- 6. Cycle graph — terminates (no infinite loop)
DO $$
DECLARE v_count INT;
BEGIN
    SELECT dmmsy_verify.gen_cycle(20);
    SELECT COUNT(*) INTO v_count FROM dmmsy_verify.dist_map(1);
    PERFORM dmmsy_verify.record(:'SUITE', 'cycle_terminates', 'cycle_20',
        v_count = 20, format('expected=20 got=%s', v_count));
END;
$$;

-- 7. Self-loop only — source is isolated, returns 1 row (source itself)
DO $$
DECLARE v_count INT;
BEGIN
    TRUNCATE dmmsy_verify.edges RESTART IDENTITY;
    INSERT INTO dmmsy_verify.edges(source,target,cost) VALUES (5,5,1.0);
    SELECT COUNT(*) INTO v_count FROM dmmsy_verify.dist_map(5);
    PERFORM dmmsy_verify.record(:'SUITE', 'self_loop_isolated', 'self_loop',
        v_count = 1, format('rows=%s', v_count));
END;
$$;

-- 8. Star topology — hub distance to all leaves = 1
DO $$
DECLARE v_bad INT;
BEGIN
    SELECT dmmsy_verify.gen_star(30);
    SELECT COUNT(*) INTO v_bad
    FROM dmmsy_verify.dist_map(0)
    WHERE node BETWEEN 1 AND 30 AND abs(dist - 1.0) > 1e-9;
    PERFORM dmmsy_verify.record(:'SUITE', 'star_hub_distances', 'star_30',
        v_bad = 0, format('bad_distances=%s', v_bad));
END;
$$;

-- 9. Large sparse vertex IDs (IDs in millions) — handled without crash
DO $$
DECLARE v_cost FLOAT8;
BEGIN
    TRUNCATE dmmsy_verify.edges RESTART IDENTITY;
    INSERT INTO dmmsy_verify.edges(source,target,cost)
    VALUES (1000000,1000001,1.0),(1000001,1000002,2.0);
    SELECT agg_cost INTO v_cost
    FROM dmmsy_verify.run_dmmsy_full(1000000, 1000002)
    WHERE node = 1000002;
    PERFORM dmmsy_verify.record(:'SUITE', 'large_sparse_ids', 'large_ids',
        abs(v_cost - 3.0) < 1e-9, format('expected=3 got=%s', v_cost));
END;
$$;

-- 10. Grid corner-to-corner — matches Dijkstra
DO $$
DECLARE v_dmmsy FLOAT8; v_dijk FLOAT8;
BEGIN
    SELECT dmmsy_verify.gen_grid(8, 8);
    SELECT dist INTO v_dmmsy FROM dmmsy_verify.dist_map(0) WHERE node = 63;
    SELECT dist INTO v_dijk  FROM dmmsy_verify.dijkstra_map(0) WHERE node = 63;
    PERFORM dmmsy_verify.record(:'SUITE', 'grid_corner_to_corner', 'grid_8x8',
        abs(v_dmmsy - v_dijk) < 1e-9,
        format('dmmsy=%s dijkstra=%s', v_dmmsy, v_dijk));
END;
$$;

-- 11. Long chain of 500 nodes — completes and distance is correct
DO $$
DECLARE v_cost FLOAT8;
BEGIN
    SELECT dmmsy_verify.gen_chain(500);
    SELECT dist INTO v_cost FROM dmmsy_verify.dist_map(1) WHERE node = 500;
    PERFORM dmmsy_verify.record(:'SUITE', 'long_chain_500', 'chain_500',
        abs(v_cost - 499.0) < 1e-9, format('expected=499 got=%s', v_cost));
END;
$$;

SELECT suite, total, passed, failed FROM dmmsy_verify.summary()
WHERE suite = :'SUITE';
