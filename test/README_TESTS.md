# Test Suite Documentation

## Overview

The pgr_dmmsy test suite consists of multiple layers of testing:

1. **C Unit Tests** - Test individual C components in isolation
2. **SQL Integration Tests** - Test PostgreSQL function interface
3. **Regression Tests** - Comprehensive end-to-end scenarios

## Test Structure

```
test/
├── c/                          # C unit tests
│   ├── test_graph.c           # Graph data structure tests
│   ├── test_minheap.c         # Min-heap priority queue tests
│   ├── test_algorithm.c       # DMMSY algorithm tests
│   └── Makefile               # Build system for C tests
├── sql/                        # SQL integration tests
│   ├── test_basic.sql         # Basic functionality tests
│   ├── test_edge_cases.sql    # Edge case scenarios
│   ├── test_parameters.sql    # Parameter combinations
│   └── test_performance.sql   # Performance benchmarks
├── pgr_dmmsy.sql              # Main regression test suite (31 tests)
├── expected/
│   └── pgr_dmmsy.out          # Expected output for regression tests
└── run_all_tests.sh           # Master test runner script
```

## Running Tests

### Run All Tests

```bash
./test/run_all_tests.sh
```

This runs:
- C unit tests
- SQL integration tests
- PostgreSQL regression tests

### Run C Unit Tests Only

```bash
cd test/c
make run
```

Individual test executables:
```bash
./test_graph      # Graph tests
./test_minheap    # MinHeap tests
./test_algorithm  # Algorithm tests
```

### Run SQL Tests Only

```bash
psql -f test/sql/test_basic.sql
psql -f test/sql/test_edge_cases.sql
psql -f test/sql/test_parameters.sql
psql -f test/sql/test_performance.sql
```

### Run Regression Tests

```bash
make installcheck
```

View differences if tests fail:
```bash
cat regression.diffs
```

## Test Coverage

### C Unit Tests (24 tests)

#### Graph Tests (8 tests)
- Graph creation and initialization
- Vertex addition and lookup
- Edge addition and adjacency lists
- Capacity expansion
- Multiple edges between vertices
- Reverse edge creation (undirected)
- Large vertex ID handling

#### MinHeap Tests (8 tests)
- Heap creation and initialization
- Insert and extract-min operations
- Decrease-key operation
- Contains check
- Ordering verification
- Equal priorities handling
- Many operations (50+ items)
- Zero priority handling

#### Algorithm Tests (8 tests)
- Simple path finding
- Shortest path selection among alternatives
- Disconnected graph handling
- Source equals target
- Max levels parameter
- Zero-cost edges
- Custom k and t parameters
- Path reconstruction

### SQL Integration Tests (40+ tests)

#### Basic Functionality Tests (4 tests)
- Simple linear paths
- Multiple path selection
- Source equals target
- No path exists scenarios

#### Edge Case Tests (7 tests)
- Very small costs (0.000001)
- Very large costs (millions)
- Single edge graphs
- Many parallel edges
- Self-loops
- Decreasing vertex IDs
- Negative vertex IDs

#### Parameter Tests (10 tests)
- directed TRUE/FALSE
- max_levels variations
- param_k custom values
- param_t custom values
- target NULL
- constant_degree flag
- All default parameters

#### Performance Tests (6 tests)
- Linear chain (100 vertices)
- Complete graph K10
- Star topology (100 edges)
- Grid 10x10 (180 edges)
- Random graph (500 edges)
- Sparse graph with large IDs

### Regression Tests (31 tests)

See `test/pgr_dmmsy.sql` for comprehensive scenarios:
- Graph topologies: linear, branching, star, grid, dense, sparse
- Edge types: zero-cost, fractional, parallel, bottleneck
- Special cases: cycles, disconnected, self-loops, triangles
- Parameter testing: max_levels, custom k/t

## Total Test Coverage

| Category | Tests | Files |
|----------|-------|-------|
| C Unit Tests | 24 | 3 |
| SQL Integration | 40+ | 4 |
| Regression | 31 | 1 |
| **Total** | **95+** | **8** |

## Code Coverage Analysis

### Functions Tested

#### Graph Module
✅ `graph_create`
✅ `graph_free`
✅ `graph_add_vertex`
✅ `graph_get_vertex_index`
✅ `graph_add_edge`
✅ `graph_add_reverse_edge`

#### MinHeap Module
✅ `minheap_create`
✅ `minheap_free`
✅ `minheap_insert`
✅ `minheap_extract_min`
✅ `minheap_decrease_key`
✅ `minheap_contains`
✅ `minheap_is_empty`

