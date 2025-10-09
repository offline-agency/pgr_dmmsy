/*
 * Unit tests for dmmsy_algorithm.c
 */

#include <stdio.h>
#include <stdlib.h>
#include <assert.h>
#include <math.h>
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
    
    printf("\n✅ All algorithm tests passed!\n");
    return 0;
}

