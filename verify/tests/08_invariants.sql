-- =============================================================
-- Suite 08: Invariants — DMMSY algorithm-specific properties
-- =============================================================
-- These tests verify properties that only a correct DMMSY
-- implementation can satisfy (vs. pure Dijkstra).
-- Failures here are WARNINGS only (non-mandatory suite).
-- =============================================================
\set SUITE '08_invariants'

-- 1. Distance monotonicity along any returned path
--    agg_cost must be non-decreasing at every step
DO $$
DECLARE v_bad INT;
BEGIN
    SELECT dmmsy_verify.gen_random_sparse(50, 9);
    WITH path AS (
        SELECT path_seq, agg_cost,
               LAG(agg_cost) OVER (ORDER BY path_seq) AS prev_agg
        FROM dmmsy_verify.run_dmmsy_full(1, 50)
    )
    SELECT COUNT(*) INTO v_bad
    FROM path
    WHERE prev_agg IS NOT NULL AND agg_cost < prev_agg - 1e-9;
    PERFORM dmmsy_verify.record(:'SUITE', 'path_monotone_agg_cost', 'random_50',
        v_bad = 0, format('violations=%s', v_bad));
END;
$$;

-- 2. Correctness under k=1, t=1 (minimum parameters)
--    Even with minimal BF rounds and widest blocks, distances must
--    match pgr_dijkstra (the heap handles cross-phase accuracy)
DO $$
DECLARE v_bad INT;
BEGIN
    SELECT dmmsy_verify.gen_chain(30);
    WITH
      dmmsy AS (
          SELECT node, agg_cost FROM pgr_dmmsy(
              'SELECT id,source,target,cost FROM dmmsy_verify.edges',
              1, NULL, TRUE, param_k := 1, param_t := 1)
      ),
      dijk AS (
          SELECT node, agg_cost FROM pgr_dijkstra(
              'SELECT id,source,target,cost FROM dmmsy_verify.edges', 1, NULL)
      )
    SELECT COUNT(*) INTO v_bad
    FROM dmmsy d JOIN dijk k USING (node)
    WHERE abs(d.agg_cost - k.agg_cost) > 1e-9;
    PERFORM dmmsy_verify.record(:'SUITE', 'k1_t1_matches_dijkstra', 'chain_30_k1t1',
        v_bad = 0, format('mismatches=%s', v_bad));
END;
$$;

-- 3. Correctness under k=2, t=2 (paper default for small n)
DO $$
DECLARE v_bad INT;
BEGIN
    SELECT dmmsy_verify.gen_random_sparse(100, 11);
    WITH
      dmmsy AS (
          SELECT node, agg_cost FROM pgr_dmmsy(
              'SELECT id,source,target,cost FROM dmmsy_verify.edges',
              1, NULL, TRUE, param_k := 2, param_t := 2)
      ),
      dijk AS (
          SELECT node, agg_cost FROM pgr_dijkstra(
              'SELECT id,source,target,cost FROM dmmsy_verify.edges', 1, NULL)
      )
    SELECT COUNT(*) INTO v_bad
    FROM dmmsy d JOIN dijk k USING (node)
    WHERE abs(d.agg_cost - k.agg_cost) > 1e-9;
    PERFORM dmmsy_verify.record(:'SUITE', 'k2_t2_matches_dijkstra', 'random_100_k2t2',
        v_bad = 0, format('mismatches=%s', v_bad));
END;
$$;

-- 4. Source-to-source distance is always 0
DO $$
DECLARE v_cost FLOAT8;
BEGIN
    SELECT dmmsy_verify.gen_cycle(10);
    SELECT dist INTO v_cost FROM dmmsy_verify.dist_map(1) WHERE node = 1;
    PERFORM dmmsy_verify.record(:'SUITE', 'source_to_source_zero', 'cycle_10',
        abs(v_cost) < 1e-9, format('d(1→1)=%s', v_cost));
END;
$$;

-- 5. All reachable vertices from a chain are reached
DO $$
DECLARE v_dmmsy INT; v_dijk INT;
BEGIN
    SELECT dmmsy_verify.gen_chain(100);
    SELECT COUNT(*) INTO v_dmmsy FROM dmmsy_verify.dist_map(1);
    SELECT COUNT(*) INTO v_dijk  FROM dmmsy_verify.dijkstra_map(1);
    PERFORM dmmsy_verify.record(:'SUITE', 'all_reachable_vertices_found', 'chain_100',
        v_dmmsy = v_dijk,
        format('dmmsy_rows=%s dijkstra_rows=%s', v_dmmsy, v_dijk));
END;
$$;

-- 6. Hub vertex (high out-degree) settled with correct distance
--    On hub_and_spoke, all spoke vertices have dist=1 from hub (vertex 0)
DO $$
DECLARE v_bad INT;
BEGIN
    SELECT dmmsy_verify.gen_hub_and_spoke(25);
    -- Spokes 1..25 are all at distance 1 from hub 0
    SELECT COUNT(*) INTO v_bad
    FROM dmmsy_verify.dist_map(0)
    WHERE node BETWEEN 1 AND 25
      AND abs(dist - 1.0) > 1e-9;
    PERFORM dmmsy_verify.record(:'SUITE', 'hub_spoke_distances_correct', 'hub_25',
        v_bad = 0, format('wrong_spoke_distances=%s', v_bad));
END;
$$;

SELECT suite, total, passed, failed FROM dmmsy_verify.summary()
WHERE suite = :'SUITE';
