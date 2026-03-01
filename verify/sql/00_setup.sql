-- =============================================================
-- pgr_dmmsy Verification Suite — Schema and Helpers
-- =============================================================
-- Run this once before any test files.
-- Prerequisites: pgr_dmmsy extension already installed.
-- =============================================================

CREATE SCHEMA IF NOT EXISTS dmmsy_verify;

-- Edge table used by all generators and test stubs
CREATE TABLE IF NOT EXISTS dmmsy_verify.edges (
    id     BIGSERIAL PRIMARY KEY,
    source BIGINT    NOT NULL,
    target BIGINT    NOT NULL,
    cost   FLOAT8    NOT NULL
);

-- Master results accumulator
CREATE TABLE IF NOT EXISTS dmmsy_verify.test_results (
    id        SERIAL      PRIMARY KEY,
    suite     TEXT        NOT NULL,
    test_name TEXT        NOT NULL,
    graph_tag TEXT,
    passed    BOOLEAN     NOT NULL,
    details   TEXT,
    run_at    TIMESTAMPTZ DEFAULT now()
);

-- ---------------------------------------------------------------
-- Helper: record a single test result
-- ---------------------------------------------------------------
CREATE OR REPLACE FUNCTION dmmsy_verify.record(
    p_suite     TEXT,
    p_name      TEXT,
    p_graph_tag TEXT,
    p_passed    BOOLEAN,
    p_details   TEXT DEFAULT NULL
) RETURNS VOID LANGUAGE plpgsql AS $$
BEGIN
    INSERT INTO dmmsy_verify.test_results
        (suite, test_name, graph_tag, passed, details)
    VALUES (p_suite, p_name, p_graph_tag, p_passed, p_details);
    IF NOT p_passed THEN
        RAISE WARNING 'FAIL [%] % on %: %',
            p_suite, p_name, p_graph_tag,
            COALESCE(p_details, '(no details)');
    END IF;
END;
$$;

-- ---------------------------------------------------------------
-- Helper: assert two float8 values are equal within epsilon
-- ---------------------------------------------------------------
CREATE OR REPLACE FUNCTION dmmsy_verify.assert_dist_eq(
    p_suite   TEXT,
    p_name    TEXT,
    p_tag     TEXT,
    p_actual  FLOAT8,
    p_expected FLOAT8,
    p_epsilon FLOAT8 DEFAULT 1e-9
) RETURNS VOID LANGUAGE plpgsql AS $$
BEGIN
    PERFORM dmmsy_verify.record(
        p_suite, p_name, p_tag,
        abs(p_actual - p_expected) <= p_epsilon,
        format('expected=%s actual=%s', p_expected, p_actual)
    );
END;
$$;

-- ---------------------------------------------------------------
-- Helper: print a summary table at the end of a run
-- ---------------------------------------------------------------
CREATE OR REPLACE FUNCTION dmmsy_verify.summary()
RETURNS TABLE(suite TEXT, total INT, passed INT, failed INT)
LANGUAGE sql AS $$
    SELECT
        suite,
        COUNT(*)::INT                          AS total,
        COUNT(*) FILTER (WHERE passed)::INT    AS passed,
        COUNT(*) FILTER (WHERE NOT passed)::INT AS failed
    FROM dmmsy_verify.test_results
    GROUP BY suite
    ORDER BY suite;
$$;

-- ---------------------------------------------------------------
-- Helper: overall pass/fail count
-- ---------------------------------------------------------------
CREATE OR REPLACE FUNCTION dmmsy_verify.overall_failures()
RETURNS INT LANGUAGE sql AS $$
    SELECT COUNT(*)::INT FROM dmmsy_verify.test_results WHERE NOT passed;
$$;

\echo '✓ 00_setup.sql loaded'
