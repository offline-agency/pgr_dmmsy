-- =============================================================
-- Suite 02: Predecessors — SPT edge/cost structural validity
-- =============================================================
-- 5 tests.  Each verifies that the returned path satisfies:
--   (a) path_seq is strictly increasing from 1
--   (b) edge column refers to a real edge in dmmsy_verify.edges
--   (c) cost column = agg_cost[v] - agg_cost[predecessor(v)]
--   (d) agg_cost is non-decreasing along the path
--   (e) source row has agg_cost = 0.0
-- =============================================================
\set SUITE '02_predecessors'

CREATE OR REPLACE FUNCTION dmmsy_verify._check_path(
    p_suite TEXT, p_name TEXT, p_tag TEXT,
    p_source BIGINT, p_target BIGINT
) RETURNS VOID LANGUAGE plpgsql AS $$
DECLARE
    v_rows     BIGINT;
    v_bad_seq  BIGINT;
    v_bad_edge BIGINT;
    v_bad_cost BIGINT;
    v_bad_mono BIGINT;
    v_src_cost FLOAT8;
    v_ok       BOOLEAN;
    v_detail   TEXT := '';
BEGIN
    -- Retrieve path into a temp table for multiple checks
    CREATE TEMP TABLE _path ON COMMIT DROP AS
    SELECT seq, path_seq, node, edge, cost, agg_cost
    FROM dmmsy_verify.run_dmmsy_full(p_source, p_target)
    ORDER BY path_seq;

    SELECT COUNT(*) INTO v_rows FROM _path;
    IF v_rows = 0 THEN
        PERFORM dmmsy_verify.record(p_suite, p_name, p_tag, false,
                                    'no rows returned');
        RETURN;
    END IF;

    -- (a) path_seq increases without gaps
    SELECT COUNT(*) INTO v_bad_seq
    FROM (
        SELECT path_seq,
               path_seq - ROW_NUMBER() OVER (ORDER BY path_seq) AS diff
        FROM _path
    ) t WHERE diff <> 0;

    -- (b) every non-final edge refers to a real edge
    SELECT COUNT(*) INTO v_bad_edge
    FROM _path p
    WHERE p.edge <> -1
      AND NOT EXISTS (SELECT 1 FROM dmmsy_verify.edges e WHERE e.id = p.edge);

    -- (c) cost matches agg_cost difference with predecessor row
    SELECT COUNT(*) INTO v_bad_cost
    FROM (
        SELECT cost,
               agg_cost - LAG(agg_cost, 1, 0.0) OVER (ORDER BY path_seq)
                   AS expected_cost
        FROM _path
    ) t
    WHERE abs(cost - expected_cost) > 1e-9;

    -- (d) agg_cost non-decreasing
    SELECT COUNT(*) INTO v_bad_mono
    FROM (
        SELECT agg_cost,
               LAG(agg_cost) OVER (ORDER BY path_seq) AS prev
        FROM _path
    ) t
    WHERE prev IS NOT NULL AND agg_cost < prev - 1e-9;

    -- (e) source has agg_cost = 0
    SELECT agg_cost INTO v_src_cost FROM _path WHERE path_seq = 1;

    v_ok := v_bad_seq = 0 AND v_bad_edge = 0
         AND v_bad_cost = 0 AND v_bad_mono = 0
         AND abs(v_src_cost) < 1e-9;

    IF NOT v_ok THEN
        v_detail := format(
            'bad_seq=%s bad_edge=%s bad_cost=%s bad_mono=%s src_cost=%s',
            v_bad_seq, v_bad_edge, v_bad_cost, v_bad_mono, v_src_cost);
    END IF;

    PERFORM dmmsy_verify.record(p_suite, p_name, p_tag, v_ok, v_detail);
END;
$$;

-- Test 1: chain path
SELECT dmmsy_verify.gen_chain(20);
SELECT dmmsy_verify._check_path(:'SUITE', 'chain_path', 'chain_20', 1, 20);

-- Test 2: grid path corner-to-corner
SELECT dmmsy_verify.gen_grid(5, 5);
SELECT dmmsy_verify._check_path(:'SUITE', 'grid_path', 'grid_5x5', 0, 24);

-- Test 3: random sparse path
SELECT dmmsy_verify.gen_random_sparse(50, 7);
SELECT dmmsy_verify._check_path(:'SUITE', 'random_path', 'random_50', 1, 50);

-- Test 4: lollipop path through the K_n portion
SELECT dmmsy_verify.gen_lollipop(4, 10);
SELECT dmmsy_verify._check_path(:'SUITE', 'lollipop_path', 'lollipop_4_10', 1, 14);

-- Test 5: shortcut path (optimal route uses shortcuts)
SELECT dmmsy_verify.gen_shortcut_path(30, 5);
SELECT dmmsy_verify._check_path(:'SUITE', 'shortcut_path', 'shortcut_30_5', 1, 30);

SELECT suite, total, passed, failed FROM dmmsy_verify.summary()
WHERE suite = :'SUITE';
