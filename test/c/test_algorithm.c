/*
 * Unit tests for dmmsy_algorithm.c
 */

#include <stdio.h>
#include <stdlib.h>
#include <assert.h>
#include <math.h>
#include <float.h>
#include "../../src/dmmsy.h"
#include "../../src/graph.h"

#define TEST(name) printf("Testing %s...\n", name)
#define PASS() printf("  ✓ PASS\n")
#define FAIL(msg) do { printf("  ✗ FAIL: %s\n", msg); exit(1); } while(0)
#define EPSILON 0.0001

int double_equal(double a, double b) {
    return fabs(a - b) < EPSILON;
}

void test_simple_path(void) {
    TEST("simple_path");
    
    /* Create graph: 1 -> 2 -> 3 */
    Graph *graph = graph_create(10);
    Edge e1 = {1, 1, 2, 1.0};
    Edge e2 = {2, 2, 3, 2.0};
    
    graph_add_edge(graph, &e1);
    graph_add_edge(graph, &e2);
    
    DMMSYParams params = {
        .source = 1,
        .target = 3,
        .directed = true,
        .output_predecessors = true,
        .max_levels = -1,
        .param_k = -1,
        .param_t = -1,
        .constant_degree = false
    };
    
    DMMSYResult *result = dmmsy_compute(graph, &params);
    assert(result != NULL);
    
    int64_t idx1 = graph_get_vertex_index(graph, 1);
    int64_t idx2 = graph_get_vertex_index(graph, 2);
    int64_t idx3 = graph_get_vertex_index(graph, 3);
    
    assert(double_equal(result->distances[idx1], 0.0));
    assert(double_equal(result->distances[idx2], 1.0));
    assert(double_equal(result->distances[idx3], 3.0));
    
    dmmsy_result_free(result);
    graph_free(graph);
    PASS();
}

void test_shortest_path_selection(void) {
    TEST("shortest_path_selection");
    
    /* Graph with two paths: 1->2->3 (cost 2) and 1->3 (cost 10) */
    Graph *graph = graph_create(10);
    Edge e1 = {1, 1, 2, 1.0};
    Edge e2 = {2, 2, 3, 1.0};
    Edge e3 = {3, 1, 3, 10.0};
    
    graph_add_edge(graph, &e1);
    graph_add_edge(graph, &e2);
    graph_add_edge(graph, &e3);
    
    DMMSYParams params = {
        .source = 1,
        .target = 3,
        .directed = true,
        .output_predecessors = true,
        .max_levels = -1,
        .param_k = -1,
        .param_t = -1,
        .constant_degree = false
    };
    
    DMMSYResult *result = dmmsy_compute(graph, &params);
    int64_t idx3 = graph_get_vertex_index(graph, 3);
    
    /* Should choose shorter path */
    assert(double_equal(result->distances[idx3], 2.0));
    
    dmmsy_result_free(result);
    graph_free(graph);
    PASS();
}

void test_disconnected_graph(void) {
    TEST("disconnected_graph");
    
    /* Graph: 1->2, 3->4 (disconnected) */
    Graph *graph = graph_create(10);
    Edge e1 = {1, 1, 2, 1.0};
    Edge e2 = {2, 3, 4, 1.0};
    
    graph_add_edge(graph, &e1);
    graph_add_edge(graph, &e2);
    
    DMMSYParams params = {
        .source = 1,
        .target = 4,
        .directed = true,
        .output_predecessors = true,
        .max_levels = -1,
        .param_k = -1,
        .param_t = -1,
        .constant_degree = false
    };
    
    DMMSYResult *result = dmmsy_compute(graph, &params);
    int path_length;
    PathResult *path = dmmsy_get_path(graph, result, 1, 4, &path_length);
    
    /* No path should exist */
    assert(path == NULL);
    assert(path_length == 0);
    
    dmmsy_result_free(result);
    graph_free(graph);
    PASS();
}

