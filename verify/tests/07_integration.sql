-- =============================================================
-- Suite 07: Integration — types, NULLs, transactions, params
-- =============================================================
\set SUITE '07_integration'

-- 1. NULL target (all-pairs from source) — returns all reachable vertices
DO $$
DECLARE v_count INT; v_expected INT;
BEGIN
    SELECT dmmsy_verify.gen_chain(10);
    SELECT COUNT(*) INTO v_count   FROM dmmsy_verify.run_dmmsy_full(1, NULL);
    SELECT COUNT(*) INTO v_expected FROM dmmsy_verify.dijkstra_map(1);
    PERFORM dmmsy_verify.record(:'SUITE', 'null_target_all_paths', 'chain_10',
        v_count = v_expected,
        format('dmmsy=%s dijkstra=%s', v_count, v_expected));
END;
$$;

-- 2. Directed=FALSE (undirected) — reverse path exists
DO $$
DECLARE v_fwd FLOAT8; v_rev FLOAT8;
BEGIN
    SELECT dmmsy_verify.gen_chain(5, 2.0);
    -- With undirected, 5→1 should cost same as 1→5
    SELECT dist INTO v_fwd
    FROM pgr_dmmsy(
        'SELECT id,source,target,cost FROM dmmsy_verify.edges', 1, NULL, FALSE)
    WHERE node = 5;
    SELECT dist INTO v_rev
    FROM pgr_dmmsy(
        'SELECT id,source,target,cost FROM dmmsy_verify.edges', 5, NULL, FALSE)
    WHERE node = 1;
    PERFORM dmmsy_verify.record(:'SUITE', 'undirected_symmetric', 'chain_5_undirected',
        abs(v_fwd - v_rev) < 1e-9,
        format('fwd=%s rev=%s', v_fwd, v_rev));
END;
$$;

-- 3. max_levels=1 — only source vertex settled, target unreachable on chain
DO $$
DECLARE v_rows INT;
BEGIN
    SELECT dmmsy_verify.gen_chain(5);
    SELECT COUNT(*) INTO v_rows
    FROM pgr_dmmsy(
        'SELECT id,source,target,cost FROM dmmsy_verify.edges',
        1, 5, TRUE, max_levels := 1);
    PERFORM dmmsy_verify.record(:'SUITE', 'max_levels_1_restricts', 'chain_5',
        v_rows = 0,
        format('rows_returned=%s (expected 0)', v_rows));
END;
$$;

-- 4. Custom param_k and param_t — distances unchanged vs defaults
DO $$
DECLARE v_bad INT;
BEGIN
    SELECT dmmsy_verify.gen_random_sparse(30, 5);
    WITH
      default_run AS (
          SELECT node, agg_cost FROM pgr_dmmsy(
              'SELECT id,source,target,cost FROM dmmsy_verify.edges', 1, NULL)
      ),
      custom_run AS (
          SELECT node, agg_cost FROM pgr_dmmsy(
              'SELECT id,source,target,cost FROM dmmsy_verify.edges',
              1, NULL, TRUE, param_k := 5, param_t := 3)
      )
    SELECT COUNT(*) INTO v_bad
    FROM default_run d JOIN custom_run c USING (node)
    WHERE abs(d.agg_cost - c.agg_cost) > 1e-9;
    PERFORM dmmsy_verify.record(:'SUITE', 'custom_k_t_same_distances', 'random_30',
        v_bad = 0, format('mismatches=%s', v_bad));
END;
$$;

-- 5. Transaction rollback — no side effects on test_results table
DO $$
DECLARE v_before INT; v_after INT;
BEGIN
    SELECT COUNT(*) INTO v_before FROM dmmsy_verify.test_results;
    BEGIN
        SELECT dmmsy_verify.gen_chain(5);
        -- intentionally do a search inside a savepoint
        PERFORM * FROM dmmsy_verify.dist_map(1);
        RAISE EXCEPTION 'deliberate rollback';
    EXCEPTION WHEN OTHERS THEN
        NULL;  -- swallow
    END;
    SELECT COUNT(*) INTO v_after FROM dmmsy_verify.test_results;
    PERFORM dmmsy_verify.record(:'SUITE', 'transaction_rollback_no_leak', 'txn',
        v_after = v_before + 1,  -- only this record itself is added
        format('before=%s after=%s', v_before, v_after));
END;
$$;

-- 6. Sequential queries — no state leak between calls
DO $$
DECLARE v1 FLOAT8; v2 FLOAT8;
BEGIN
    SELECT dmmsy_verify.gen_chain(10);
    SELECT dist INTO v1 FROM dmmsy_verify.dist_map(1)  WHERE node = 10;
    SELECT dist INTO v2 FROM dmmsy_verify.dist_map(10) WHERE node = 10;
    -- second call from source=10: dist to itself should be 0
    PERFORM dmmsy_verify.record(:'SUITE', 'sequential_no_state_leak', 'chain_10',
        abs(v1 - 9.0) < 1e-9 AND abs(v2) < 1e-9,
        format('d(1→10)=%s d(10→10)=%s', v1, v2));
END;
$$;

-- 7. Very large param_k and param_t — no crash, correct result
DO $$
DECLARE v_bad INT;
BEGIN
    SELECT dmmsy_verify.gen_chain(10);
    WITH
      large_run AS (
          SELECT node, agg_cost FROM pgr_dmmsy(
              'SELECT id,source,target,cost FROM dmmsy_verify.edges',
              1, NULL, TRUE, param_k := 100, param_t := 50)
      ),
      ref_run AS (
          SELECT node, agg_cost FROM pgr_dijkstra(
              'SELECT id,source,target,cost FROM dmmsy_verify.edges', 1, NULL)
      )
    SELECT COUNT(*) INTO v_bad
    FROM large_run lr JOIN ref_run rr USING (node)
    WHERE abs(lr.agg_cost - rr.agg_cost) > 1e-9;
    PERFORM dmmsy_verify.record(:'SUITE', 'large_params_no_crash', 'chain_10_large_k_t',
        v_bad = 0, format('mismatches=%s', v_bad));
END;
$$;

SELECT suite, total, passed, failed FROM dmmsy_verify.summary()
WHERE suite = :'SUITE';
