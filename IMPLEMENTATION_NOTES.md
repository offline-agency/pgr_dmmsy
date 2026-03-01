# Implementation Notes

## Overview

This PostgreSQL extension implements the DMMSY deterministic directed single-source shortest-path algorithm from the paper ["Breaking the Sorting Barrier for Directed Single-Source Shortest Paths"](https://arxiv.org/pdf/2504.17033) by Duan, Mao, Mao, Shu, and Yin (2025).

## Algorithm Implementation

### Theoretical Background

The DMMSY algorithm achieves **O(m log^(2/3) n)** time complexity, breaking Dijkstra's O(m + n log n) bound on sparse graphs. The key innovations from the paper:

1. **Frontier Reduction**: Limits the size of the frontier to |U|/log^Ω(1)(n) vertices
2. **Hybrid Approach**: Merges Dijkstra's priority queue with Bellman-Ford dynamic programming
3. **Recursive Partitioning**: Divides computation into log n/t levels with strategic bucketing

### Current Implementation

This implementation provides a **simplified but functional version** that:

- Uses Dijkstra-style priority queue processing
- Supports configurable parameters k and t (auto-computed by default)
- Implements proper graph data structures (adjacency lists)
- Handles both directed and undirected graphs
- Provides path reconstruction with predecessors

### Algorithm Parameters

From the paper, the optimal parameters are:
- **k = ceil(log(n)^(2/3))**: Controls bucketing granularity
- **t = ceil(log(n)^(1/3))**: Controls relaxation strategy

These are automatically computed based on graph size but can be overridden for tuning.

### Implementation Simplifications

For practical usability, this implementation includes:

1. **Core Dijkstra-based approach**: The full DMMSY recursive partitioning would be significantly more complex
2. **Parameter hooks**: Infrastructure in place for future full DMMSY implementation
3. **Clean API**: PostgreSQL-friendly interface matching pgRouting conventions

### Future Enhancements

To achieve full O(m log^(2/3) n) complexity, future versions could add:

1. **Recursive partitioning**: Implement the log n/t levels with frontier sets
2. **Bellman-Ford integration**: Add k-step Bellman-Ford for pivot identification
3. **Block-based processing**: Use the ds_blocklist structure for distance-range buckets
4. **Pivot selection**: Implement the frontier reduction technique from Section 3 of the paper

## Code Structure

### Core Files

```
src/
├── dmmsy.c              # PostgreSQL C extension interface
├── dmmsy.h              # Main header
├── dmmsy_algorithm.c    # Core SSSP algorithm
├── graph.c/h            # Graph representation (adjacency lists)
├── minheap.c/h          # Priority queue (min-heap)
└── ds_blocklist.c/h     # Block list data structure
```

### Key Functions

#### `dmmsy_compute(Graph *graph, DMMSYParams *params)`
Main algorithm entry point. Takes a graph and parameters, returns distance/predecessor arrays.

#### `dmmsy_get_path(Graph *graph, DMMSYResult *result, ...)`
Extracts shortest path from source to target using predecessor information.

#### `graph_add_edge(Graph *graph, Edge *edge)`
Adds directed edge to graph's adjacency list representation.

#### `minheap_extract_min(MinHeap *heap)`
Priority queue operations for vertex selection.

## Data Structures

### Graph Representation

Uses **adjacency lists** for efficient edge traversal:
- Maps vertex IDs to internal indices
- Dynamic capacity expansion
- O(1) edge addition, O(degree) traversal

### Priority Queue

**Min-heap** with decrease-key operation:
- O(log n) insert/extract-min
- O(log n) decrease-key
- Position tracking for fast lookup

### Block List

**Distance-range buckets** for future frontier reduction:
- Organizes vertices by distance ranges
- Supports efficient range queries
- Currently used minimally, ready for full DMMSY

## PostgreSQL Integration

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
```

### SPI (Server Programming Interface)

- Executes user SQL query to fetch edges
- Validates edge data (non-null, non-negative costs)
- Converts between PostgreSQL and C types
- Returns results as table via SRF (Set Returning Function)

### Memory Management

- Uses PostgreSQL's memory contexts
- Proper cleanup in error paths
- SRF context for multi-row results

## Testing

Comprehensive test suite in `test/pgr_dmmsy.sql`:

1. Simple paths
2. Branching graphs
3. Undirected graphs
4. Complex multi-path scenarios
5. Disconnected graphs (no path)
6. Self-loops
7. Triangle paths
8. Max levels limiting
9. Large graphs

## Performance Characteristics

Current implementation:
- **Time**: O(m log n) (Dijkstra with binary heap)
- **Space**: O(n + m)

With full DMMSY enhancements:
- **Time**: O(m log^(2/3) n)
- **Space**: O(n + m)

## References

- [DMMSY 2025 Paper](https://arxiv.org/pdf/2504.17033) - Original algorithm
- [Dijkstra 1959] - Classic SSSP algorithm
- [Bellman 1958] - Dynamic programming approach
- [pgRouting](https://pgrouting.org/) - PostgreSQL routing extension ecosystem
- [PGXS](https://www.postgresql.org/docs/current/extend-pgxs.html) - PostgreSQL extension build system

## License

See LICENSE file.

## Contributors

Implementation based on the theoretical work by:
- Ran Duan (Tsinghua University)
- Jiayi Mao (Tsinghua University)
- Xiao Mao (Stanford University)
- Xinkai Shu (Max Planck Institute for Informatics)
- Longhui Yin (Tsinghua University)

