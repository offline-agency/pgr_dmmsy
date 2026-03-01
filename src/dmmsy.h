#ifndef DMMSY_H
#define DMMSY_H

/* PostgreSQL headers are only available in the extension build context.
 * When compiling standalone unit tests, define NO_PG_HEADERS to skip them. */
#ifndef NO_PG_HEADERS
#include "postgres.h"
#include "fmgr.h"
#endif

#include "graph.h"
#include <stdbool.h>

/* DMMSY algorithm parameters */
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

/* DMMSY result structure */
typedef struct {
    double *distances;
    int64_t *predecessors;
    int64_t *edge_ids;
    int64_t num_vertices;
    bool *visited;
} DMMSYResult;

/* Path result structure for output */
typedef struct {
    int seq;
    int path_seq;
    int64_t node;
    int64_t edge;
    double cost;
    double agg_cost;
} PathResult;

/* Function declarations */
DMMSYResult* dmmsy_compute(Graph *graph, DMMSYParams *params);
void dmmsy_result_free(DMMSYResult *result);
PathResult* dmmsy_get_path(Graph *graph, DMMSYResult *result, 
                           int64_t source, int64_t target, int *path_length);

#endif /* DMMSY_H */

