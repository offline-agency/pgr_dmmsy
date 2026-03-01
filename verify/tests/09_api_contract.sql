-- =============================================================
-- Suite 09: API Contract — default parameters, STRICT regression,
--           path field correctness
-- =============================================================
-- Regression tests added after fixing:
--   (a) STRICT + DEFAULT NULL returned 0 rows when optional
--       parameters (max_levels, param_k, param_t) were left
--       at their DEFAULT NULL values.
--   (b) Path fields (seq, edge, cost) were populated incorrectly
--       due to using edge_ids[current] instead of edge_ids[next].
-- =============================================================

-- ---------------------------------------------------------------
-- 1. STRICT regression: calling with only required positional
--    args leaves optional params at DEFAULT NULL.
--    Before the fix this returned 0 rows.
-- ---------------------------------------------------------------
DO $$
DECLARE
    suite  CONSTANT TEXT := '09_api_contract';
    v_rows INT;
BEGIN
    SELECT COUNT(*) INTO v_rows
    FROM pgr_dmmsy(
        $sql$SELECT 1::BIGINT AS id,
                    1::BIGINT AS source,
                    2::BIGINT AS target,
                    1.0::FLOAT8 AS cost$sql$,
        1::BIGINT,   -- source
        2::BIGINT    -- target  (all remaining params use DEFAULT NULL)
    );
    PERFORM dmmsy_verify.record(
        suite, 'strict_regression_minimal_args', '2_node',
        v_rows > 0,
        format('expected >0 rows (STRICT+DEFAULT NULL regression), got %s', v_rows));
END;
$$;

-- ---------------------------------------------------------------
-- 2. STRICT regression: explicitly passing NULL for every
--    optional parameter must behave identically to omitting them.
-- ---------------------------------------------------------------
DO $$
DECLARE
    suite  CONSTANT TEXT := '09_api_contract';
    v_rows INT;
BEGIN
    SELECT COUNT(*) INTO v_rows
    FROM pgr_dmmsy(
        $sql$SELECT 1::BIGINT AS id,
                    1::BIGINT AS source,
                    2::BIGINT AS target,
                    1.0::FLOAT8 AS cost$sql$,
        1::BIGINT,      -- source
        2::BIGINT,      -- target
        TRUE,           -- directed
        TRUE,           -- output_predecessors
        NULL::INTEGER,  -- max_levels   (explicit NULL)
        NULL::INTEGER,  -- param_k      (explicit NULL)
        NULL::INTEGER,  -- param_t      (explicit NULL)
        FALSE           -- constant_degree
    );
    PERFORM dmmsy_verify.record(
        suite, 'strict_regression_explicit_nulls', '2_node',
        v_rows > 0,
        format('expected >0 rows with explicit NULLs, got %s', v_rows));
END;
$$;

-- ---------------------------------------------------------------
-- 3. Row count: a chain of N nodes from source to target
--    must return exactly N rows (one per hop including endpoints).
-- ---------------------------------------------------------------
DO $$
DECLARE
    suite  CONSTANT TEXT := '09_api_contract';
    v_rows INT;
BEGIN
    -- chain: 1→2→3→4→5 (4 edges, 5 nodes, path = 5 rows)
    SELECT COUNT(*) INTO v_rows
    FROM pgr_dmmsy(
        $sql$SELECT id, source, target, cost
             FROM (VALUES
                 (1::BIGINT, 1::BIGINT, 2::BIGINT, 1.0::FLOAT8),
                 (2::BIGINT, 2::BIGINT, 3::BIGINT, 1.0::FLOAT8),
                 (3::BIGINT, 3::BIGINT, 4::BIGINT, 1.0::FLOAT8),
                 (4::BIGINT, 4::BIGINT, 5::BIGINT, 1.0::FLOAT8)
             ) AS t(id, source, target, cost)$sql$,
        1::BIGINT, 5::BIGINT
    );
    PERFORM dmmsy_verify.record(
        suite, 'row_count_5_node_chain', '5_node_chain',
        v_rows = 5,
        format('expected 5 rows, got %s', v_rows));
END;
$$;

-- ---------------------------------------------------------------
-- 4. Path field: seq values must be 1..N in ascending order.
--    Before the fix seq was populated as (N - pos) instead of
--    (pos + 1), giving reversed sequence numbers.
-- ---------------------------------------------------------------
DO $$
DECLARE
    suite  CONSTANT TEXT := '09_api_contract';
    v_bad INT;
BEGIN
    SELECT COUNT(*) INTO v_bad
    FROM (
        SELECT seq, ROW_NUMBER() OVER (ORDER BY path_seq) AS expected_seq
        FROM pgr_dmmsy(
            $sql$SELECT id, source, target, cost
                 FROM (VALUES
                     (1::BIGINT, 1::BIGINT, 2::BIGINT, 2.0::FLOAT8),
                     (2::BIGINT, 2::BIGINT, 3::BIGINT, 3.0::FLOAT8)
                 ) AS t(id, source, target, cost)$sql$,
            1::BIGINT, 3::BIGINT
        )
    ) sub
    WHERE seq <> expected_seq::INT;

    PERFORM dmmsy_verify.record(
        suite, 'seq_monotonic_1_to_N', '3_node_chain',
        v_bad = 0,
        format('%s row(s) had wrong seq value', v_bad));