void test_source_equals_target(void) {
    TEST("source_equals_target");
    
    Graph *graph = graph_create(10);
    Edge e1 = {1, 1, 2, 1.0};
    graph_add_edge(graph, &e1);
    
    DMMSYParams params = {
        .source = 1,
        .target = 1,
        .directed = true,
        .output_predecessors = true,
        .max_levels = -1,
        .param_k = -1,
        .param_t = -1,
        .constant_degree = false
    };
    
    DMMSYResult *result = dmmsy_compute(graph, &params);
    int64_t idx1 = graph_get_vertex_index(graph, 1);
    
    assert(double_equal(result->distances[idx1], 0.0));
    
    int path_length;
    PathResult *path = dmmsy_get_path(graph, result, 1, 1, &path_length);
    assert(path != NULL);
    assert(path_length == 1);
    assert(path[0].node == 1);
    
    free(path);
    dmmsy_result_free(result);
    graph_free(graph);
    PASS();
}

void test_max_levels(void) {
    TEST("max_levels");
    
    /* Chain: 1->2->3->4->5 */
    Graph *graph = graph_create(10);
    Edge e1 = {1, 1, 2, 1.0};
    Edge e2 = {2, 2, 3, 1.0};
    Edge e3 = {3, 3, 4, 1.0};
    Edge e4 = {4, 4, 5, 1.0};
    
    graph_add_edge(graph, &e1);
    graph_add_edge(graph, &e2);
    graph_add_edge(graph, &e3);
    graph_add_edge(graph, &e4);
    
    DMMSYParams params = {
        .source = 1,
        .target = 5,
        .directed = true,
        .output_predecessors = true,
        .max_levels = 2,  /* Stop after 2 levels */
        .param_k = -1,
        .param_t = -1,
        .constant_degree = false
    };
    
    DMMSYResult *result = dmmsy_compute(graph, &params);
    int path_length;
    PathResult *path = dmmsy_get_path(graph, result, 1, 5, &path_length);
    
    /* Should not reach vertex 5 with max_levels=2 */
    assert(path == NULL);
    
    dmmsy_result_free(result);
    graph_free(graph);
    PASS();
}

void test_zero_cost_edges(void) {
    TEST("zero_cost_edges");
    
    Graph *graph = graph_create(10);
    Edge e1 = {1, 1, 2, 0.0};
    Edge e2 = {2, 2, 3, 0.0};
    Edge e3 = {3, 3, 4, 1.0};
    
    graph_add_edge(graph, &e1);
    graph_add_edge(graph, &e2);
    graph_add_edge(graph, &e3);
    
    DMMSYParams params = {
        .source = 1,
        .target = 4,
        .directed = true,
        .output_predecessors = true,
        .max_levels = -1,
        .param_k = -1,
        .param_t = -1,
        .constant_degree = false
    };
    
    DMMSYResult *result = dmmsy_compute(graph, &params);
    int64_t idx4 = graph_get_vertex_index(graph, 4);
    
    assert(double_equal(result->distances[idx4], 1.0));
    
    dmmsy_result_free(result);
    graph_free(graph);
    PASS();
}

void test_custom_parameters(void) {
    TEST("custom_parameters");
    
    Graph *graph = graph_create(10);
    Edge e1 = {1, 1, 2, 1.0};
    Edge e2 = {2, 2, 3, 2.0};
    
    graph_add_edge(graph, &e1);
    graph_add_edge(graph, &e2);
    
    DMMSYParams params = {
        .source = 1,
        .target = 3,
        .directed = true,
        .output_predecessors = true,
        .max_levels = -1,
        .param_k = 10,  /* Custom k */
        .param_t = 5,   /* Custom t */
        .constant_degree = false
    };
    
    DMMSYResult *result = dmmsy_compute(graph, &params);
    int64_t idx3 = graph_get_vertex_index(graph, 3);
    
    assert(double_equal(result->distances[idx3], 3.0));
    
    dmmsy_result_free(result);
    graph_free(graph);
    PASS();
}

