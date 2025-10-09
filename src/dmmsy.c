#include "postgres.h"
#include "fmgr.h"
#include "funcapi.h"
#include "catalog/pg_type.h"
#include "utils/builtins.h"
#include "executor/spi.h"

#include "dmmsy.h"
#include "graph.h"

#ifdef PG_MODULE_MAGIC
PG_MODULE_MAGIC;
#endif

/* SQL function declaration */
PG_FUNCTION_INFO_V1(pgr_dmmsy_c);

/*
 * Structure to hold the context for SRF (Set Returning Function)
 */
typedef struct {
    PathResult *path;
    int path_length;
    int current_index;
} DMMSYContext;

/*
 * Parse edge data from SQL result
 */
static Edge* parse_edges(SPITupleTable *tuptable, int ntuples, int *num_edges) {
    Edge *edges = (Edge*)malloc(ntuples * sizeof(Edge));
    int i;
    
    if (!edges) {
        ereport(ERROR, (errcode(ERRCODE_OUT_OF_MEMORY),
                errmsg("Out of memory allocating edges")));
        return NULL;
    }
    
    for (i = 0; i < ntuples; i++) {
        HeapTuple tuple = tuptable->vals[i];
        TupleDesc tupdesc = tuptable->tupdesc;
        bool isnull;
        Datum id_datum, source_datum, target_datum, cost_datum;
        
        /* Get id column */
        id_datum = SPI_getbinval(tuple, tupdesc, 1, &isnull);
        if (isnull) {
            ereport(ERROR, (errcode(ERRCODE_NULL_VALUE_NOT_ALLOWED),
                    errmsg("Edge id cannot be NULL")));
        }
        edges[i].id = DatumGetInt64(id_datum);
        
        /* Get source column */
        source_datum = SPI_getbinval(tuple, tupdesc, 2, &isnull);
        if (isnull) {
            ereport(ERROR, (errcode(ERRCODE_NULL_VALUE_NOT_ALLOWED),
                    errmsg("Edge source cannot be NULL")));
        }
        edges[i].source = DatumGetInt64(source_datum);
        
        /* Get target column */
        target_datum = SPI_getbinval(tuple, tupdesc, 3, &isnull);
        if (isnull) {
            ereport(ERROR, (errcode(ERRCODE_NULL_VALUE_NOT_ALLOWED),
                    errmsg("Edge target cannot be NULL")));
        }
        edges[i].target = DatumGetInt64(target_datum);
        
        /* Get cost column */
        cost_datum = SPI_getbinval(tuple, tupdesc, 4, &isnull);
        if (isnull) {
            ereport(ERROR, (errcode(ERRCODE_NULL_VALUE_NOT_ALLOWED),
                    errmsg("Edge cost cannot be NULL")));
        }
        edges[i].cost = DatumGetFloat8(cost_datum);
        
        /* Validate non-negative cost */
        if (edges[i].cost < 0) {
            ereport(ERROR, (errcode(ERRCODE_INVALID_PARAMETER_VALUE),
                    errmsg("Edge cost must be non-negative")));
        }
    }
    
    *num_edges = ntuples;
    return edges;
}

/*
 * Build graph from edge array
 */
static Graph* build_graph_from_edges(Edge *edges, int num_edges, bool directed) {
    Graph *graph = graph_create(num_edges);
    int i;
    
    if (!graph) {
        ereport(ERROR, (errcode(ERRCODE_OUT_OF_MEMORY),
                errmsg("Out of memory creating graph")));
        return NULL;
    }
    
    for (i = 0; i < num_edges; i++) {
        graph_add_edge(graph, &edges[i]);
        
        if (!directed) {
            graph_add_reverse_edge(graph, &edges[i]);
        }
    }
    
    return graph;
}

/*
 * Main PostgreSQL function implementation
 */
