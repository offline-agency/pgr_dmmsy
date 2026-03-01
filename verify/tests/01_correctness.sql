-- =============================================================
-- Suite 01: Correctness — distances match pgr_dijkstra
-- =============================================================
-- 6 graph topologies.  For each: compare every reachable node's
-- agg_cost from pgr_dmmsy against pgr_dijkstra within ε=1e-9.
-- =============================================================
\set SUITE '01_correctness'
\set EPS 1e-9

-- Helper macro: compare dmmsy vs dijkstra on current edges
CREATE OR REPLACE FUNCTION dmmsy_verify._cmp_distances(
    p_suite TEXT, p_name TEXT, p_tag TEXT, p_source BIGINT
) RETURNS VOID LANGUAGE plpgsql AS $$
DECLARE
    v_mismatch INT;
    v_detail   TEXT;
BEGIN
    SELECT COUNT(*), string_agg(
        format('node=%s dmmsy=%.9g dijkstra=%.9g',
               d.node, d.dist, k.dist), '; ')
    INTO v_mismatch, v_detail
    FROM dmmsy_verify.dist_map(p_source) d
    JOIN dmmsy_verify.dijkstra_map(p_source) k USING (node)
    WHERE abs(d.dist - k.dist) > 1e-9;

    PERFORM dmmsy_verify.record(
        p_suite, p_name, p_tag,
        v_mismatch = 0,
        CASE WHEN v_mismatch = 0 THEN NULL
             ELSE format('%s mismatches: %s', v_mismatch, v_detail)
        END
    );
END;
$$;

-- ------ Graph 1: chain(100) ------
SELECT dmmsy_verify.gen_chain(100);
SELECT dmmsy_verify._cmp_distances(:'SUITE', 'chain_100', 'chain_100', 1);

-- ------ Graph 2: grid(10,10) ------
SELECT dmmsy_verify.gen_grid(10, 10);
SELECT dmmsy_verify._cmp_distances(:'SUITE', 'grid_10x10', 'grid_10x10', 0);

-- ------ Graph 3: random_sparse(200) ------
SELECT dmmsy_verify.gen_random_sparse(200, 42);
SELECT dmmsy_verify._cmp_distances(:'SUITE', 'random_sparse_200', 'random_sparse_200', 1);

-- ------ Graph 4: star(50) ------
SELECT dmmsy_verify.gen_star(50);
SELECT dmmsy_verify._cmp_distances(:'SUITE', 'star_50', 'star_50', 0);

-- ------ Graph 5: cycle(50) ------
SELECT dmmsy_verify.gen_cycle(50);
SELECT dmmsy_verify._cmp_distances(:'SUITE', 'cycle_50', 'cycle_50', 1);

-- ------ Graph 6: lollipop(5,20) ------
SELECT dmmsy_verify.gen_lollipop(5, 20);
SELECT dmmsy_verify._cmp_distances(:'SUITE', 'lollipop_5_20', 'lollipop_5_20', 1);

SELECT suite, total, passed, failed FROM dmmsy_verify.summary()
WHERE suite = :'SUITE';