#### Algorithm Module
✅ `dmmsy_compute`
✅ `dmmsy_result_free`
✅ `dmmsy_get_path`
✅ Edge relaxation
✅ Priority queue operations
✅ Path reconstruction
✅ Early termination

#### PostgreSQL Interface
✅ SQL function `pgr_dmmsy`
✅ Edge query parsing
✅ Graph construction from SQL
✅ Result formatting
✅ Error handling

### Parameters Tested

| Parameter | Coverage |
|-----------|----------|
| edges_sql | ✅ Various queries |
| source | ✅ Multiple values |
| target | ✅ NULL and specific |
| directed | ✅ TRUE/FALSE |
| output_predecessors | ⚠️ Only TRUE |
| max_levels | ✅ NULL and limits |
| param_k | ✅ NULL and custom |
| param_t | ✅ NULL and custom |
| constant_degree | ⚠️ Only FALSE |

### Scenarios Covered

✅ Simple paths
✅ Branching paths
✅ Cycles
✅ Disconnected graphs
✅ Undirected graphs
✅ Zero-cost edges
✅ Fractional costs
✅ Large vertex IDs
✅ Parallel edges
✅ Dense graphs
✅ Sparse graphs
✅ Grid topology
✅ Star topology
✅ Single edge
✅ Self-loops
✅ Max levels
✅ Custom parameters
✅ Equal-cost paths
✅ Bottleneck paths
✅ Long chains
✅ Multiple components

### Not Yet Tested

❌ Negative edge costs (not supported by DMMSY)
❌ Invalid SQL queries (error handling)
❌ NULL cost values (should error)
❌ Empty graph
❌ Memory leak testing (needs valgrind)
❌ Concurrent access
❌ Very large graphs (10000+ vertices)
❌ output_predecessors = FALSE
❌ constant_degree = TRUE

## Adding New Tests

### Adding C Unit Tests

1. Create test function in appropriate file:
```c
void test_my_feature(void) {
    TEST("my_feature");
    // ... test code ...
    PASS();
}
```

2. Call from main():
```c
int main(void) {
    test_my_feature();
    return 0;
}
```

### Adding SQL Tests

1. Create test in appropriate SQL file:
```sql
SELECT '=== Test: My Test Case ===' AS test_name;
SELECT * FROM pgr_dmmsy(...) ORDER BY path_seq;
```

2. Run with psql:
```bash
psql -f test/sql/test_yourfile.sql
```

### Adding Regression Tests

1. Add test case to `test/pgr_dmmsy.sql`
2. Run tests to generate expected output:
```bash
make installcheck
```
3. If correct, update expected output:
```bash
cp results/pgr_dmmsy.out test/expected/
```

## Continuous Integration

Tests run automatically on:
- Every push to main/master/develop
- Every pull request
- Multiple PostgreSQL versions (12, 13, 14, 15, 16)
- Multiple platforms (Ubuntu, macOS)

See `.github/workflows/ci.yml` for CI configuration.

## Performance Benchmarks

Run performance tests:
```bash
psql -f test/sql/test_performance.sql
```

Expected performance (approximate):
- 100 vertices: < 10ms
- 500 edges: < 50ms
- Grid 10x10: < 20ms

## Debugging Failed Tests

### C Tests Fail

1. Compile with debug symbols:
```bash
cd test/c
make clean
make CFLAGS="-Wall -Wextra -g -O0"
```

2. Run with gdb:
```bash
gdb ./test_graph
```

### SQL Tests Fail

1. Run test file directly to see errors:
```bash
psql -f test/sql/test_basic.sql
```

2. Check PostgreSQL logs:
```bash
tail -f /var/log/postgresql/postgresql-15-main.log
```

### Regression Tests Fail

1. Check regression.diffs:
```bash
cat regression.diffs
```

2. View actual vs expected:
```bash
diff test/expected/pgr_dmmsy.out results/pgr_dmmsy.out
```

## Memory Testing

Run tests with valgrind:
```bash
cd test/c
valgrind --leak-check=full ./test_graph
valgrind --leak-check=full ./test_minheap
valgrind --leak-check=full ./test_algorithm
```

## Coverage Reports

Generate coverage report (requires gcov):
```bash
cd test/c
make CFLAGS="-fprofile-arcs -ftest-coverage"
make run
gcov *.c
```

---

For more information, see:
- `README.md` - Project overview
- `IMPLEMENTATION_NOTES.md` - Algorithm details
- `CONTRIBUTING.md` - Contribution guidelines

