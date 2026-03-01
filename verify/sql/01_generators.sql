-- =============================================================
-- pgr_dmmsy Verification Suite — 14 Synthetic Graph Generators
-- =============================================================
-- Each function TRUNCATES dmmsy_verify.edges then re-populates it.
-- All generators produce directed graphs with non-negative weights.
-- =============================================================

-- 1. Linear chain: 1 → 2 → … → n, each edge weight w
CREATE OR REPLACE FUNCTION dmmsy_verify.gen_chain(n INT, w FLOAT8 DEFAULT 1.0)
RETURNS VOID LANGUAGE sql AS $$
    TRUNCATE dmmsy_verify.edges RESTART IDENTITY;
    INSERT INTO dmmsy_verify.edges(source, target, cost)
    SELECT i, i + 1, w
    FROM generate_series(1, n - 1) i;
$$;

-- 2. Complete binary tree (directed parent → children), depth levels
--    Vertices: 1 … 2^depth - 1
CREATE OR REPLACE FUNCTION dmmsy_verify.gen_binary_tree(depth INT)
RETURNS VOID LANGUAGE sql AS $$
    TRUNCATE dmmsy_verify.edges RESTART IDENTITY;
    INSERT INTO dmmsy_verify.edges(source, target, cost)
    SELECT i, 2 * i,     1.0 FROM generate_series(1, (2^depth)::INT - 1) i
    UNION ALL
    SELECT i, 2 * i + 1, 1.0 FROM generate_series(1, (2^depth)::INT - 1) i;
$$;

-- 3. rows × cols grid (directed right and down)
--    Vertex ID = row * cols + col  (0-based)
CREATE OR REPLACE FUNCTION dmmsy_verify.gen_grid(rows INT, cols INT)
RETURNS VOID LANGUAGE sql AS $$
    TRUNCATE dmmsy_verify.edges RESTART IDENTITY;
    WITH g AS (
        SELECT (i / cols) AS r, (i % cols) AS c, i AS v
        FROM generate_series(0, rows * cols - 1) i
    )
    INSERT INTO dmmsy_verify.edges(source, target, cost)
    SELECT g1.v, g2.v, 1.0
    FROM g g1
    JOIN g g2
      ON (g1.r = g2.r AND g2.c = g1.c + 1)
      OR (g1.c = g2.c AND g2.r = g1.r + 1);
$$;

-- 4. Complete directed graph K_n (all ordered pairs i≠j)
--    Edge weight = i + j
CREATE OR REPLACE FUNCTION dmmsy_verify.gen_complete(n INT)
RETURNS VOID LANGUAGE sql AS $$
    TRUNCATE dmmsy_verify.edges RESTART IDENTITY;
    INSERT INTO dmmsy_verify.edges(source, target, cost)
    SELECT i, j, (i + j)::FLOAT8
    FROM generate_series(1, n) i
    CROSS JOIN generate_series(1, n) j
    WHERE i <> j;
$$;

-- 5. Star: hub vertex 0, n inbound spokes and n outbound spokes
CREATE OR REPLACE FUNCTION dmmsy_verify.gen_star(n INT)
RETURNS VOID LANGUAGE sql AS $$
    TRUNCATE dmmsy_verify.edges RESTART IDENTITY;
    INSERT INTO dmmsy_verify.edges(source, target, cost)
    SELECT i, 0, 1.0 FROM generate_series(1, n) i   -- inbound
    UNION ALL
    SELECT 0, n + i, 1.0 FROM generate_series(1, n) i; -- outbound
$$;

-- 6. Random sparse: n vertices, ~2n edges, backbone chain + random extras
--    Uses seed for reproducibility; weights uniformly in [1, 10)
CREATE OR REPLACE FUNCTION dmmsy_verify.gen_random_sparse(
    n INT, seed INT DEFAULT 42
) RETURNS VOID LANGUAGE plpgsql AS $$
BEGIN
    PERFORM setseed(seed / 10000.0);
    TRUNCATE dmmsy_verify.edges RESTART IDENTITY;
    -- Backbone chain guarantees strong connectivity
    INSERT INTO dmmsy_verify.edges(source, target, cost)
    SELECT i, i + 1, round((random() * 9 + 1)::numeric, 3)
    FROM generate_series(1, n - 1) i;
    -- Random extra edges
    INSERT INTO dmmsy_verify.edges(source, target, cost)
    SELECT
        1 + (random() * (n - 1))::INT,
        1 + (random() * (n - 1))::INT,
        round((random() * 9 + 1)::numeric, 3)
    FROM generate_series(1, n) i;
END;
$$;

-- 7. DAG (layered): layers × width vertices, all edges go forward one layer
CREATE OR REPLACE FUNCTION dmmsy_verify.gen_dag(layers INT, width INT)
RETURNS VOID LANGUAGE sql AS $$
    TRUNCATE dmmsy_verify.edges RESTART IDENTITY;
    INSERT INTO dmmsy_verify.edges(source, target, cost)
    SELECT l * width + c,
           (l + 1) * width + d,
           1.0
    FROM generate_series(0, layers - 1) l
    CROSS JOIN generate_series(0, width - 1) c
    CROSS JOIN generate_series(0, width - 1) d;
$$;

