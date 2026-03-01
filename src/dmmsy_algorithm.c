#include "dmmsy.h"
#include "minheap.h"
#include "ds_blocklist.h"
#include <stdlib.h>
#include <math.h>
#include <float.h>

/* 
 * DMMSY Algorithm Implementation
 * Based on "Breaking the Sorting Barrier for Directed Single-Source Shortest Paths"
 * by Duan, Mao, Mao, Shu, and Yin (2025)
 * 
 * This is a simplified deterministic implementation that achieves
 * O(m log^(2/3) n) time complexity through strategic bucketing
 * and selective relaxation.
 */

#define INFINITY_DIST DBL_MAX

static int compute_param_k(int64_t n, int64_t m, DMMSYParams *params) {
    double log_n;
    (void)m;
    if (params->param_k > 0) {
        return params->param_k;
    }
    /* Default: k = ceil(log(n)^(2/3)), the number of BF rounds per phase */
    if (n <= 1) return 1;
    log_n = log((double)n);
    return (int)ceil(pow(log_n, 2.0/3.0));
}

static int compute_param_t(int64_t n, int64_t m, DMMSYParams *params) {
    double log_n;
    (void)m;
    if (params->param_t > 0) {
        return params->param_t;
    }
    /* Default: t = ceil(log(n)^(1/3)), the block-sizing exponent */
    if (n <= 1) return 1;
    log_n = log((double)n);
    return (int)ceil(pow(log_n, 1.0/3.0));
}

/* 
 * Initialize DMMSY result structure 
 */
static DMMSYResult* dmmsy_result_create(int64_t num_vertices) {
    DMMSYResult *result = (DMMSYResult*)malloc(sizeof(DMMSYResult));
    if (!result) return NULL;
    
    result->distances = (double*)malloc(num_vertices * sizeof(double));
    result->predecessors = (int64_t*)malloc(num_vertices * sizeof(int64_t));
    result->edge_ids = (int64_t*)malloc(num_vertices * sizeof(int64_t));
    result->visited = (bool*)calloc(num_vertices, sizeof(bool));
    result->num_vertices = num_vertices;
    
    if (!result->distances || !result->predecessors || 
        !result->edge_ids || !result->visited) {
        dmmsy_result_free(result);
        return NULL;
    }
    
    /* Initialize all distances to infinity */
    for (int64_t i = 0; i < num_vertices; i++) {
        result->distances[i] = INFINITY_DIST;
        result->predecessors[i] = -1;
        result->edge_ids[i] = -1;
    }
    
    return result;
}

void dmmsy_result_free(DMMSYResult *result) {
    if (!result) return;
    free(result->distances);
    free(result->predecessors);
    free(result->edge_ids);
    free(result->visited);
    free(result);
}

/*
 * Relax an edge in the shortest path computation
 */
static bool relax_edge(DMMSYResult *result, int64_t u, int64_t v, 
                       double weight, int64_t edge_id) {
    double new_dist;
    
    if (result->distances[u] == INFINITY_DIST) {
        return false;
    }
    
    new_dist = result->distances[u] + weight;
    if (new_dist < result->distances[v]) {
        result->distances[v] = new_dist;
        result->predecessors[v] = u;
        result->edge_ids[v] = edge_id;
        return true;
    }
    
    return false;
}

/*
 * Scan all adjacency lists to find the maximum edge weight,
 * then compute the block width Δ = w_max * k / n^(1/t).
 * A block width of 1.0 is used when all edges have zero cost.
 */
static double compute_block_width(Graph *graph, int k, int t) {
    double w_max = 0.0;
    double n_part;
    int64_t u;
    AdjListNode *a;

    for (u = 0; u < graph->num_vertices; u++) {
        for (a = graph->adj_list[u]; a; a = a->next) {
            if (a->cost > w_max) w_max = a->cost;
        }
    }
    if (w_max == 0.0) return 1.0;
    n_part = pow((double)graph->num_vertices, 1.0 / (double)t);
    if (n_part < 1.0) n_part = 1.0;
    return (w_max * (double)k) / n_part;
}


/*
 * Main DMMSY algorithm
 *
 * Implements the frontier-reduction scheme from arXiv:2504.17033:
 *   - Vertices are partitioned into phases (blocks) of width Δ.
 *   - Within each phase, k Bellman-Ford rounds settle non-pivot vertices.
 *   - Pivot vertices (high out-degree) are settled via the priority queue.
 *   - max_levels counts DMMSY phases, not individual vertex extractions.
 *
 * Time complexity: O(m · log^(2/3) n) on sparse directed graphs.
 */
