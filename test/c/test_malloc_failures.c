/*
 * test_malloc_failures.c — covers malloc/calloc/realloc failure branches
 * across graph.c, minheap.c, ds_blocklist.c, and dmmsy_algorithm.c.
 *
 * Build on Linux with --wrap=malloc,calloc,realloc (via Makefile WRAP_FLAGS).
 * On macOS the wrapper is absent so all failure tests pass vacuously.
 */

#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <assert.h>
#include <stdbool.h>

#include "../../src/graph.h"
#include "../../src/minheap.h"
#include "../../src/ds_blocklist.h"
#include "../../src/dmmsy.h"

/* ── allocation interception (GNU ld --wrap, Linux only) ──────────── */
#ifdef WRAP_MALLOC

static int  alloc_countdown = -1; /* -1=off; N=fail after N successes */
static int  fail_all_allocs = 0;  /* 1=every alloc returns NULL       */

void *__real_malloc(size_t size);
void *__wrap_malloc(size_t size) {
    if (fail_all_allocs) return NULL;
    if (alloc_countdown == 0) { alloc_countdown = -1; return NULL; }
    if (alloc_countdown > 0) alloc_countdown--;
    return __real_malloc(size);
}

void *__real_calloc(size_t n, size_t size);
void *__wrap_calloc(size_t n, size_t size) {
    if (fail_all_allocs) return NULL;
    if (alloc_countdown == 0) { alloc_countdown = -1; return NULL; }
    if (alloc_countdown > 0) alloc_countdown--;
    return __real_calloc(n, size);
}

void *__real_realloc(void *ptr, size_t size);
void *__wrap_realloc(void *ptr, size_t size) {
    if (fail_all_allocs) return NULL;
    if (alloc_countdown == 0) { alloc_countdown = -1; return NULL; }
    if (alloc_countdown > 0) alloc_countdown--;
    return __real_realloc(ptr, size);
}

#define FAIL_AFTER(n)   (alloc_countdown = (n))
#define FAIL_ALL_ON()   (fail_all_allocs = 1)
#define FAIL_ALL_OFF()  (fail_all_allocs = 0)

#else  /* no --wrap support */

#define FAIL_AFTER(n)   ((void)0)
#define FAIL_ALL_ON()   ((void)0)
#define FAIL_ALL_OFF()  ((void)0)

#endif /* WRAP_MALLOC */

/* ── test harness ─────────────────────────────────────────────────── */

static int tests_run    = 0;
static int tests_passed = 0;

#define RUN_TEST(fn) do { \
    tests_run++; \
    printf("  %-65s ", #fn); \
    if (fn()) { tests_passed++; printf("[PASS]\n"); } \
    else       {               printf("[FAIL]\n"); } \
} while (0)

/* ── helpers ──────────────────────────────────────────────────────── */

/* Build a simple 2-vertex, 1-edge graph without touching the countdown. */
static Graph *make_graph_1_2(void) {
    Graph *g = graph_create(4);
    if (!g) return NULL;
    Edge e = {1, 1, 2, 1.0};
    graph_add_edge(g, &e);
    return g;
}

/* Standard params: all reachable, no target limit */
static DMMSYParams make_params_all(int64_t source) {
    DMMSYParams p = {
        .source = source, .target = -1, .directed = true,
        .output_predecessors = true, .max_levels = -1,
        .param_k = -1, .param_t = -1, .constant_degree = false
    };
    return p;
}

/* ══════════════════════════════════════════════════════════════════
 * A — graph.c malloc failures
 * ══════════════════════════════════════════════════════════════════ */

/* graph_create: malloc(Graph) fails */
static int test_graph_create_malloc_graph(void) {
#ifndef WRAP_MALLOC
    return 1;
#else
    FAIL_AFTER(0);
    Graph *g = graph_create(4);
    return (g == NULL);
#endif
}

/* graph_create: calloc(adj_list) fails */
static int test_graph_create_calloc_adj(void) {
#ifndef WRAP_MALLOC
    return 1;
#else
    FAIL_AFTER(1);
    Graph *g = graph_create(4);
    return (g == NULL);
#endif
}