void test_path_reconstruction(void) {
    TEST("path_reconstruction");
    
    /* 1->2->3->4 */
    Graph *graph = graph_create(10);
    Edge e1 = {1, 1, 2, 1.0};
    Edge e2 = {2, 2, 3, 2.0};
    Edge e3 = {3, 3, 4, 3.0};
    
    graph_add_edge(graph, &e1);
    graph_add_edge(graph, &e2);
    graph_add_edge(graph, &e3);
    
    DMMSYParams params = {
        .source = 1,
        .target = 4,
        .directed = true,
        .output_predecessors = true,
        .max_levels = -1,
        .param_k = -1,
        .param_t = -1,
        .constant_degree = false
    };
    
    DMMSYResult *result = dmmsy_compute(graph, &params);
    int path_length;
    PathResult *path = dmmsy_get_path(graph, result, 1, 4, &path_length);
    
    assert(path != NULL);
    assert(path_length == 4);
    
    /* Verify path sequence */
    assert(path[0].node == 1);
    assert(path[1].node == 2);
    assert(path[2].node == 3);
    assert(path[3].node == 4);
    
    /* Verify costs */
    assert(double_equal(path[0].agg_cost, 0.0));
    assert(double_equal(path[1].agg_cost, 1.0));
    assert(double_equal(path[2].agg_cost, 3.0));
    assert(double_equal(path[3].agg_cost, 6.0));
    
    free(path);
    dmmsy_result_free(result);
    graph_free(graph);
    PASS();
}

/* ---------------------------------------------------------------
 * DMMSY-specific tests
 * --------------------------------------------------------------- */

/*
 * BF convergence: on a chain of exactly k hops (where k is the
 * computed BF-rounds parameter), all vertices should be reachable
 * in 1 DMMSY phase with param_k == chain_length.
 */
void test_bellman_ford_rounds_settle_chain(void) {
    TEST("bellman_ford_rounds_settle_chain");

    /* Chain: 1->2->3->4  (3 edges, all within one BF sweep with k=3) */
    Graph *graph = graph_create(10);
    Edge e1 = {1, 1, 2, 0.1};
    Edge e2 = {2, 2, 3, 0.1};
    Edge e3 = {3, 3, 4, 0.1};

    graph_add_edge(graph, &e1);
    graph_add_edge(graph, &e2);
    graph_add_edge(graph, &e3);

    /* Force param_k=3 so a single BF pass settles the whole chain */
    DMMSYParams params = {
        .source = 1,
        .target = 4,
        .directed = true,
        .output_predecessors = true,
        .max_levels = -1,
        .param_k = 3,
        .param_t = 1,
        .constant_degree = false
    };

    DMMSYResult *result = dmmsy_compute(graph, &params);
    assert(result != NULL);

    int64_t idx4 = graph_get_vertex_index(graph, 4);
    assert(double_equal(result->distances[idx4], 0.3));

    dmmsy_result_free(result);
    graph_free(graph);
    PASS();
}

/*
 * Distances must be identical regardless of k and t values.
 * k=1 and k=10 must produce the same shortest-path distances.
 */
void test_k_t_params_produce_same_distances(void) {
    TEST("k_t_params_produce_same_distances");

    /* Build a small random-ish graph */
    Graph *g1 = graph_create(10);
    Graph *g2 = graph_create(10);
    Edge edges[] = {
        {1, 1, 2, 3.0}, {2, 1, 3, 7.0}, {3, 2, 3, 1.0},
        {4, 2, 4, 5.0}, {5, 3, 4, 2.0}, {6, 4, 5, 1.0}
    };
    int ne = 6, i;
    for (i = 0; i < ne; i++) {
        graph_add_edge(g1, &edges[i]);
        graph_add_edge(g2, &edges[i]);
    }

    DMMSYParams p1 = {.source=1, .target=-1, .directed=true,
                      .output_predecessors=true, .max_levels=-1,
                      .param_k=1, .param_t=1, .constant_degree=false};
    DMMSYParams p2 = {.source=1, .target=-1, .directed=true,
                      .output_predecessors=true, .max_levels=-1,
                      .param_k=10, .param_t=5, .constant_degree=false};

    DMMSYResult *r1 = dmmsy_compute(g1, &p1);
    DMMSYResult *r2 = dmmsy_compute(g2, &p2);
    assert(r1 != NULL && r2 != NULL);
    assert(r1->num_vertices == r2->num_vertices);

    for (i = 0; i < (int)r1->num_vertices; i++) {
        if (r1->distances[i] == DBL_MAX && r2->distances[i] == DBL_MAX)
            continue;
        assert(double_equal(r1->distances[i], r2->distances[i]));
    }

    dmmsy_result_free(r1);
    dmmsy_result_free(r2);
    graph_free(g1);
    graph_free(g2);
    PASS();
}

