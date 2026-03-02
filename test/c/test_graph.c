/*
 * Unit tests for graph.c
 */

#include <stdio.h>
#include <stdlib.h>
#include <assert.h>
#include <string.h>
#include "../../src/graph.h"

#define TEST(name) printf("Testing %s...\n", name)
#define PASS() printf("  ✓ PASS\n")
#define FAIL(msg) do { printf("  ✗ FAIL: %s\n", msg); exit(1); } while(0)

void test_graph_create(void) {
    TEST("graph_create");
    
    Graph *graph = graph_create(10);
    assert(graph != NULL);
    assert(graph->num_vertices == 0);
    assert(graph->num_edges == 0);
    assert(graph->vertex_capacity >= 10);
    
    graph_free(graph);
    PASS();
}

void test_graph_add_vertex(void) {
    TEST("graph_add_vertex");
    
    Graph *graph = graph_create(5);
    
    /* Add first vertex */
    int64_t idx1 = graph_add_vertex(graph, 100);
    assert(idx1 == 0);
    assert(graph->num_vertices == 1);
    assert(graph->vertex_ids[0] == 100);
    
    /* Add second vertex */
    int64_t idx2 = graph_add_vertex(graph, 200);
    assert(idx2 == 1);
    assert(graph->num_vertices == 2);
    assert(graph->vertex_ids[1] == 200);
    
    /* Add duplicate vertex (should return existing index) */
    int64_t idx3 = graph_add_vertex(graph, 100);
    assert(idx3 == 0);
    assert(graph->num_vertices == 2);
    
    graph_free(graph);
    PASS();
}

void test_graph_get_vertex_index(void) {
    TEST("graph_get_vertex_index");
    
    Graph *graph = graph_create(5);
    
    graph_add_vertex(graph, 10);
    graph_add_vertex(graph, 20);
    graph_add_vertex(graph, 30);
    
    assert(graph_get_vertex_index(graph, 10) == 0);
    assert(graph_get_vertex_index(graph, 20) == 1);
    assert(graph_get_vertex_index(graph, 30) == 2);
    assert(graph_get_vertex_index(graph, 999) == -1);
    
    graph_free(graph);
    PASS();
}

void test_graph_add_edge(void) {
    TEST("graph_add_edge");
    
    Graph *graph = graph_create(5);
    
    Edge edge1 = {1, 10, 20, 5.0};
    graph_add_edge(graph, &edge1);
    
    assert(graph->num_vertices == 2);
    assert(graph->num_edges == 1);
    
    int64_t idx = graph_get_vertex_index(graph, 10);
    assert(idx >= 0);
    assert(graph->adj_list[idx] != NULL);
    assert(graph->adj_list[idx]->cost == 5.0);
    
    graph_free(graph);
    PASS();
}

void test_graph_capacity_expansion(void) {
    TEST("graph_capacity_expansion");
    
    Graph *graph = graph_create(2);
    int64_t initial_capacity = graph->vertex_capacity;
    
    /* Add more vertices than initial capacity */
    for (int i = 0; i < 10; i++) {
        graph_add_vertex(graph, i * 100);
    }
    
    assert(graph->num_vertices == 10);
    assert(graph->vertex_capacity > initial_capacity);
    
    graph_free(graph);
    PASS();
}

void test_graph_multiple_edges(void) {
    TEST("graph_multiple_edges");
    
    Graph *graph = graph_create(5);
    
    Edge edge1 = {1, 1, 2, 1.0};
    Edge edge2 = {2, 1, 3, 2.0};
    Edge edge3 = {3, 2, 3, 3.0};
    
    graph_add_edge(graph, &edge1);
    graph_add_edge(graph, &edge2);
    graph_add_edge(graph, &edge3);
    
    assert(graph->num_edges == 3);
    
    /* Check vertex 1 has 2 outgoing edges */
    int64_t idx = graph_get_vertex_index(graph, 1);
    AdjListNode *node = graph->adj_list[idx];
    int count = 0;
    while (node) {
        count++;
        node = node->next;
    }
    assert(count == 2);
    
    graph_free(graph);
    PASS();
}

void test_graph_reverse_edge(void) {
    TEST("graph_add_reverse_edge");
    
    Graph *graph = graph_create(5);
    
    Edge edge = {1, 10, 20, 5.0};
    graph_add_edge(graph, &edge);
    graph_add_reverse_edge(graph, &edge);
    
    assert(graph->num_edges == 2);
    
    /* Check both directions exist */
    int64_t idx1 = graph_get_vertex_index(graph, 10);
    int64_t idx2 = graph_get_vertex_index(graph, 20);
    
    assert(graph->adj_list[idx1] != NULL);
    assert(graph->adj_list[idx2] != NULL);
    
    graph_free(graph);
    PASS();
}

void test_graph_large_vertex_ids(void) {
    TEST("graph_large_vertex_ids");
    
    Graph *graph = graph_create(5);
    
    graph_add_vertex(graph, 1000000);
    graph_add_vertex(graph, 2000000);
    
    assert(graph_get_vertex_index(graph, 1000000) == 0);
    assert(graph_get_vertex_index(graph, 2000000) == 1);
    
    Edge edge = {1, 1000000, 2000000, 10.5};
    graph_add_edge(graph, &edge);
    
    assert(graph->num_edges == 1);
    
    graph_free(graph);
    PASS();
}

void test_graph_free_null(void) {
    TEST("graph_free_null");
    graph_free(NULL);   /* must not crash */
    PASS();
}

void test_graph_create_zero_capacity(void) {
    TEST("graph_create_zero_capacity");
    Graph *graph = graph_create(0);  /* triggers the ternary else → cap = 100 */
    assert(graph != NULL);
    assert(graph->vertex_capacity == 100);
    graph_free(graph);
    PASS();
}

int main(void) {
    printf("=== Graph Unit Tests ===\n\n");

    test_graph_create();
    test_graph_add_vertex();
    test_graph_get_vertex_index();
    test_graph_add_edge();
    test_graph_capacity_expansion();
    test_graph_multiple_edges();
    test_graph_reverse_edge();
    test_graph_large_vertex_ids();
    test_graph_free_null();
    test_graph_create_zero_capacity();

    printf("\n✅ All graph tests passed!\n");
    return 0;
}

