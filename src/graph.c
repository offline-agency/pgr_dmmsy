#include "graph.h"
#include <stdlib.h>
#include <string.h>

Graph* graph_create(int64_t initial_capacity) {
    Graph *graph = (Graph*)malloc(sizeof(Graph));
    if (!graph) return NULL;
    
    graph->num_vertices = 0;
    graph->num_edges = 0;
    graph->vertex_capacity = initial_capacity > 0 ? initial_capacity : 100;
    
    graph->adj_list = (AdjListNode**)calloc(graph->vertex_capacity, sizeof(AdjListNode*));
    graph->vertex_ids = (int64_t*)malloc(graph->vertex_capacity * sizeof(int64_t));
    
    if (!graph->adj_list || !graph->vertex_ids) {
        free(graph->adj_list);
        free(graph->vertex_ids);
        free(graph);
        return NULL;
    }
    
    return graph;
}

void graph_free(Graph *graph) {
    if (!graph) return;
    
    for (int64_t i = 0; i < graph->num_vertices; i++) {
        AdjListNode *node = graph->adj_list[i];
        while (node) {
            AdjListNode *tmp = node;
            node = node->next;
            free(tmp);
        }
    }
    
    free(graph->adj_list);
    free(graph->vertex_ids);
    free(graph);
}

int64_t graph_get_vertex_index(Graph *graph, int64_t vertex_id) {
    for (int64_t i = 0; i < graph->num_vertices; i++) {
        if (graph->vertex_ids[i] == vertex_id) {
            return i;
        }
    }
    return -1;
}

int64_t graph_add_vertex(Graph *graph, int64_t vertex_id) {
    int64_t idx = graph_get_vertex_index(graph, vertex_id);
    if (idx >= 0) {
        return idx;
    }
    
    if (graph->num_vertices >= graph->vertex_capacity) {
        int64_t new_capacity = graph->vertex_capacity * 2;
        AdjListNode **new_adj_list = (AdjListNode**)realloc(graph->adj_list, 
                                                             new_capacity * sizeof(AdjListNode*));
        int64_t *new_vertex_ids = (int64_t*)realloc(graph->vertex_ids, 
                                                     new_capacity * sizeof(int64_t));
        
        if (!new_adj_list || !new_vertex_ids) {
            return -1;
        }
        
        memset(new_adj_list + graph->vertex_capacity, 0, 
               (new_capacity - graph->vertex_capacity) * sizeof(AdjListNode*));
        
        graph->adj_list = new_adj_list;
        graph->vertex_ids = new_vertex_ids;
        graph->vertex_capacity = new_capacity;
    }
    
    idx = graph->num_vertices;
    graph->vertex_ids[idx] = vertex_id;
    graph->adj_list[idx] = NULL;
    graph->num_vertices++;
    
    return idx;
}

void graph_add_edge(Graph *graph, Edge *edge) {
    int64_t src_idx = graph_add_vertex(graph, edge->source);
    int64_t tgt_idx = graph_add_vertex(graph, edge->target);
    AdjListNode *new_node;
    
    if (src_idx < 0 || tgt_idx < 0) return;
    
    new_node = (AdjListNode*)malloc(sizeof(AdjListNode));
    if (!new_node) return;
    
    new_node->target = tgt_idx;
    new_node->edge_id = edge->id;
    new_node->cost = edge->cost;
    new_node->next = graph->adj_list[src_idx];
    graph->adj_list[src_idx] = new_node;
    graph->num_edges++;
}

void graph_add_reverse_edge(Graph *graph, Edge *edge) {
    Edge reverse = {
        .id = edge->id,
        .source = edge->target,
        .target = edge->source,
        .cost = edge->cost
    };
    graph_add_edge(graph, &reverse);
}