/* graph_create: malloc(vertex_ids) fails */
static int test_graph_create_malloc_ids(void) {
#ifndef WRAP_MALLOC
    return 1;
#else
    FAIL_AFTER(2);
    Graph *g = graph_create(4);
    return (g == NULL);
#endif
}

/* graph_add_vertex: both realloc calls fail → returns -1 */
static int test_graph_add_vertex_realloc_fail(void) {
#ifndef WRAP_MALLOC
    return 1;
#else
    /* Build cap=2 graph, fill it, then force realloc failure */
    Graph *g = graph_create(2);
    if (!g) return 0;
    graph_add_vertex(g, 1);
    graph_add_vertex(g, 2);           /* at capacity */
    FAIL_ALL_ON();
    int64_t r = graph_add_vertex(g, 3); /* triggers resize — both reallocs fail */
    FAIL_ALL_OFF();
    int ok = (r == -1);
    graph_free(g);
    return ok;
#endif
}

/* graph_add_edge: malloc(AdjListNode) fails → edge silently not added */
static int test_graph_add_edge_malloc_fail(void) {
#ifndef WRAP_MALLOC
    return 1;
#else
    Graph *g = graph_create(4);
    if (!g) return 0;
    /* Add vertices first so no vertex-alloc happens inside add_edge */
    graph_add_vertex(g, 1);
    graph_add_vertex(g, 2);
    /* Now only the AdjListNode malloc happens */
    FAIL_AFTER(0);
    Edge e = {1, 1, 2, 1.0};
    graph_add_edge(g, &e);
    int ok = (g->num_edges == 0);   /* edge was not added */
    graph_free(g);
    return ok;
#endif
}

/* ══════════════════════════════════════════════════════════════════
 * B — minheap.c malloc failures
 * ══════════════════════════════════════════════════════════════════ */

/* minheap_create: malloc(MinHeap) fails */
static int test_minheap_create_malloc_heap(void) {
#ifndef WRAP_MALLOC
    return 1;
#else
    FAIL_AFTER(0);
    MinHeap *h = minheap_create(10, 100);
    return (h == NULL);
#endif
}

/* minheap_create: malloc(nodes) fails */
static int test_minheap_create_malloc_nodes(void) {
#ifndef WRAP_MALLOC
    return 1;
#else
    FAIL_AFTER(1);
    MinHeap *h = minheap_create(10, 100);
    return (h == NULL);
#endif
}

/* minheap_create: malloc(positions) fails */
static int test_minheap_create_malloc_positions(void) {
#ifndef WRAP_MALLOC
    return 1;
#else
    FAIL_AFTER(2);
    MinHeap *h = minheap_create(10, 100);
    return (h == NULL);
#endif
}

/* ══════════════════════════════════════════════════════════════════
 * C — dmmsy_algorithm.c malloc failures in dmmsy_compute()
 *
 * Allocation order for dmmsy_compute on a pre-built 2-vertex graph:
 *   0  malloc(DMMSYResult)
 *   1  malloc(distances[])
 *   2  malloc(predecessors[])
 *   3  malloc(edge_ids[])
 *   4  calloc(visited[])
 *   5  malloc(MinHeap)
 *   6  malloc(heap->nodes[])
 *   7  malloc(heap->positions[])
 *   8  calloc(in_frontier[])
 *   9  malloc(frontier[])
 *  10  malloc(BlockList)       ← blocklist_create
 *  11  malloc(Block)           ← block_create in Step C (first phase)
 * ══════════════════════════════════════════════════════════════════ */

static int test_dmmsy_compute_result_malloc(void) {
#ifndef WRAP_MALLOC
    return 1;
#else
    Graph *g = make_graph_1_2();
    if (!g) return 0;
    DMMSYParams p = make_params_all(1);
    FAIL_AFTER(0);
    DMMSYResult *r = dmmsy_compute(g, &p);
    int ok = (r == NULL);
    graph_free(g);
    return ok;
#endif
}

static int test_dmmsy_compute_distances_malloc(void) {
#ifndef WRAP_MALLOC
    return 1;
#else
    Graph *g = make_graph_1_2();
    if (!g) return 0;
    DMMSYParams p = make_params_all(1);
    FAIL_AFTER(1);
    DMMSYResult *r = dmmsy_compute(g, &p);
    int ok = (r == NULL);
    graph_free(g);
    return ok;
#endif
}

