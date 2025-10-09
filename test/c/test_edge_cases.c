/*
 * Edge case tests for DMMSY implementation
 * Note: These are C-level tests without PostgreSQL dependencies
 */

#include <stdio.h>
#include <stdlib.h>
#include <assert.h>
#include <float.h>
#include <math.h>

/* Include only non-PostgreSQL headers */
#include "../../src/graph.h"
/* We'll use structures directly instead of including dmmsy.h which has PG dependencies */

/* Simplified structures for testing (mimics dmmsy.h without PostgreSQL) */
typedef struct {
    int64_t source;
    int64_t target;
    bool directed;
    bool output_predecessors;
    int32_t max_levels;
    int32_t param_k;
    int32_t param_t;
    bool constant_degree;
} DMMSYParams;

typedef struct {
    double *distances;
    int64_t *predecessors;
    int64_t *edge_ids;
    int64_t num_vertices;
    bool *visited;
} DMMSYResult;

typedef struct {
    int seq;
    int path_seq;
    int64_t node;
    int64_t edge;
    double cost;
    double agg_cost;
} PathResult;

/* Forward declarations of functions we'll test */
extern DMMSYResult* dmmsy_compute(Graph *graph, DMMSYParams *params);
extern void dmmsy_result_free(DMMSYResult *result);
extern PathResult* dmmsy_get_path(Graph *graph, DMMSYResult *result, 
                                   int64_t source, int64_t target, int *path_length);

#define TEST(name) printf("Testing %s...\n", name)
#define PASS() printf("  ✓ PASS\n")
#define EPSILON 0.0001

int double_equal(double a, double b) {
    return fabs(a - b) < EPSILON;
}

void test_null_graph(void) {
    TEST("null_graph");
    
    DMMSYParams params = {
        .source = 1,
        .target = 2,
        .directed = true,
        .output_predecessors = true,
        .max_levels = -1,
        .param_k = -1,
        .param_t = -1,
        .constant_degree = false
    };
    
    DMMSYResult *result = dmmsy_compute(NULL, &params);
    assert(result == NULL);
    
    PASS();
}

void test_empty_graph(void) {
    TEST("empty_graph");
    
    Graph *graph = graph_create(10);
    
    DMMSYParams params = {
        .source = 1,
        .target = 2,
        .directed = true,
        .output_predecessors = true,
        .max_levels = -1,
        .param_k = -1,
        .param_t = -1,
        .constant_degree = false
    };
    
    DMMSYResult *result = dmmsy_compute(graph, &params);
    assert(result == NULL);  /* Source not in graph */
    
    graph_free(graph);
    PASS();
}

void test_single_vertex(void) {
    TEST("single_vertex");
    
    Graph *graph = graph_create(10);
    graph_add_vertex(graph, 100);
    
    DMMSYParams params = {
        .source = 100,
        .target = 100,
        .directed = true,
        .output_predecessors = true,
        .max_levels = -1,
        .param_k = -1,
        .param_t = -1,
        .constant_degree = false
    };
    
    DMMSYResult *result = dmmsy_compute(graph, &params);
    assert(result != NULL);
    
    int64_t idx = graph_get_vertex_index(graph, 100);
    assert(double_equal(result->distances[idx], 0.0));
    
    dmmsy_result_free(result);
    graph_free(graph);
    PASS();
}

void test_very_small_costs(void) {
    TEST("very_small_costs");
    
    Graph *graph = graph_create(10);
    Edge e1 = {1, 1, 2, 0.000001};
    Edge e2 = {2, 2, 3, 0.000002};
    Edge e3 = {3, 3, 4, 0.000003};
    
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
    
    assert(result->distances[idx4] > 0.000005);
    assert(result->distances[idx4] < 0.000007);
    
    dmmsy_result_free(result);
    graph_free(graph);
    PASS();
}

void test_very_large_costs(void) {
    TEST("very_large_costs");
    
    Graph *graph = graph_create(10);
    Edge e1 = {1, 1, 2, 1000000.0};
    Edge e2 = {2, 2, 3, 2000000.0};
    
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
    int64_t idx3 = graph_get_vertex_index(graph, 3);
    
    assert(double_equal(result->distances[idx3], 3000000.0));
    
    dmmsy_result_free(result);
    graph_free(graph);
    PASS();
}

void test_many_parallel_edges(void) {
    TEST("many_parallel_edges");
    
    Graph *graph = graph_create(10);
    Edge e1 = {1, 1, 2, 10.0};
    Edge e2 = {2, 1, 2, 5.0};
    Edge e3 = {3, 1, 2, 7.0};
    Edge e4 = {4, 1, 2, 3.0};
    Edge e5 = {5, 2, 3, 1.0};
    
    graph_add_edge(graph, &e1);
    graph_add_edge(graph, &e2);
    graph_add_edge(graph, &e3);
    graph_add_edge(graph, &e4);
    graph_add_edge(graph, &e5);
    
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
    
    /* Should choose cheapest parallel edge (3.0) + 1.0 = 4.0 */
    assert(double_equal(result->distances[idx3], 4.0));
    
    dmmsy_result_free(result);
    graph_free(graph);
    PASS();
}