-- 8. Directed cycle: 1 → 2 → … → n → 1
CREATE OR REPLACE FUNCTION dmmsy_verify.gen_cycle(n INT)
RETURNS VOID LANGUAGE sql AS $$
    TRUNCATE dmmsy_verify.edges RESTART IDENTITY;
    INSERT INTO dmmsy_verify.edges(source, target, cost)
    SELECT i,
           CASE WHEN i < n THEN i + 1 ELSE 1 END,
           1.0
    FROM generate_series(1, n) i;
$$;

-- 9. Lollipop: complete K_n attached to a directed chain of length m
--    Vertices 1..n form K_n; chain n → n+1 → … → n+m
CREATE OR REPLACE FUNCTION dmmsy_verify.gen_lollipop(n INT, m INT)
RETURNS VOID LANGUAGE sql AS $$
    TRUNCATE dmmsy_verify.edges RESTART IDENTITY;
    -- K_n directed part
    INSERT INTO dmmsy_verify.edges(source, target, cost)
    SELECT i, j, 1.0
    FROM generate_series(1, n) i
    CROSS JOIN generate_series(1, n) j
    WHERE i <> j;
    -- Chain tail
    INSERT INTO dmmsy_verify.edges(source, target, cost)
    SELECT n + i - 1, n + i, 1.0
    FROM generate_series(1, m) i;
$$;

-- 10. Two-level hierarchy: hubs connected in a chain, each hub → cluster
CREATE OR REPLACE FUNCTION dmmsy_verify.gen_hierarchy(
    hubs INT, cluster_size INT
) RETURNS VOID LANGUAGE sql AS $$
    TRUNCATE dmmsy_verify.edges RESTART IDENTITY;
    -- Hub backbone
    INSERT INTO dmmsy_verify.edges(source, target, cost)
    SELECT i, i + 1, 1.0
    FROM generate_series(1, hubs - 1) i;
    -- Each hub to its cluster members
    INSERT INTO dmmsy_verify.edges(source, target, cost)
    SELECT h,
           hubs + (h - 1) * cluster_size + c,
           2.0
    FROM generate_series(1, hubs) h
    CROSS JOIN generate_series(1, cluster_size) c;
$$;

-- 11. Hub-and-spoke: hub 0 with high out-degree, good pivot test
--     0 → 1..spokes (outgoing), 1..spokes → 0 (incoming),
--     1..spokes → spokes+1..2*spokes (tail)
CREATE OR REPLACE FUNCTION dmmsy_verify.gen_hub_and_spoke(spokes INT)
RETURNS VOID LANGUAGE sql AS $$
    TRUNCATE dmmsy_verify.edges RESTART IDENTITY;
    INSERT INTO dmmsy_verify.edges(source, target, cost)
    SELECT 0, i, 1.0 FROM generate_series(1, spokes) i       -- hub outbound
    UNION ALL
    SELECT i, 0, 1.0 FROM generate_series(1, spokes) i       -- hub inbound
    UNION ALL
    SELECT i, i + spokes, 1.0 FROM generate_series(1, spokes) i; -- spoke tails
$$;

-- 12. Bottleneck: cheap lead-in chain → single expensive edge → cheap tail
CREATE OR REPLACE FUNCTION dmmsy_verify.gen_bottleneck(
    pre INT, post INT, neck_cost FLOAT8
) RETURNS VOID LANGUAGE sql AS $$
    TRUNCATE dmmsy_verify.edges RESTART IDENTITY;
    -- Lead-in chain (very cheap)
    INSERT INTO dmmsy_verify.edges(source, target, cost)
    SELECT i, i + 1, 0.01
    FROM generate_series(1, pre - 1) i;
    -- Bottleneck edge
    INSERT INTO dmmsy_verify.edges(source, target, cost)
    VALUES (pre, pre + 1, neck_cost);
    -- Tail chain (very cheap)
    INSERT INTO dmmsy_verify.edges(source, target, cost)
    SELECT pre + i, pre + i + 1, 0.01
    FROM generate_series(1, post - 1) i;
$$;

-- 13. Near-complete: K_n minus a random fraction of edges
CREATE OR REPLACE FUNCTION dmmsy_verify.gen_near_complete(
    n INT, drop_pct FLOAT8 DEFAULT 0.1
) RETURNS VOID LANGUAGE plpgsql AS $$
BEGIN
    PERFORM setseed(0.5);
    TRUNCATE dmmsy_verify.edges RESTART IDENTITY;
    INSERT INTO dmmsy_verify.edges(source, target, cost)
    SELECT i, j, round((random() * 10 + 1)::numeric, 2)
    FROM generate_series(1, n) i
    CROSS JOIN generate_series(1, n) j
    WHERE i <> j
      AND random() > drop_pct;
END;
$$;

-- 14. Path with shortcuts: chain 1..n plus direct edges every skip hops
--     Shortcut cost = 0.5 * skip (slightly less than taking skip unit steps)
CREATE OR REPLACE FUNCTION dmmsy_verify.gen_shortcut_path(n INT, skip INT)
RETURNS VOID LANGUAGE sql AS $$
    TRUNCATE dmmsy_verify.edges RESTART IDENTITY;
    -- Base chain
    INSERT INTO dmmsy_verify.edges(source, target, cost)
    SELECT i, i + 1, 1.0
    FROM generate_series(1, n - 1) i;
    -- Shortcuts every skip steps
    INSERT INTO dmmsy_verify.edges(source, target, cost)
    SELECT i, LEAST(i + skip, n), 0.5 * skip
    FROM generate_series(1, n - 1) i
    WHERE (i % skip) = 0;
$$;

\echo '✓ 01_generators.sql loaded (14 generators)'