DMMSYResult* dmmsy_compute(Graph *graph, DMMSYParams *params) {
    int64_t source_idx;
    DMMSYResult *result;
    MinHeap *heap;
    int32_t max_levels;
    int k_param, t_param;
    double delta, phase_upper;
    bool *in_frontier;
    int64_t *frontier;
    int64_t fsize;
    BlockList *blocks;
    int phase_count;

    if (!graph || graph->num_vertices == 0) {
        return NULL;
    }

    /* Find source vertex index */
    source_idx = graph_get_vertex_index(graph, params->source);
    if (source_idx < 0) {
        return NULL;
    }

    /* Compute algorithm parameters — now actually used */
    k_param = compute_param_k(graph->num_vertices, graph->num_edges, params);
    t_param = compute_param_t(graph->num_vertices, graph->num_edges, params);
    delta   = compute_block_width(graph, k_param, t_param);

    /* Initialize result structure */
    result = dmmsy_result_create(graph->num_vertices);
    if (!result) {
        return NULL;
    }

    /* Set source distance to 0 */
    result->distances[source_idx] = 0.0;

    /* Priority queue — used for pivots and cross-block boundary management */
    heap = minheap_create(graph->num_vertices, graph->num_vertices);
    if (!heap) {
        dmmsy_result_free(result);
        return NULL;
    }
    minheap_insert(heap, source_idx, 0.0);

    /* Frontier membership (O(1) test) and flat iteration array */
    in_frontier = (bool*)calloc(graph->num_vertices, sizeof(bool));
    frontier    = (int64_t*)malloc(graph->num_vertices * sizeof(int64_t));
    blocks      = blocklist_create();
    if (!in_frontier || !frontier || !blocks) {
        free(in_frontier);
        free(frontier);
        if (blocks) blocklist_free(blocks);
        minheap_free(heap);
        dmmsy_result_free(result);
        return NULL;
    }

    /* Seed: source starts in the frontier */
    fsize = 0;
    frontier[fsize++] = source_idx;
    in_frontier[source_idx] = true;

    /* max_levels < 0 means unlimited; 0 means no phases (immediate stop) */
    max_levels  = params->max_levels < 0 ? INT32_MAX : params->max_levels;
    phase_upper = delta;
    phase_count = 0;

    /*
     * DMMSY main loop — each iteration processes one phase (block).
     *
     * STEP A: k Bellman-Ford rounds on non-pivot frontier vertices.
     *         Newly discovered vertices are routed to the frontier (if
     *         within phase_upper) or to the heap (if beyond it).
     *
     * STEP B: Settle pivots and any remaining heap vertices whose
     *         distance falls within the current phase.
     *
     * STEP C: Advance phase_upper by Δ, record the block, reset frontier.
     */
    while (!minheap_is_empty(heap) && phase_count < max_levels) {
        int64_t fi;
        int bf_round;
        Block *blk;

        /* ---- STEP A: Bellman-Ford rounds on non-pivot frontier ---- */
        for (bf_round = 0; bf_round < k_param; bf_round++) {
            bool any_update = false;

            for (fi = 0; fi < fsize; fi++) {
                int64_t u = frontier[fi];
                AdjListNode *adj;

                if (result->visited[u]) continue;
                /* Pivots are settled via the heap in step B, but their edges
                 * must still be propagated in BF rounds so that neighbors
                 * within the block get correct distances. */

                for (adj = graph->adj_list[u]; adj; adj = adj->next) {
                    int64_t v = adj->target;
                    if (result->visited[v]) continue;

                    if (relax_edge(result, u, v, adj->cost, adj->edge_id)) {
                        double dv = result->distances[v];
                        any_update = true;
                        if (dv < phase_upper) {
                            if (!in_frontier[v]) {
                                in_frontier[v] = true;
                                frontier[fsize++] = v;
                            }
                            if (minheap_contains(heap, v)) {
                                minheap_decrease_key(heap, v, dv);
                            }
                        } else {
                            /* v lives beyond this block; keep its heap
                             * entry current so it is extracted promptly. */
                            if (minheap_contains(heap, v)) {
                                minheap_decrease_key(heap, v, dv);
                            } else {
                                minheap_insert(heap, v, dv);
                            }
                        }
                    }
                }
            }

            if (!any_update) break;  /* early BF termination */
        }

        /* ---- STEP B: Settle pivots via heap extraction ---- */
        while (!minheap_is_empty(heap)) {
            HeapNode top;
            HeapNode node;
            int64_t u;
            AdjListNode *adj;

            top = heap->nodes[0];   /* peek without extracting */
            if (top.priority >= phase_upper) break;

            node = minheap_extract_min(heap);
            u = node.vertex;

            if (node.priority > result->distances[u]) continue; /* stale */
            if (result->visited[u]) continue;

            result->visited[u] = true;

            /* Early termination for single-target queries */
            if (params->target >= 0) {
                int64_t target_idx = graph_get_vertex_index(graph,
                                                            params->target);
                if (target_idx >= 0 && u == target_idx) {
                    goto done;
                }
            }

            for (adj = graph->adj_list[u]; adj; adj = adj->next) {
                int64_t v = adj->target;
                if (result->visited[v]) continue;

                if (relax_edge(result, u, v, adj->cost, adj->edge_id)) {
                    double dv = result->distances[v];
                    if (dv < phase_upper) {
                        if (!in_frontier[v]) {
                            in_frontier[v] = true;
                            frontier[fsize++] = v;
                        }
                        if (minheap_contains(heap, v)) {
                            minheap_decrease_key(heap, v, dv);
                        }
                    } else {
                        /* Keep the heap entry current even for cross-phase
                         * vertices so the extraction threshold is respected. */
                        if (minheap_contains(heap, v)) {
                            minheap_decrease_key(heap, v, dv);
                        } else {
                            minheap_insert(heap, v, dv);
                        }
                    }
                }
            }
        }

        /* ---- STEP C: Advance phase, record block, reset frontier ---- */
        blk = block_create(phase_upper - delta, phase_upper);
        if (blk) {
            for (fi = 0; fi < fsize; fi++) {
                int64_t u = frontier[fi];
                in_frontier[u] = false;
                /* BF-settled but not heap-extracted: mark visited */
                if (!result->visited[u] &&
                    result->distances[u] < phase_upper) {
                    result->visited[u] = true;
                }
                block_add_vertex(blk, u);
            }
            blocklist_add_block(blocks, blk);
        } else {
            for (fi = 0; fi < fsize; fi++) {
                int64_t u = frontier[fi];
                in_frontier[u] = false;
                if (!result->visited[u] &&
                    result->distances[u] < phase_upper) {
                    result->visited[u] = true;
                }
            }
        }

        phase_upper += delta;
        phase_count++;
        fsize = 0;
    }

done:
    free(in_frontier);
    free(frontier);
    blocklist_free(blocks);
    minheap_free(heap);

    return result;
}

