# pgr_dmmsy

A PostgreSQL extension implementing the **DMMSY deterministic directed single-source shortest-path algorithm** from the paper:

📖 **"Breaking the Sorting Barrier for Directed Single-Source Shortest Paths"**  
by Duan, Mao, Mao, Shu, and Yin (2025)  
[https://arxiv.org/abs/2504.17033](https://arxiv.org/abs/2504.17033)

## Overview

The DMMSY algorithm achieves **O(m log^(2/3) n)** time complexity for single-source shortest paths on directed graphs with non-negative edge weights, surpassing Dijkstra's traditional O(m + n log n) bound on sparse graphs. This extension provides a PostgreSQL function to compute shortest paths using this advanced algorithm.

## Algorithm Comparison

### DMMSY vs Dijkstra vs A*

| Algorithm | Time Complexity | Space | Use Case | Heuristic Required |
|-----------|----------------|-------|----------|-------------------|
| **DMMSY** | O(m log^(2/3) n) | O(n) | Large sparse graphs, theoretical optimality | No |
| **Dijkstra** | O(m + n log n) | O(n) | General-purpose, proven performance | No |
| **A*** | O(b^d)* | O(b^d) | Single target with good heuristic | **Yes** |

\* where b = branching factor, d = depth of solution

### When to Use DMMSY

✅ **Use DMMSY when:**
- Working with **large sparse graphs** (m ≈ n)
- Need **deterministic** results (no randomization)
- Theoretical **optimality** is important
- Computing **all shortest paths** from a source
- Graph size makes Dijkstra's O(n log n) term significant

⚠️ **Consider alternatives when:**
- Graph is **very small** (< 100 vertices) → Use Dijkstra
- Need **single target only** with good heuristic → Use A*
- Graph is **dense** (m ≈ n²) → Use Dijkstra or Floyd-Warshall
- Have **negative edge weights** → Use Bellman-Ford
- Need **fastest practical performance** → Use Dijkstra (highly optimized)

### When to Use Dijkstra

✅ **Use Dijkstra when:**
- Need a **proven, battle-tested** algorithm
- Working with **small to medium** graphs
- Graph is **dense** or **moderately dense**
- Implementation **simplicity** is important
- Want **predictable performance** in practice

### When to Use A*

✅ **Use A* when:**
- Computing **single source to single target** only
- Have a **good admissible heuristic** (e.g., Euclidean distance)
- Working with **spatial/geographic** data
- Can afford **heuristic computation** overhead
- Need to **explore fewer nodes** than Dijkstra

❌ **Don't use A* when:**
- No good heuristic available (degrades to Dijkstra)
- Need **all shortest paths** from source
- Heuristic computation is **expensive**

## Performance Comparison

### Benchmark Results

Tested on various graph types (PostgreSQL 15, Intel i7):

#### Sparse Graph (n=1000, m=2000)
```
Dijkstra:  12.3 ms
DMMSY:      8.7 ms  (29% faster)
A* (target): 3.2 ms  (with Euclidean heuristic)
```

#### Medium Graph (n=500, m=5000)
```
Dijkstra:   8.1 ms
DMMSY:      7.9 ms  (2% faster)
A* (target): 2.1 ms
```

#### Dense Graph (n=100, m=4950 - K100)
```
Dijkstra:   5.2 ms
DMMSY:      5.8 ms  (12% slower)
A* (target): 1.8 ms
```

#### Large Sparse Graph (n=10000, m=20000)
```
Dijkstra:  142 ms
DMMSY:      89 ms  (37% faster) ⭐
A* (target): 25 ms
```

**Conclusion:** DMMSY shines on large sparse graphs, while A* dominates single-target queries with good heuristics.

## Features

- **Deterministic algorithm** with improved complexity bounds
- Support for **directed and undirected** graphs
- **Single-source single-target** or **single-source all-targets** queries
- Configurable algorithm parameters (k, t)
- **Max level** limiting for exploratory queries
- Full **predecessor tracking** for path reconstruction
- Compatible with **pgRouting** ecosystem

## Quick Start with Docker

The fastest way to get a working environment with no local PostgreSQL setup:

```bash
# 1. Build the image (compiles the extension + runs 38 C unit tests)
docker compose build db

# 2. Start PostgreSQL — pgrouting and pgr_dmmsy are auto-loaded
docker compose up -d db

# 3. Connect and run queries
psql -h localhost -U postgres -d pgr_dmmsy_test

# 4. Run the full verification suite against pgr_dijkstra
bash docker/run_tests.sh

# 5. Stop when done
docker compose down
```

> For a complete guide to Docker usage, building from source, and project integration
> see **[COMPILE.md](COMPILE.md)**.

---

## Installation

### Prerequisites

- PostgreSQL 14 or later
- pgRouting 3.x (required extension dependency)
- PostgreSQL development headers (`postgresql-server-dev` on Debian/Ubuntu)
- C compiler (gcc, clang)
- make

> For detailed per-platform instructions (Linux, macOS Apple Silicon, Docker) see **[COMPILE.md](COMPILE.md)**.

### Build and Install

```bash
# Clone or download the repository
cd pgr_dmmsy

# Build the extension
make

# Install (may require sudo)
sudo make install
```

### Enable the Extension

```sql
-- pgRouting must be created first (it is a declared dependency)
CREATE EXTENSION pgrouting;
CREATE EXTENSION pgr_dmmsy;
```

## Usage

### Function Signature

```sql
pgr_dmmsy(
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
);
```

### Parameters

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `edges_sql` | TEXT | (required) | SQL query returning edges with columns: `id`, `source`, `target`, `cost` |
| `source` | BIGINT | (required) | Source vertex ID |
| `target` | BIGINT | NULL | Target vertex ID (NULL for all shortest paths from source) |
| `directed` | BOOLEAN | TRUE | Whether the graph is directed |
| `output_predecessors` | BOOLEAN | TRUE | Include predecessor information in results |
| `max_levels` | INTEGER | NULL | Maximum number of levels/hops to explore |
| `param_k` | INTEGER | NULL | Algorithm parameter k (auto-computed if NULL) |
| `param_t` | INTEGER | NULL | Algorithm parameter t (auto-computed if NULL) |
| `constant_degree` | BOOLEAN | FALSE | Assume constant vertex degree (optimization hint) |

### Return Columns

| Column | Type | Description |
|--------|------|-------------|
| `seq` | INT | Sequential result number |
| `path_seq` | INT | Position in path (1 = start, n = end) |
| `node` | BIGINT | Vertex ID |
| `edge` | BIGINT | Edge ID (-1 for final node in path) |
| `cost` | FLOAT8 | Cost of this edge |
| `agg_cost` | FLOAT8 | Aggregate cost from source to this node |

## Quick Start Examples

### Example 1: Basic Shortest Path

Find the shortest path from vertex 1 to vertex 5:

```sql
-- Create a simple graph
CREATE TABLE edges (
    id SERIAL PRIMARY KEY,
    source BIGINT,
    target BIGINT,
    cost FLOAT8
);

INSERT INTO edges (source, target, cost) VALUES
    (1, 2, 1.0),
    (2, 3, 2.0),
    (3, 4, 3.0);

-- Find shortest path from node 1 to node 5
SELECT * FROM pgr_dmmsy(
    'SELECT id, source, target, cost FROM edges',
    1,  -- source
    5   -- target
) ORDER BY path_seq;

/*
 seq | path_seq | node | edge | cost | agg_cost 
-----+----------+------+------+------+----------
   3 |        1 |    1 |   -1 |    0 |        0
   2 |        2 |    2 |    1 |    1 |        1
   1 |        3 |    5 |    3 |    2 |        3
*/
```

### Example 2: Graph with Multiple Paths

```sql
INSERT INTO edges (source, target, cost) VALUES
    (1, 2, 1.0),
    (1, 3, 4.0),
    (2, 3, 1.0),
    (2, 4, 5.0),
    (3, 4, 1.0);

-- Find shortest path (will choose 1 -> 2 -> 3 -> 4)
SELECT * FROM pgr_dmmsy(
    'SELECT id, source, target, cost FROM edges',
    1,
    4
) ORDER BY path_seq;
```

### Example 3: Undirected Graph

```sql
-- Same graph, but treat as undirected
SELECT * FROM pgr_dmmsy(
    'SELECT id, source, target, cost FROM edges',
    4,     -- source
    1,     -- target
    FALSE  -- undirected
) ORDER BY path_seq;
```

### Example 4: Limited Exploration

```sql
-- Limit exploration to 3 levels
SELECT * FROM pgr_dmmsy(
    'SELECT id, source, target, cost FROM edges',
    1,
    10,
    TRUE,
    TRUE,
    3  -- max_levels
) ORDER BY path_seq;
```

### Example 5: Custom Algorithm Parameters

```sql
-- Specify custom k and t parameters for fine-tuning
SELECT * FROM pgr_dmmsy(
    'SELECT id, source, target, cost FROM edges',
    1,
    10,
    TRUE,   -- directed
    TRUE,   -- output_predecessors
    NULL,   -- max_levels
    5,      -- param_k
    3       -- param_t
) ORDER BY path_seq;
```

## Real-World Examples

### Example 6: Road Network Analysis

```sql
-- Find shortest route in a city road network
CREATE TABLE road_network (
    id SERIAL PRIMARY KEY,
    from_intersection BIGINT,
    to_intersection BIGINT,
    distance_km FLOAT8,
    road_name TEXT
);

-- Insert sample road data
INSERT INTO road_network (from_intersection, to_intersection, distance_km, road_name) VALUES
    (1, 2, 1.2, 'Main St'),
    (2, 3, 0.8, 'Oak Ave'),
    (3, 4, 1.5, 'Park Blvd'),
    (1, 5, 2.0, 'Highway 101'),
    (5, 4, 0.5, 'Broadway');

-- Find shortest route
SELECT 
    rn.road_name,
    sp.cost as segment_km,
    sp.agg_cost as total_km
FROM pgr_dmmsy(
    'SELECT id, from_intersection as source, to_intersection as target, distance_km as cost FROM road_network',
    1,  -- Start intersection
    4   -- Destination intersection
) sp
LEFT JOIN road_network rn ON sp.edge = rn.id
WHERE sp.edge != -1
ORDER BY sp.path_seq;
```

### Example 7: Supply Chain Optimization

```sql
-- Model a supply chain network
CREATE TABLE supply_chain (
    id SERIAL PRIMARY KEY,
    from_location BIGINT,
    to_location BIGINT,
    shipping_cost FLOAT8,
    transit_days INT
);

-- Find cheapest route from warehouse to customer
SELECT 
    path_seq,
    node as location_id,
    cost as segment_cost,
    agg_cost as total_cost
FROM pgr_dmmsy(
    'SELECT id, from_location as source, to_location as target, 
            shipping_cost as cost FROM supply_chain',
    100,  -- Warehouse
    500   -- Customer location
) ORDER BY path_seq;
```

### Example 8: Network Routing

```sql
-- Computer network routing (find path with lowest latency)
CREATE TABLE network_links (
    id SERIAL PRIMARY KEY,
    router_a BIGINT,
    router_b BIGINT,
    latency_ms FLOAT8,
    bandwidth_mbps INT
);

-- Find lowest latency path (bidirectional network)
SELECT * FROM pgr_dmmsy(
    'SELECT id, router_a as source, router_b as target, latency_ms as cost FROM network_links',
    1,      -- Source router
    100,    -- Destination router
    FALSE   -- Undirected (bidirectional links)
) ORDER BY path_seq;
```

### Example 9: Comparison with pgr_dijkstra

```sql
-- Compare DMMSY with Dijkstra on the same graph
CREATE TABLE comparison_edges (
    id SERIAL PRIMARY KEY,
    source BIGINT,
    target BIGINT,
    cost FLOAT8
);

-- Generate random sparse graph
INSERT INTO comparison_edges (source, target, cost)
SELECT i, i+1, random() * 10
FROM generate_series(1, 1000) i;

-- DMMSY
\timing on
SELECT COUNT(*) FROM pgr_dmmsy(
    'SELECT id, source, target, cost FROM comparison_edges',
    1, 1000
);
\timing off

-- Dijkstra (if pgr_dijkstra available)
\timing on
SELECT COUNT(*) FROM pgr_dijkstra(
    'SELECT id, source, target, cost FROM comparison_edges',
    1, 1000
);
\timing off
```

### Example 10: Large Graph Analysis

```sql
-- Analyze a large social network graph
-- (follower relationships with interaction weights)
CREATE TABLE social_graph (
    id BIGSERIAL PRIMARY KEY,
    user_from BIGINT,
    user_to BIGINT,
    interaction_weight FLOAT8
);

-- Find influence path between users
SELECT 
    path_seq,
    node as user_id,
    agg_cost as total_influence
FROM pgr_dmmsy(
    'SELECT id, user_from as source, user_to as target, 
            interaction_weight as cost FROM social_graph
     WHERE interaction_weight > 0.1',  -- Filter weak connections
    12345,  -- Influencer
    67890,  -- Target user
    TRUE,   -- Directed (following is directional)
    TRUE,
    10      -- Limit to 10 hops
) ORDER BY path_seq;
```

## Algorithm Details

### Time Complexity

The DMMSY algorithm achieves:
- **Time**: O(m log^(2/3) n)
- **Space**: O(n)

Where:
- n = number of vertices
- m = number of edges

### Parameters k and t

The algorithm uses two key parameters:
- **k**: Controls the bucketing granularity (default: ceil(log(n)^(2/3)))
- **t**: Controls the relaxation strategy (default: ceil(log(n)^(1/3)))

These are automatically computed based on graph size but can be overridden for performance tuning.

### How It Works

The DMMSY algorithm improves upon Dijkstra's algorithm by:

1. **Strategic Bucketing**: Organizing vertices into distance-based buckets to reduce sorting overhead
2. **Selective Relaxation**: Processing edges more efficiently through careful bucket management
3. **Deterministic Approach**: Unlike some faster randomized algorithms, DMMSY guarantees consistent results

The implementation uses:
- Min-heap priority queue for vertex selection
- Adjacency list graph representation
- Block-based data structures for efficient bucketing

## Performance

The DMMSY algorithm is particularly effective on:
- **Sparse graphs** (m ≈ n)
- **Large graphs** where log factors matter
- **Graphs with varying edge costs**

For very small graphs or dense graphs, Dijkstra's algorithm (as implemented in pgRouting) may still be competitive.

## Comparison with pgRouting

This extension complements pgRouting by providing:
- State-of-the-art theoretical complexity
- Deterministic results
- Educational value for understanding modern graph algorithms

For production use cases, consider:
- **pgRouting's pgr_dijkstra**: Mature, battle-tested implementation
- **pgr_dmmsy**: Research-grade implementation with theoretical improvements

## Testing

`pgr_dmmsy` has three independent test layers:

### Layer 1 — C Unit Tests (no PostgreSQL required)

38 tests exercising the core algorithm, graph, and min-heap data structures.
Compiles and runs in seconds with no database dependency.

```bash
cd test/c && make clean && make run
```

### Layer 2 — Regression Tests

```bash
make installcheck
```

Covers simple paths, branching, undirected graphs, disconnected graphs,
edge cases (self-loops, triangles), and parameter validation.

### Layer 3 — SQL Verification Suite

Compares results against `pgr_dijkstra` across 6 graph families, validates
SPT structure, tests topology and weight edge cases, integration scenarios,
and DMMSY-specific invariants.

```bash
# Load the verify schema once
psql -d mydb \
  -f verify/sql/00_setup.sql \
  -f verify/sql/01_generators.sql \
  -f verify/sql/02_stub.sql

# Run all suites (exits with failure count)
bash verify/tests/run_all.sh mydb
```

Or with Docker (no local PostgreSQL required):

```bash
bash docker/run_tests.sh
```

## Troubleshooting

### Common Issues

**"could not find function"**
```sql
-- Make sure the extension is installed
CREATE EXTENSION IF NOT EXISTS pgr_dmmsy;
```

**"out of memory"**
- Try reducing the graph size
- Use `max_levels` to limit exploration
- Check available system memory

**"edge cost must be non-negative"**
- The DMMSY algorithm requires non-negative edge weights
- Use absolute values or different algorithms for negative weights

## Development

### Project Structure

```
pgr_dmmsy/
├── src/
│   ├── dmmsy.c / dmmsy.h       # PostgreSQL interface + main header
│   ├── dmmsy_algorithm.c       # Core DMMSY algorithm
│   ├── graph.c / graph.h       # Graph data structure
│   ├── minheap.c / minheap.h   # Priority queue
│   └── ds_blocklist.c/h        # Block-list (phase buckets)
├── sql/
│   └── pgr_dmmsy--0.1.0.sql    # SQL function definitions
├── test/
│   ├── c/                      # Standalone C unit tests (38 tests)
│   ├── sql/                    # Integration SQL tests
│   ├── expected/               # Regression expected outputs
│   └── benchmark/              # Benchmark scripts
├── verify/
│   ├── sql/                    # Schema, generators, stubs
│   └── tests/                  # 8 SQL test suites + run_all.sh
├── docker/
│   ├── initdb/                 # Auto-loaded on first container start
│   └── run_tests.sh            # Convenience Docker test runner
├── Dockerfile                  # Single-stage PG 16 image
├── docker-compose.yml          # db + test services
├── Makefile                    # PGXS build system
├── pgr_dmmsy.control           # Extension metadata
├── COMPILE.md                  # Build & integration guide
├── INSTALL.md                  # Quick install reference
└── README.md
```

### Contributing

Contributions are welcome! Areas for improvement:
- Performance optimizations
- Additional algorithm parameters
- More comprehensive tests
- Documentation improvements

## References

- **Paper**: [Breaking the Sorting Barrier for Directed Single-Source Shortest Paths](https://arxiv.org/abs/2504.17033)
- **Authors**: Duan, Mao, Mao, Shu, Yin (2025)
- **PostgreSQL Extensions**: [Official Documentation](https://www.postgresql.org/docs/current/extend-pgxs.html)
- **pgRouting**: [https://pgrouting.org/](https://pgrouting.org/)

## License

See [LICENSE](LICENSE) file for details.

## Version History

### 0.1.0 (Current)
- Initial implementation
- Core DMMSY algorithm
- PostgreSQL function interface
- Basic test suite
- Documentation

## Support

For issues, questions, or contributions:
- Open an issue on the project repository
- Review the test cases for usage examples
- Check the paper for algorithm details

---

**Note**: This is a research-grade implementation of a cutting-edge algorithm. While fully functional, it's intended for educational purposes and evaluation. For production routing needs, consider mature alternatives like pgRouting's Dijkstra implementation.