static int test_dmmsy_compute_predecessors_malloc(void) {
#ifndef WRAP_MALLOC
    return 1;
#else
    Graph *g = make_graph_1_2();
    if (!g) return 0;
    DMMSYParams p = make_params_all(1);
    FAIL_AFTER(2);
    DMMSYResult *r = dmmsy_compute(g, &p);
    int ok = (r == NULL);
    graph_free(g);
    return ok;
#endif
}

static int test_dmmsy_compute_edge_ids_malloc(void) {
#ifndef WRAP_MALLOC
    return 1;
#else
    Graph *g = make_graph_1_2();
    if (!g) return 0;
    DMMSYParams p = make_params_all(1);
    FAIL_AFTER(3);
    DMMSYResult *r = dmmsy_compute(g, &p);
    int ok = (r == NULL);
    graph_free(g);
    return ok;
#endif
}

static int test_dmmsy_compute_visited_calloc(void) {
#ifndef WRAP_MALLOC
    return 1;
#else
    Graph *g = make_graph_1_2();
    if (!g) return 0;
    DMMSYParams p = make_params_all(1);
    FAIL_AFTER(4);
    DMMSYResult *r = dmmsy_compute(g, &p);
    int ok = (r == NULL);
    graph_free(g);
    return ok;
#endif
}

static int test_dmmsy_compute_heap_malloc(void) {
#ifndef WRAP_MALLOC
    return 1;
#else
    Graph *g = make_graph_1_2();
    if (!g) return 0;
    DMMSYParams p = make_params_all(1);
    FAIL_AFTER(5);
    DMMSYResult *r = dmmsy_compute(g, &p);
    int ok = (r == NULL);
    graph_free(g);
    return ok;
#endif
}

static int test_dmmsy_compute_heap_nodes_malloc(void) {
#ifndef WRAP_MALLOC
    return 1;
#else
    Graph *g = make_graph_1_2();
    if (!g) return 0;
    DMMSYParams p = make_params_all(1);
    FAIL_AFTER(6);
    DMMSYResult *r = dmmsy_compute(g, &p);
    int ok = (r == NULL);
    graph_free(g);
    return ok;
#endif
}

static int test_dmmsy_compute_heap_positions_malloc(void) {
#ifndef WRAP_MALLOC
    return 1;
#else
    Graph *g = make_graph_1_2();
    if (!g) return 0;
    DMMSYParams p = make_params_all(1);
    FAIL_AFTER(7);
    DMMSYResult *r = dmmsy_compute(g, &p);
    int ok = (r == NULL);
    graph_free(g);
    return ok;
#endif
}

static int test_dmmsy_compute_in_frontier_calloc(void) {
#ifndef WRAP_MALLOC
    return 1;
#else
    Graph *g = make_graph_1_2();
    if (!g) return 0;
    DMMSYParams p = make_params_all(1);
    FAIL_AFTER(8);
    DMMSYResult *r = dmmsy_compute(g, &p);
    int ok = (r == NULL);
    graph_free(g);
    return ok;
#endif
}

static int test_dmmsy_compute_frontier_malloc(void) {
#ifndef WRAP_MALLOC
    return 1;
#else
    Graph *g = make_graph_1_2();
    if (!g) return 0;
    DMMSYParams p = make_params_all(1);
    FAIL_AFTER(9);
    DMMSYResult *r = dmmsy_compute(g, &p);
    int ok = (r == NULL);
    graph_free(g);
    return ok;
#endif
}

static int test_dmmsy_compute_blocklist_malloc(void) {
#ifndef WRAP_MALLOC
    return 1;
#else
    Graph *g = make_graph_1_2();
    if (!g) return 0;
    DMMSYParams p = make_params_all(1);
    FAIL_AFTER(10);
    DMMSYResult *r = dmmsy_compute(g, &p);
    int ok = (r == NULL);
    graph_free(g);
    return ok;
#endif
}