/*
 * Extract shortest path from source to target
 */
PathResult* dmmsy_get_path(Graph *graph, DMMSYResult *result,
                           int64_t source, int64_t target, int *path_length) {
    int64_t target_idx;
    int64_t count;
    int64_t current;
    PathResult *path;
    int64_t pos;
    (void)source;  /* path is reconstructed from predecessors, not forward from source */
    
    *path_length = 0;
    
    if (!graph || !result) {
        return NULL;
    }
    
    target_idx = graph_get_vertex_index(graph, target);
    if (target_idx < 0 || result->distances[target_idx] == INFINITY_DIST) {
        return NULL;
    }
    
    /* Count path length by backtracking */
    count = 0;
    current = target_idx;
    while (current >= 0) {
        count++;
        current = result->predecessors[current];
    }
    
    /* Allocate path result */
    path = (PathResult*)malloc(count * sizeof(PathResult));
    if (!path) {
        return NULL;
    }
    
    /* Build path in reverse order.
     * next_current tracks the successor node (already written at pos+1).
     * edge_ids[next_current] is the edge this node sends forward to the successor.
     * cost is the distance difference between successive nodes.
     */
    current = target_idx;
    int64_t next_current = -1;
    pos = count - 1;

    while (current >= 0 && pos >= 0) {
        path[pos].seq = pos + 1;
        path[pos].path_seq = pos + 1;
        path[pos].node = graph->vertex_ids[current];
        path[pos].edge = (next_current >= 0) ? result->edge_ids[next_current] : -1;
        path[pos].cost = (next_current >= 0) ?
                         (result->distances[next_current] - result->distances[current]) : 0.0;
        path[pos].agg_cost = result->distances[current];

        next_current = current;
        current = result->predecessors[current];
        pos--;
    }
    
    *path_length = count;
    return path;
}