void test_negative_vertex_ids(void) {
    TEST("negative_vertex_ids");
    
    Graph *graph = graph_create(10);
    Edge e1 = {1, -10, -5, 1.0};
    Edge e2 = {2, -5, 0, 2.0};
    Edge e3 = {3, 0, 10, 3.0};
    
    graph_add_edge(graph, &e1);
    graph_add_edge(graph, &e2);
    graph_add_edge(graph, &e3);
    
    DMMSYParams params = {
        .source = -10,
        .target = 10,
        .directed = true,
        .output_predecessors = true,
        .max_levels = -1,
        .param_k = -1,
        .param_t = -1,
        .constant_degree = false
    };
    
    DMMSYResult *result = dmmsy_compute(graph, &params);
    int64_t idx10 = graph_get_vertex_index(graph, 10);
    
    assert(double_equal(result->distances[idx10], 6.0));
    
    dmmsy_result_free(result);
    graph_free(graph);
    PASS();
}

void test_cycle_detection(void) {
    TEST("cycle_detection");
    
    /* Graph with cycle: 1->2->3->4->2 */
    Graph *graph = graph_create(10);
    Edge e1 = {1, 1, 2, 1.0};
    Edge e2 = {2, 2, 3, 1.0};
    Edge e3 = {3, 3, 4, 1.0};
    Edge e4 = {4, 4, 2, 1.0};  /* Creates cycle */
    Edge e5 = {5, 4, 5, 1.0};
    
    graph_add_edge(graph, &e1);
    graph_add_edge(graph, &e2);
    graph_add_edge(graph, &e3);
    graph_add_edge(graph, &e4);
    graph_add_edge(graph, &e5);
    
    DMMSYParams params = {
        .source = 1,
        .target = 5,
        .directed = true,
        .output_predecessors = true,
        .max_levels = -1,
        .param_k = -1,
        .param_t = -1,
        .constant_degree = false
    };
    
    DMMSYResult *result = dmmsy_compute(graph, &params);
    int64_t idx5 = graph_get_vertex_index(graph, 5);
    
    /* Should find path without infinite loop */
    assert(double_equal(result->distances[idx5], 4.0));
    
    dmmsy_result_free(result);
    graph_free(graph);
    PASS();
}

void test_large_graph(void) {
    TEST("large_graph");
    
    /* Create chain of 100 vertices */
    Graph *graph = graph_create(100);
    
    for (int i = 1; i < 100; i++) {
        Edge e = {i, i, i+1, 1.0};
        graph_add_edge(graph, &e);
    }
    
    DMMSYParams params = {
        .source = 1,
        .target = 100,
        .directed = true,
        .output_predecessors = true,
        .max_levels = -1,
        .param_k = -1,
        .param_t = -1,
        .constant_degree = false
    };
    
    DMMSYResult *result = dmmsy_compute(graph, &params);
    int64_t idx100 = graph_get_vertex_index(graph, 100);
    
    assert(double_equal(result->distances[idx100], 99.0));
    
    int path_length;
    PathResult *path = dmmsy_get_path(graph, result, 1, 100, &path_length);
    assert(path != NULL);
    assert(path_length == 100);
    
    free(path);
    dmmsy_result_free(result);
    graph_free(graph);
    PASS();
}

void test_max_levels_zero(void) {
    TEST("max_levels_zero");
    
    Graph *graph = graph_create(10);
    Edge e1 = {1, 1, 2, 1.0};
    graph_add_edge(graph, &e1);
    
    DMMSYParams params = {
        .source = 1,
        .target = 2,
        .directed = true,
        .output_predecessors = true,
        .max_levels = 0,  /* Process zero vertices */
        .param_k = -1,
        .param_t = -1,
        .constant_degree = false
    };
    
    DMMSYResult *result = dmmsy_compute(graph, &params);
    int path_length;
    PathResult *path = dmmsy_get_path(graph, result, 1, 2, &path_length);
    
    /* Should not find path with max_levels=0 */
    assert(path == NULL);
    
    dmmsy_result_free(result);
    graph_free(graph);
    PASS();
}

void test_multiple_equal_cost_paths(void) {
    TEST("multiple_equal_cost_paths");
    
    /* Diamond with equal costs on both paths */
    Graph *graph = graph_create(10);
    Edge e1 = {1, 1, 2, 5.0};
    Edge e2 = {2, 1, 3, 5.0};
    Edge e3 = {3, 2, 4, 5.0};
    Edge e4 = {4, 3, 4, 5.0};
    
    graph_add_edge(graph, &e1);
    graph_add_edge(graph, &e2);
    graph_add_edge(graph, &e3);
    graph_add_edge(graph, &e4);
    
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
    
    /* Both paths cost 10.0 */
    assert(double_equal(result->distances[idx4], 10.0));
    
    dmmsy_result_free(result);
    graph_free(graph);
    PASS();
}

int main(void) {
    printf("=== Edge Case Unit Tests ===\n\n");
    
    test_null_graph();
    test_empty_graph();
    test_single_vertex();
    test_very_small_costs();
    test_very_large_costs();
    test_many_parallel_edges();
    test_negative_vertex_ids();
    test_cycle_detection();
    test_large_graph();
    test_max_levels_zero();
    test_multiple_equal_cost_paths();
    
    printf("\n✅ All edge case tests passed!\n");
    return 0;
}

