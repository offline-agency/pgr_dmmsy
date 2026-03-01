-- =============================================================
-- Suite 03: Negative Weights — rejection behavior
-- =============================================================
-- 3 tests verifying that pgr_dmmsy correctly rejects graphs
-- with negative-cost edges (as required by the algorithm).
-- Zero-cost edges must be accepted.
-- =============================================================
\set SUITE '03_negative'

-- Test 1: single negative edge must raise an ERROR
DO $$
BEGIN
    BEGIN
        PERFORM node FROM pgr_dmmsy(
            $sql$SELECT 1::BIGINT AS id,
                        1::BIGINT AS source,
                        2::BIGINT AS target,
                        -1.0::FLOAT8 AS cost$sql$,
            1, 2);
        -- If we reach here, no error was raised — that is a failure
        PERFORM dmmsy_verify.record(
            '03_negative', 'single_negative_edge', 'inline',
            FALSE, 'expected ERROR but none was raised');
    EXCEPTION WHEN OTHERS THEN
        PERFORM dmmsy_verify.record(
            '03_negative', 'single_negative_edge', 'inline',
            TRUE, format('correctly raised: %s', SQLERRM));
    END;
END;
$$;

-- Test 2: graph with mixed positive and negative edges must raise an ERROR
DO $$
BEGIN
    BEGIN
        PERFORM node FROM pgr_dmmsy(
            $sql$SELECT id, source, target, cost
                 FROM (VALUES
                     (1::BIGINT, 1::BIGINT, 2::BIGINT, 3.0::FLOAT8),
                     (2::BIGINT, 2::BIGINT, 3::BIGINT, -0.5::FLOAT8),
                     (3::BIGINT, 1::BIGINT, 3::BIGINT, 5.0::FLOAT8)
                 ) AS t(id, source, target, cost)$sql$,
            1, 3);
        PERFORM dmmsy_verify.record(
            '03_negative', 'mixed_negative_edge', 'inline',
            FALSE, 'expected ERROR but none was raised');
    EXCEPTION WHEN OTHERS THEN
        PERFORM dmmsy_verify.record(
            '03_negative', 'mixed_negative_edge', 'inline',
            TRUE, format('correctly raised: %s', SQLERRM));
    END;
END;
$$;

-- Test 3: zero-cost edges must be ACCEPTED (not treated as negative)
DO $$
DECLARE
    v_count INT;
BEGIN
    SELECT COUNT(*) INTO v_count
    FROM pgr_dmmsy(
        $sql$SELECT id, source, target, cost
             FROM (VALUES
                 (1::BIGINT, 1::BIGINT, 2::BIGINT, 0.0::FLOAT8),
                 (2::BIGINT, 2::BIGINT, 3::BIGINT, 0.0::FLOAT8),
                 (3::BIGINT, 3::BIGINT, 4::BIGINT, 1.0::FLOAT8)
             ) AS t(id, source, target, cost)$sql$,
        1, 4);
    PERFORM dmmsy_verify.record(
        '03_negative', 'zero_cost_accepted', 'inline',
        v_count > 0,
        format('expected rows, got %s', v_count));
EXCEPTION WHEN OTHERS THEN
    PERFORM dmmsy_verify.record(
        '03_negative', 'zero_cost_accepted', 'inline',
        FALSE, format('unexpected error: %s', SQLERRM));
END;
$$;

SELECT suite, total, passed, failed FROM dmmsy_verify.summary()
WHERE suite = :'SUITE';