/*
 * Distance monotonicity: agg_cost along any returned path is
 * non-decreasing (each step costs >= 0, so cumulative cost only grows).
 */
void test_distance_monotonicity_along_path(void) {
    TEST("distance_monotonicity_along_path");

    /* Grid-like graph: source at 1, target at 9 */
    Graph *graph = graph_create(20);
    Edge edges[] = {
        {1, 1, 2, 1.0}, {2, 1, 4, 2.0},
        {3, 2, 3, 1.0}, {4, 2, 5, 3.0},
        {5, 3, 6, 1.0},
        {6, 4, 5, 1.0}, {7, 4, 7, 2.0},
        {8, 5, 6, 1.0}, {9, 5, 8, 2.0},
        {10, 6, 9, 1.0},
        {11, 7, 8, 1.0},
        {12, 8, 9, 1.0}
    };
    int ne = 12, i;
    for (i = 0; i < ne; i++) graph_add_edge(graph, &edges[i]);

    DMMSYParams params = {.source=1, .target=9, .directed=true,
                          .output_predecessors=true, .max_levels=-1,
                          .param_k=-1, .param_t=-1, .constant_degree=false};

    DMMSYResult *result = dmmsy_compute(graph, &params);
    assert(result != NULL);

    int path_length;
    PathResult *path = dmmsy_get_path(graph, result, 1, 9, &path_length);
    assert(path != NULL);
    assert(path_length > 0);

    for (i = 1; i < path_length; i++) {
        assert(path[i].agg_cost >= path[i-1].agg_cost - EPSILON);
    }

    free(path);
    dmmsy_result_free(result);
    graph_free(graph);
    PASS();
}

void test_dmmsy_compute_source_not_in_graph(void) {
    TEST("dmmsy_compute_source_not_in_graph");
    Graph *graph = graph_create(5);
    graph_add_vertex(graph, 99);   /* non-empty graph, but no vertex 1 */
    DMMSYParams params = {
        .source = 1,               /* source absent → source_idx < 0 */
        .target = -1,
        .directed = true,
        .output_predecessors = true,
        .max_levels = -1,
        .param_k = -1,
        .param_t = -1,
        .constant_degree = false
    };
    DMMSYResult *result = dmmsy_compute(graph, &params);
    assert(result == NULL);
    graph_free(graph);
    PASS();
}

void test_dmmsy_result_free_null(void) {
    TEST("dmmsy_result_free_null");
    dmmsy_result_free(NULL);   /* must not crash */
    PASS();
}

void test_dmmsy_get_path_null_graph(void) {
    TEST("dmmsy_get_path_null_graph");
    /* Build a real result to pass a non-NULL result */
    Graph *graph = graph_create(5);
    Edge e = {1, 1, 2, 1.0};
    graph_add_edge(graph, &e);
    DMMSYParams params = {.source=1, .target=2, .directed=true,
                          .output_predecessors=true, .max_levels=-1,
                          .param_k=-1, .param_t=-1, .constant_degree=false};
    DMMSYResult *result = dmmsy_compute(graph, &params);
    int path_length;
    PathResult *path = dmmsy_get_path(NULL, result, 1, 2, &path_length);
    assert(path == NULL);
    dmmsy_result_free(result);
    graph_free(graph);
    PASS();
}

void test_dmmsy_get_path_null_result(void) {
    TEST("dmmsy_get_path_null_result");
    Graph *graph = graph_create(5);
    Edge e = {1, 1, 2, 1.0};
    graph_add_edge(graph, &e);
    int path_length;
    PathResult *path = dmmsy_get_path(graph, NULL, 1, 2, &path_length);
    assert(path == NULL);
    graph_free(graph);
    PASS();
}

