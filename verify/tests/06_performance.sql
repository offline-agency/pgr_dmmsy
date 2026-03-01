-- =============================================================
-- Suite 06: Performance — timing benchmarks (informational)
-- =============================================================
-- These tests ALWAYS pass (no hard assertions on absolute time).
-- They record elapsed times for dmmsy vs dijkstra and warn if
-- dmmsy is more than 3x slower than dijkstra on sparse graphs.
-- =============================================================
\set SUITE '06_performance'

CREATE OR REPLACE FUNCTION dmmsy_verify._bench(
    p_tag TEXT, p_source BIGINT, p_warn_ratio FLOAT8 DEFAULT 3.0
) RETURNS VOID LANGUAGE plpgsql AS $$
DECLARE
    t0 TIMESTAMPTZ; t1 TIMESTAMPTZ; t2 TIMESTAMPTZ;
    d_rows INT; k_rows INT;
    d_ms  FLOAT8; k_ms FLOAT8;
    ratio FLOAT8;
    ok    BOOLEAN;
    msg   TEXT;
BEGIN
    -- dmmsy timing
    t0 := clock_timestamp();
    SELECT COUNT(*) INTO d_rows FROM dmmsy_verify.dist_map(p_source);
    t1 := clock_timestamp();
    -- dijkstra timing
    SELECT COUNT(*) INTO k_rows FROM dmmsy_verify.dijkstra_map(p_source);
    t2 := clock_timestamp();

    d_ms  := EXTRACT(EPOCH FROM (t1 - t0)) * 1000.0;
    k_ms  := EXTRACT(EPOCH FROM (t2 - t1)) * 1000.0;
    ratio := CASE WHEN k_ms > 0 THEN d_ms / k_ms ELSE 1.0 END;
    ok    := d_rows = k_rows;  -- basic correctness; timing is informational

    msg := format('dmmsy=%.1fms rows=%s  dijkstra=%.1fms rows=%s  ratio=%.2f%s',
                  d_ms, d_rows, k_ms, k_rows, ratio,
                  CASE WHEN ratio > p_warn_ratio
                       THEN format(' ⚠ ratio > %.1f', p_warn_ratio) ELSE '' END);

    PERFORM dmmsy_verify.record(:'SUITE', p_tag, p_tag, ok, msg);
END;
$$;

-- 1. chain_1000
SELECT dmmsy_verify.gen_chain(1000);
SELECT dmmsy_verify._bench('chain_1000', 1);

-- 2. chain_5000
SELECT dmmsy_verify.gen_chain(5000);
SELECT dmmsy_verify._bench('chain_5000', 1);

-- 3. random_sparse(500)
SELECT dmmsy_verify.gen_random_sparse(500, 1);
SELECT dmmsy_verify._bench('random_sparse_500', 1);

-- 4. random_sparse(2000)
SELECT dmmsy_verify.gen_random_sparse(2000, 2);
SELECT dmmsy_verify._bench('random_sparse_2000', 1);

-- 5. grid(20,20) = 400 vertices, 760 edges
SELECT dmmsy_verify.gen_grid(20, 20);
SELECT dmmsy_verify._bench('grid_20x20', 0);

-- 6. complete(30) — dense K_30 = 870 edges
SELECT dmmsy_verify.gen_complete(30);
SELECT dmmsy_verify._bench('complete_k30', 1, 5.0); -- allow up to 5x on dense

-- 7. hub_and_spoke(200) — high-degree pivot vertex
SELECT dmmsy_verify.gen_hub_and_spoke(200);
SELECT dmmsy_verify._bench('hub_and_spoke_200', 0);

SELECT suite, total, passed, failed FROM dmmsy_verify.summary()
WHERE suite = :'SUITE';
