-- pgr_dmmsy extension SQL definitions
-- Implements the DMMSY deterministic SSSP algorithm
-- Based on: "Breaking the Sorting Barrier for Directed Single-Source Shortest Paths"
-- by Duan, Mao, Mao, Shu, and Yin (2025)
-- Paper: https://arxiv.org/abs/2504.17033

CREATE OR REPLACE FUNCTION pgr_dmmsy(
    edges_sql TEXT,
    source BIGINT,
    target BIGINT DEFAULT NULL,
    directed BOOLEAN DEFAULT TRUE,
    output_predecessors BOOLEAN DEFAULT TRUE,
    max_levels INTEGER DEFAULT NULL,
    param_k INTEGER DEFAULT NULL,
    param_t INTEGER DEFAULT NULL,
    constant_degree BOOLEAN DEFAULT FALSE
)
RETURNS TABLE (
    seq INT,
    path_seq INT,
    node BIGINT,
    edge BIGINT,
    cost FLOAT8,
    agg_cost FLOAT8
)
AS 'MODULE_PATHNAME', 'pgr_dmmsy_c'
LANGUAGE C VOLATILE STRICT PARALLEL SAFE;

COMMENT ON FUNCTION pgr_dmmsy(TEXT, BIGINT, BIGINT, BOOLEAN, BOOLEAN, INTEGER, INTEGER, INTEGER, BOOLEAN) IS 
'pgr_dmmsy - Deterministic directed single-source shortest path algorithm
Paper: https://arxiv.org/abs/2504.17033

Parameters:
  edges_sql          - SQL query returning edges with columns: id, source, target, cost
  source             - Source vertex id
  target             - Target vertex id (optional, NULL for all shortest paths from source)
  directed           - TRUE for directed graph, FALSE for undirected (default TRUE)
  output_predecessors - TRUE to include predecessor information (default TRUE)
  max_levels         - Maximum number of levels to explore (optional)
  param_k            - Algorithm parameter k (optional, auto-computed if NULL)
  param_t            - Algorithm parameter t (optional, auto-computed if NULL)
  constant_degree    - Assume constant degree graph (default FALSE)

Returns:
  seq       - Sequential result number
  path_seq  - Position in path (1 = start, n = end)
  node      - Vertex id
  edge      - Edge id (-1 for final node)
  cost      - Edge cost
  agg_cost  - Aggregate cost from source to this node

Example:
  SELECT * FROM pgr_dmmsy(
    ''SELECT id, source, target, cost FROM edges'',
    1,  -- source
    10  -- target
  );
';
