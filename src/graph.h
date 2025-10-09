#ifndef GRAPH_H
#define GRAPH_H

#include <stdint.h>
#include <stdbool.h>

/* Edge structure */
typedef struct {
    int64_t id;
    int64_t source;
    int64_t target;
    double cost;
} Edge;

/* Graph node adjacency list entry */
typedef struct AdjListNode {
    int64_t target;
    int64_t edge_id;
    double cost;
    struct AdjListNode *next;
} AdjListNode;

/* Graph structure */
typedef struct {
    int64_t num_vertices;
    int64_t num_edges;
    AdjListNode **adj_list;
    int64_t *vertex_ids;  /* Mapping from index to actual vertex ID */
    int64_t vertex_capacity;
} Graph;

/* Function declarations */
Graph* graph_create(int64_t initial_capacity);
void graph_free(Graph *graph);
int64_t graph_add_vertex(Graph *graph, int64_t vertex_id);
int64_t graph_get_vertex_index(Graph *graph, int64_t vertex_id);
void graph_add_edge(Graph *graph, Edge *edge);
void graph_add_reverse_edge(Graph *graph, Edge *edge);

#endif /* GRAPH_H */