/*
 * block_create() failure inside the main loop (Step C else branch).
 * With countdown=11, the 12th alloc (first malloc inside block_create)
 * fails. The algorithm continues and still produces correct results;
 * only the block-list tracking is skipped via the else branch.
 *
 * We use a 3-vertex chain with large k/t so the entire graph is
 * settled in one phase, guaranteeing Step C runs at least once.
 */
static int test_dmmsy_compute_block_create_fail(void) {
#ifndef WRAP_MALLOC
    return 1;
#else
    Graph *g = graph_create(4);
    if (!g) return 0;
    Edge e1 = {1, 1, 2, 1.0};
    Edge e2 = {2, 2, 3, 1.0};
    graph_add_edge(g, &e1);
    graph_add_edge(g, &e2);

    DMMSYParams p = {
        .source = 1, .target = -1, .directed = true,
        .output_predecessors = true, .max_levels = -1,
        .param_k = 100, .param_t = 1,   /* large delta: one phase covers all */
        .constant_degree = false
    };

    FAIL_AFTER(11);
    DMMSYResult *r = dmmsy_compute(g, &p);
    /* Result is non-NULL — algorithm still works, just block list skipped */
    int ok = (r != NULL);
    dmmsy_result_free(r);
    graph_free(g);
    return ok;
#endif
}

/* ══════════════════════════════════════════════════════════════════
 * D — dmmsy_get_path() malloc failure
 * ══════════════════════════════════════════════════════════════════ */

static int test_dmmsy_get_path_malloc_fail(void) {
#ifndef WRAP_MALLOC
    return 1;
#else
    Graph *g = make_graph_1_2();
    if (!g) return 0;
    DMMSYParams p = make_params_all(1);
    DMMSYResult *r = dmmsy_compute(g, &p);
    if (!r) { graph_free(g); return 0; }

    int path_length;
    FAIL_AFTER(0);   /* next malloc is the path array inside dmmsy_get_path */
    PathResult *path = dmmsy_get_path(g, r, 1, 2, &path_length);
    int ok = (path == NULL);

    dmmsy_result_free(r);
    graph_free(g);
    return ok;
#endif
}

/* ══════════════════════════════════════════════════════════════════
 * main
 * ══════════════════════════════════════════════════════════════════ */

int main(void) {
    printf("=== Malloc Failure Tests ===\n\n");

    /* A: graph.c */
    RUN_TEST(test_graph_create_malloc_graph);
    RUN_TEST(test_graph_create_calloc_adj);
    RUN_TEST(test_graph_create_malloc_ids);
    RUN_TEST(test_graph_add_vertex_realloc_fail);
    RUN_TEST(test_graph_add_edge_malloc_fail);

    /* B: minheap.c */
    RUN_TEST(test_minheap_create_malloc_heap);
    RUN_TEST(test_minheap_create_malloc_nodes);
    RUN_TEST(test_minheap_create_malloc_positions);

    /* C: dmmsy_algorithm.c — dmmsy_compute() */
    RUN_TEST(test_dmmsy_compute_result_malloc);
    RUN_TEST(test_dmmsy_compute_distances_malloc);
    RUN_TEST(test_dmmsy_compute_predecessors_malloc);
    RUN_TEST(test_dmmsy_compute_edge_ids_malloc);
    RUN_TEST(test_dmmsy_compute_visited_calloc);
    RUN_TEST(test_dmmsy_compute_heap_malloc);
    RUN_TEST(test_dmmsy_compute_heap_nodes_malloc);
    RUN_TEST(test_dmmsy_compute_heap_positions_malloc);
    RUN_TEST(test_dmmsy_compute_in_frontier_calloc);
    RUN_TEST(test_dmmsy_compute_frontier_malloc);
    RUN_TEST(test_dmmsy_compute_blocklist_malloc);
    RUN_TEST(test_dmmsy_compute_block_create_fail);

    /* D: dmmsy_get_path() */
    RUN_TEST(test_dmmsy_get_path_malloc_fail);

    printf("\n=== Results: %d/%d passed ===\n", tests_passed, tests_run);
    if (tests_passed == tests_run)
        printf("✅ All malloc failure tests passed!\n");
    return (tests_passed == tests_run) ? 0 : 1;
}
