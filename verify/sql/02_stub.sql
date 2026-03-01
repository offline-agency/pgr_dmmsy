-- =============================================================
-- pgr_dmmsy Verification Suite — Function Wrappers
-- =============================================================
-- Wraps pgr_dmmsy and pgr_dijkstra over dmmsy_verify.edges
-- so tests can call them without repeating the SQL string.
-- =============================================================

-- Full path-rows wrapper (all 6 output columns)
CREATE OR REPLACE FUNCTION dmmsy_verify.run_dmmsy_full(
    p_source   BIGINT,
    p_target   BIGINT  DEFAULT NULL,
    p_directed BOOLEAN DEFAULT TRUE,
    p_k        INT     DEFAULT NULL,
    p_t        INT     DEFAULT NULL
) RETURNS TABLE(
    seq       INT,
    path_seq  INT,
    node      BIGINT,
    edge      BIGINT,
    cost      FLOAT8,
    agg_cost  FLOAT8
) LANGUAGE sql AS $$
    SELECT seq, path_seq, node, edge, cost, agg_cost
    FROM pgr_dmmsy(
        'SELECT id, source, target, cost FROM dmmsy_verify.edges',
        p_source,
        p_target,
        p_directed,
        output_predecessors := TRUE,
        param_k := COALESCE(p_k, -1),
        param_t := COALESCE(p_t, -1)
    )
    ORDER BY CASE WHEN p_target IS NULL THEN node ELSE path_seq END;
$$;

-- Distance-map: (node, agg_cost) for all reachable vertices from source
CREATE OR REPLACE FUNCTION dmmsy_verify.dist_map(
    p_source   BIGINT,
    p_directed BOOLEAN DEFAULT TRUE
) RETURNS TABLE(node BIGINT, dist FLOAT8) LANGUAGE sql AS $$
    SELECT node, agg_cost
    FROM pgr_dmmsy(
        'SELECT id, source, target, cost FROM dmmsy_verify.edges',
        p_source,
        NULL,
        p_directed
    )
    ORDER BY node;
$$;

-- Reference Dijkstra distance-map for correctness comparison
CREATE OR REPLACE FUNCTION dmmsy_verify.dijkstra_map(
    p_source   BIGINT,
    p_directed BOOLEAN DEFAULT TRUE
) RETURNS TABLE(node BIGINT, dist FLOAT8) LANGUAGE sql AS $$
    SELECT node, agg_cost
    FROM pgr_dijkstra(
        'SELECT id, source, target, cost FROM dmmsy_verify.edges',
        p_source,
        NULL,
        p_directed
    )
    ORDER BY node;
$$;

\echo '✓ 02_stub.sql loaded'
