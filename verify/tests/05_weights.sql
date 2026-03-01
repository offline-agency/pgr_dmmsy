-- =============================================================
-- Suite 05: Weights — 6 edge weight edge cases
-- =============================================================
\set SUITE '05_weights'

-- 1. All-zero weights — source reaches every vertex at cost 0
DO $$
DECLARE v_bad INT;
BEGIN
    SELECT dmmsy_verify.gen_chain(20, 0.0);
    SELECT COUNT(*) INTO v_bad
    FROM dmmsy_verify.dist_map(1)
    WHERE abs(dist) > 1e-9;
    PERFORM dmmsy_verify.record(:'SUITE', 'all_zero_weights', 'chain_zero',
        v_bad = 0, format('non_zero_distances=%s', v_bad));
END;
$$;

-- 2. Very small weights (1e-9) — no floating-point collapse
DO $$
DECLARE v_cost FLOAT8;
BEGIN
    TRUNCATE dmmsy_verify.edges RESTART IDENTITY;
    INSERT INTO dmmsy_verify.edges(source,target,cost)
    VALUES (1,2,1e-9),(2,3,1e-9),(3,4,1e-9);
    SELECT dist INTO v_cost FROM dmmsy_verify.dist_map(1) WHERE node = 4;
    PERFORM dmmsy_verify.record(:'SUITE', 'very_small_weights', 'tiny',
        abs(v_cost - 3e-9) < 1e-18, format('expected=3e-9 got=%s', v_cost));
END;
$$;

-- 3. Very large weights (1e12) — no overflow in agg_cost
DO $$
DECLARE v_cost FLOAT8;
BEGIN
    TRUNCATE dmmsy_verify.edges RESTART IDENTITY;
    INSERT INTO dmmsy_verify.edges(source,target,cost)
    VALUES (1,2,1e12),(2,3,1e12);
    SELECT dist INTO v_cost FROM dmmsy_verify.dist_map(1) WHERE node = 3;
    PERFORM dmmsy_verify.record(:'SUITE', 'very_large_weights', 'huge',
        abs(v_cost - 2e12) < 1.0, format('expected=2e12 got=%s', v_cost));
END;
$$;

-- 4. Mixed tiny and huge weights — correct ordering maintained
DO $$
DECLARE v_dmmsy FLOAT8; v_dijk FLOAT8;
BEGIN
    TRUNCATE dmmsy_verify.edges RESTART IDENTITY;
    INSERT INTO dmmsy_verify.edges(source,target,cost)
    VALUES (1,2,1e-6),(1,3,1e10),(2,3,1e-6),(3,4,1.0);
    -- Optimal 1→2→3→4 = 1e-6 + 1e-6 + 1.0 ≈ 1.000002
    SELECT dist INTO v_dmmsy FROM dmmsy_verify.dist_map(1)    WHERE node = 4;
    SELECT dist INTO v_dijk  FROM dmmsy_verify.dijkstra_map(1) WHERE node = 4;
    PERFORM dmmsy_verify.record(:'SUITE', 'mixed_extreme_weights', 'mixed',
        abs(v_dmmsy - v_dijk) < 1e-9,
        format('dmmsy=%s dijkstra=%s', v_dmmsy, v_dijk));
END;
$$;

-- 5. All equal weights (uniform=1) — distances equal hop counts
DO $$
DECLARE v_bad INT;
BEGIN
    SELECT dmmsy_verify.gen_chain(15, 1.0);
    SELECT COUNT(*) INTO v_bad
    FROM (
        SELECT node, dist
        FROM dmmsy_verify.dist_map(1)
    ) t
    WHERE abs(dist - (node - 1)) > 1e-9;
    PERFORM dmmsy_verify.record(:'SUITE', 'uniform_weights_hop_count', 'chain_uniform',
        v_bad = 0, format('bad_distances=%s', v_bad));
END;
$$;

-- 6. Bottleneck — agg_cost decomposes correctly at the narrow edge
DO $$
DECLARE v_before FLOAT8; v_after FLOAT8; v_neck FLOAT8 := 100.0;
BEGIN
    SELECT dmmsy_verify.gen_bottleneck(5, 5, v_neck);
    -- vertex at position 5 (just before neck): agg_cost = 4 * 0.01 = 0.04
    -- vertex at position 6 (just after neck):  agg_cost = 0.04 + 100 = 100.04
    SELECT dist INTO v_before FROM dmmsy_verify.dist_map(1) WHERE node = 5;
    SELECT dist INTO v_after  FROM dmmsy_verify.dist_map(1) WHERE node = 6;
    PERFORM dmmsy_verify.record(:'SUITE', 'bottleneck_decomposition', 'bottleneck',
        abs(v_before - 0.04) < 1e-9 AND abs(v_after - 100.04) < 1e-9,
        format('pre_neck=%.4f (expected=0.04) post_neck=%.4f (expected=100.04)',
               v_before, v_after));
END;
$$;

SELECT suite, total, passed, failed FROM dmmsy_verify.summary()
WHERE suite = :'SUITE';