END;
$$;

-- ---------------------------------------------------------------
-- 5. Path field: source row must have agg_cost = 0.
-- ---------------------------------------------------------------
DO $$
DECLARE
    suite  CONSTANT TEXT := '09_api_contract';
    v_agg FLOAT8;
BEGIN
    SELECT agg_cost INTO v_agg
    FROM pgr_dmmsy(
        $sql$SELECT 1::BIGINT AS id,
                    1::BIGINT AS source,
                    2::BIGINT AS target,
                    5.0::FLOAT8 AS cost$sql$,
        1::BIGINT, 2::BIGINT
    )
    ORDER BY path_seq
    LIMIT 1;

    PERFORM dmmsy_verify.record(
        suite, 'source_agg_cost_zero', '2_node',
        abs(v_agg) < 1e-9,
        format('source agg_cost expected 0, got %s', v_agg));
END;
$$;

-- ---------------------------------------------------------------
-- 6. Path field: source row edge must be the actual edge id
--    (not -1).  Before the fix edge_ids[source_idx] = -1 was
--    used instead of edge_ids[successor].
-- ---------------------------------------------------------------
DO $$
DECLARE
    suite  CONSTANT TEXT := '09_api_contract';
    v_edge BIGINT;
BEGIN
    SELECT edge INTO v_edge
    FROM pgr_dmmsy(
        $sql$SELECT 1::BIGINT AS id,
                    1::BIGINT AS source,
                    2::BIGINT AS target,
                    1.0::FLOAT8 AS cost$sql$,
        1::BIGINT, 2::BIGINT
    )
    ORDER BY path_seq
    LIMIT 1;

    PERFORM dmmsy_verify.record(
        suite, 'source_edge_not_minus1', '2_node',
        v_edge <> -1,
        format('source edge expected != -1, got %s', v_edge));
END;
$$;

-- ---------------------------------------------------------------
-- 7. Path field: source row cost must equal the first edge weight.
--    Before the fix cost was always 0 for the source row.
-- ---------------------------------------------------------------
DO $$
DECLARE
    suite  CONSTANT TEXT := '09_api_contract';
    v_cost FLOAT8;
BEGIN
    SELECT cost INTO v_cost
    FROM pgr_dmmsy(
        $sql$SELECT 1::BIGINT AS id,
                    1::BIGINT AS source,
                    2::BIGINT AS target,
                    7.5::FLOAT8 AS cost$sql$,
        1::BIGINT, 2::BIGINT
    )
    ORDER BY path_seq
    LIMIT 1;

    PERFORM dmmsy_verify.record(
        suite, 'source_cost_equals_edge_weight', '2_node',
        abs(v_cost - 7.5) < 1e-9,
        format('source cost expected 7.5, got %s', v_cost));
END;
$$;

-- ---------------------------------------------------------------
-- 8. Path field: target (last) row must have edge = -1.
-- ---------------------------------------------------------------
DO $$
DECLARE
    suite  CONSTANT TEXT := '09_api_contract';
    v_edge BIGINT;
BEGIN
    SELECT edge INTO v_edge
    FROM pgr_dmmsy(
        $sql$SELECT 1::BIGINT AS id,
                    1::BIGINT AS source,
                    2::BIGINT AS target,
                    1.0::FLOAT8 AS cost$sql$,
        1::BIGINT, 2::BIGINT
    )
    ORDER BY path_seq DESC
    LIMIT 1;

    PERFORM dmmsy_verify.record(
        suite, 'target_edge_is_minus1', '2_node',
        v_edge = -1,
        format('target edge expected -1, got %s', v_edge));
END;
$$;

-- ---------------------------------------------------------------
-- 9. Path field: target (last) row must have cost = 0.
-- ---------------------------------------------------------------
DO $$
DECLARE
    suite  CONSTANT TEXT := '09_api_contract';
    v_cost FLOAT8;
BEGIN
    SELECT cost INTO v_cost
    FROM pgr_dmmsy(
        $sql$SELECT 1::BIGINT AS id,
                    1::BIGINT AS source,
                    2::BIGINT AS target,
                    1.0::FLOAT8 AS cost$sql$,
        1::BIGINT, 2::BIGINT
    )
    ORDER BY path_seq DESC
    LIMIT 1;

    PERFORM dmmsy_verify.record(
        suite, 'target_cost_is_zero', '2_node',
        abs(v_cost) < 1e-9,
        format('target cost expected 0, got %s', v_cost));
END;
$$;

-- ---------------------------------------------------------------
-- 10. Path field: agg_cost of the target row must equal the sum
--     of all individual edge costs along the path.
-- ---------------------------------------------------------------
DO $$
DECLARE
    suite         CONSTANT TEXT := '09_api_contract';
    v_agg_target  FLOAT8;
    v_sum_costs   FLOAT8;