void test_dmmsy_get_path_target_not_in_graph(void) {
    TEST("dmmsy_get_path_target_not_in_graph");
    Graph *graph = graph_create(5);
    Edge e = {1, 1, 2, 1.0};
    graph_add_edge(graph, &e);
    DMMSYParams params = {.source=1, .target=-1, .directed=true,
                          .output_predecessors=true, .max_levels=-1,
                          .param_k=-1, .param_t=-1, .constant_degree=false};
    DMMSYResult *result = dmmsy_compute(graph, &params);
    int path_length;
    /* vertex 999 was never added → target_idx < 0 → NULL */
    PathResult *path = dmmsy_get_path(graph, result, 1, 999, &path_length);
    assert(path == NULL);
    assert(path_length == 0);
    dmmsy_result_free(result);
    graph_free(graph);
    PASS();
}

/*
 * Covers lines 249 and 255 in dmmsy_algorithm.c (minheap_decrease_key inside
 * STEP A BF): a cheap frontier vertex discovers shorter 2-hop paths to vertices
 * that were already inserted into the heap via expensive direct edges.
 *
 * With k=2, t=1: delta = 3.0*2/4 = 1.5 (phase_upper = 1.5)
 *   BF round 0: 1->3 and 1->4 go to heap (dv >= 1.5)
 *   BF round 1: vertex 2 (in frontier) relaxes:
 *     2->3  total=1.0 < 1.5  -> decrease_key from 3.0 to 1.0  (line 249)
 *     2->4  total=2.5 >= 1.5 -> decrease_key from 3.0 to 2.5  (line 255)
 */
void test_bf_step_a_decrease_key(void) {
    TEST("bf_step_a_decrease_key");

    Graph *graph = graph_create(10);
    Edge e1 = {1, 1, 2, 0.5};
    Edge e2 = {2, 1, 3, 3.0};   /* direct: expensive, goes to heap */
    Edge e3 = {3, 1, 4, 3.0};   /* direct: expensive, goes to heap */
    Edge e4 = {4, 2, 3, 0.5};   /* 2-hop: 1->2->3 total=1.0 < phase_upper */
    Edge e5 = {5, 2, 4, 2.0};   /* 2-hop: 1->2->4 total=2.5 >= phase_upper */

    graph_add_edge(graph, &e1);
    graph_add_edge(graph, &e2);
    graph_add_edge(graph, &e3);
    graph_add_edge(graph, &e4);
    graph_add_edge(graph, &e5);

    DMMSYParams params = {
        .source = 1, .target = -1, .directed = true,
        .output_predecessors = true, .max_levels = -1,
        .param_k = 2, .param_t = 1, .constant_degree = false
    };

    DMMSYResult *result = dmmsy_compute(graph, &params);
    assert(result != NULL);

    int64_t idx3 = graph_get_vertex_index(graph, 3);
    int64_t idx4 = graph_get_vertex_index(graph, 4);

    assert(double_equal(result->distances[idx3], 1.0));   /* via 1->2->3 */
    assert(double_equal(result->distances[idx4], 2.5));   /* via 1->2->4 */

    dmmsy_result_free(result);
    graph_free(graph);
    PASS();
}

int main(void) {
    printf("=== Algorithm Unit Tests ===\n\n");

    test_simple_path();
    test_shortest_path_selection();
    test_disconnected_graph();
    test_source_equals_target();
    test_max_levels();
    test_zero_cost_edges();
    test_custom_parameters();
    test_path_reconstruction();

    /* DMMSY-specific tests */
    test_bellman_ford_rounds_settle_chain();
    test_k_t_params_produce_same_distances();
    test_distance_monotonicity_along_path();

    /* NULL / missing-vertex guards */
    test_dmmsy_compute_source_not_in_graph();
    test_dmmsy_result_free_null();
    test_dmmsy_get_path_null_graph();
    test_dmmsy_get_path_null_result();
    test_dmmsy_get_path_target_not_in_graph();

    /* BF STEP A: minheap_decrease_key coverage (lines 249 and 255) */
    test_bf_step_a_decrease_key();

    printf("\n✅ All algorithm tests passed!\n");
    return 0;
}