Datum pgr_dmmsy_c(PG_FUNCTION_ARGS) {
    FuncCallContext *funcctx;
    DMMSYContext *user_ctx;
    
    /* First-time setup */
    if (SRF_IS_FIRSTCALL()) {
        MemoryContext oldcontext;
        text *edges_sql_text;
        char *edges_sql;
        int64_t source;
        int64_t target = -1;
        bool directed = true;
        bool output_predecessors = true;
        int32_t max_levels = -1;
        int32_t param_k = -1;
        int32_t param_t = -1;
        bool constant_degree = false;
        int ret, num_edges;
        Edge *edges;
        Graph *graph;
        DMMSYParams params;
        DMMSYResult *result;
        PathResult *path = NULL;
        int path_length = 0;
        TupleDesc tupdesc;
        
        funcctx = SRF_FIRSTCALL_INIT();
        oldcontext = MemoryContextSwitchTo(funcctx->multi_call_memory_ctx);
        
        /* Get function arguments */
        edges_sql_text = PG_GETARG_TEXT_P(0);
        edges_sql = text_to_cstring(edges_sql_text);
        source = PG_GETARG_INT64(1);
        
        if (PG_NARGS() > 2 && !PG_ARGISNULL(2)) {
            target = PG_GETARG_INT64(2);
        }
        if (PG_NARGS() > 3 && !PG_ARGISNULL(3)) {
            directed = PG_GETARG_BOOL(3);
        }
        if (PG_NARGS() > 4 && !PG_ARGISNULL(4)) {
            output_predecessors = PG_GETARG_BOOL(4);
        }
        if (PG_NARGS() > 5 && !PG_ARGISNULL(5)) {
            max_levels = PG_GETARG_INT32(5);
        }
        if (PG_NARGS() > 6 && !PG_ARGISNULL(6)) {
            param_k = PG_GETARG_INT32(6);
        }
        if (PG_NARGS() > 7 && !PG_ARGISNULL(7)) {
            param_t = PG_GETARG_INT32(7);
        }
        if (PG_NARGS() > 8 && !PG_ARGISNULL(8)) {
            constant_degree = PG_GETARG_BOOL(8);
        }
        
        /* Connect to SPI */
        if (SPI_connect() != SPI_OK_CONNECT) {
            ereport(ERROR, (errcode(ERRCODE_INTERNAL_ERROR),
                    errmsg("Could not connect to SPI manager")));
        }
        
        /* Execute edge query */
        ret = SPI_execute(edges_sql, true, 0);
        if (ret != SPI_OK_SELECT) {
            SPI_finish();
            ereport(ERROR, (errcode(ERRCODE_INTERNAL_ERROR),
                    errmsg("Edge query failed")));
        }
        
        /* Parse edges from result */
        edges = parse_edges(SPI_tuptable, SPI_processed, &num_edges);
        
        /* Build graph */
        graph = build_graph_from_edges(edges, num_edges, directed);
        
        /* Set up DMMSY parameters */
        params.source = source;
        params.target = target;
        params.directed = directed;
        params.output_predecessors = output_predecessors;
        params.max_levels = max_levels;
        params.param_k = param_k;
        params.param_t = param_t;
        params.constant_degree = constant_degree;
        
        /* Run DMMSY algorithm */
        result = dmmsy_compute(graph, &params);
        
        if (!result) {
            graph_free(graph);
            free(edges);
            SPI_finish();
            ereport(ERROR, (errcode(ERRCODE_INTERNAL_ERROR),
                    errmsg("DMMSY algorithm failed")));
        }
        
        /* Get path if target specified */
        if (target >= 0) {
            path = dmmsy_get_path(graph, result, source, target, &path_length);
        }
        
        /* Clean up */
        dmmsy_result_free(result);
        graph_free(graph);
        free(edges);
        SPI_finish();
        
        /* Set up user context */
        user_ctx = (DMMSYContext*)palloc(sizeof(DMMSYContext));
        user_ctx->path = path;
        user_ctx->path_length = path_length;
        user_ctx->current_index = 0;
        
        funcctx->user_fctx = user_ctx;
        funcctx->max_calls = path_length;
        
        /* Build tuple descriptor */
        if (get_call_result_type(fcinfo, NULL, &tupdesc) != TYPEFUNC_COMPOSITE) {
            ereport(ERROR, (errcode(ERRCODE_FEATURE_NOT_SUPPORTED),
                    errmsg("Function returning record called in context that cannot accept type record")));
        }
        
        funcctx->tuple_desc = BlessTupleDesc(tupdesc);
        
        MemoryContextSwitchTo(oldcontext);
    }
    
    /* Per-call setup */
    funcctx = SRF_PERCALL_SETUP();
    user_ctx = (DMMSYContext*)funcctx->user_fctx;
    
    if (user_ctx->current_index < user_ctx->path_length) {
        Datum values[6];
        bool nulls[6] = {false, false, false, false, false, false};
        HeapTuple tuple;
        Datum result;
        
        PathResult *current = &user_ctx->path[user_ctx->current_index];
        
        values[0] = Int32GetDatum(current->seq);
        values[1] = Int32GetDatum(current->path_seq);
        values[2] = Int64GetDatum(current->node);
        values[3] = Int64GetDatum(current->edge);
        values[4] = Float8GetDatum(current->cost);
        values[5] = Float8GetDatum(current->agg_cost);
        
        tuple = heap_form_tuple(funcctx->tuple_desc, values, nulls);
        result = HeapTupleGetDatum(tuple);
        
        user_ctx->current_index++;
        
        SRF_RETURN_NEXT(funcctx, result);
    } else {
        /* Clean up */
        if (user_ctx->path) {
            free(user_ctx->path);
        }
        
        SRF_RETURN_DONE(funcctx);
    }
}