BEGIN
    WITH path AS (
        SELECT cost, agg_cost, path_seq,
               MAX(path_seq) OVER () AS max_ps
        FROM pgr_dmmsy(
            $sql$SELECT id, source, target, cost
                 FROM (VALUES
                     (1::BIGINT, 1::BIGINT, 2::BIGINT, 2.0::FLOAT8),
                     (2::BIGINT, 2::BIGINT, 3::BIGINT, 3.0::FLOAT8),
                     (3::BIGINT, 3::BIGINT, 4::BIGINT, 4.0::FLOAT8)
                 ) AS t(id, source, target, cost)$sql$,
            1::BIGINT, 4::BIGINT
        )
    )
    SELECT
        MAX(agg_cost) FILTER (WHERE path_seq = max_ps),
        SUM(cost)     FILTER (WHERE path_seq < max_ps)
    INTO v_agg_target, v_sum_costs
    FROM path;

    PERFORM dmmsy_verify.record(
        suite, 'agg_cost_equals_sum_of_edge_costs', '4_node_chain',
        abs(v_agg_target - v_sum_costs) < 1e-9,
        format('agg_cost=%s sum_costs=%s', v_agg_target, v_sum_costs));
END;
$$;

-- ---------------------------------------------------------------
-- 11. Source = target: must return exactly 1 row with
--     node=source, agg_cost=0, edge=-1, cost=0.
-- ---------------------------------------------------------------
DO $$
DECLARE
    suite   CONSTANT TEXT := '09_api_contract';
    v_rows  INT;
    v_node  BIGINT;
    v_agg   FLOAT8;
    v_edge  BIGINT;
BEGIN
    SELECT COUNT(*), MIN(node), MIN(agg_cost), MIN(edge)
    INTO v_rows, v_node, v_agg, v_edge
    FROM pgr_dmmsy(
        $sql$SELECT 1::BIGINT AS id,
                    1::BIGINT AS source,
                    2::BIGINT AS target,
                    1.0::FLOAT8 AS cost$sql$,
        1::BIGINT, 1::BIGINT  -- source = target
    );

    PERFORM dmmsy_verify.record(
        suite, 'source_equals_target_one_row', '2_node',
        v_rows = 1 AND v_node = 1 AND abs(v_agg) < 1e-9 AND v_edge = -1,
        format('rows=%s node=%s agg_cost=%s edge=%s',
               v_rows, v_node, v_agg, v_edge));
END;
$$;

-- ---------------------------------------------------------------
-- 12. Named-parameter form must produce identical results to
--     positional form.
-- ---------------------------------------------------------------
DO $$
DECLARE
    suite  CONSTANT TEXT := '09_api_contract';
    v_bad  INT;
BEGIN
    PERFORM dmmsy_verify.gen_chain(8);
    WITH
      positional AS (
          SELECT node, agg_cost
          FROM pgr_dmmsy(
              'SELECT id,source,target,cost FROM dmmsy_verify.edges',
              1::BIGINT, 8::BIGINT)
      ),
      named AS (
          SELECT node, agg_cost
          FROM pgr_dmmsy(
              'SELECT id,source,target,cost FROM dmmsy_verify.edges',
              source     := 1::BIGINT,
              target     := 8::BIGINT,
              directed   := TRUE,
              param_k    := NULL,
              param_t    := NULL)
      )
    SELECT COUNT(*) INTO v_bad
    FROM positional p
    FULL OUTER JOIN named n USING (node)
    WHERE abs(COALESCE(p.agg_cost, 0) - COALESCE(n.agg_cost, 0)) > 1e-9
       OR p.node IS NULL OR n.node IS NULL;

    PERFORM dmmsy_verify.record(
        suite, 'named_params_same_result', 'chain_8',
        v_bad = 0,
        format('%s mismatch(es) between positional and named-param calls', v_bad));
END;
$$;

-- ---------------------------------------------------------------
-- 13. Default directed=TRUE: a reverse path must not be found.
-- ---------------------------------------------------------------
DO $$
DECLARE
    suite  CONSTANT TEXT := '09_api_contract';
    v_rows INT;
BEGIN
    -- edge only goes 1→2; with directed=TRUE, 2→1 must return 0 rows
    SELECT COUNT(*) INTO v_rows
    FROM pgr_dmmsy(
        $sql$SELECT 1::BIGINT AS id,
                    1::BIGINT AS source,
                    2::BIGINT AS target,
                    1.0::FLOAT8 AS cost$sql$,
        2::BIGINT, 1::BIGINT  -- reverse direction — no path exists
    );

    PERFORM dmmsy_verify.record(
        suite, 'directed_default_no_reverse_path', '2_node',
        v_rows = 0,
        format('expected 0 rows for reverse path in directed graph, got %s', v_rows));
END;
$$;

SELECT suite, total, passed, failed FROM dmmsy_verify.summary()
WHERE suite = '09_api_contract';
