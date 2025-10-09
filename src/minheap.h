#ifndef MINHEAP_H
#define MINHEAP_H

#include <stdint.h>
#include <stdbool.h>

/* Heap node structure */
typedef struct {
    int64_t vertex;
    double priority;
} HeapNode;

/* Min heap structure */
typedef struct {
    HeapNode *nodes;
    int64_t *positions;  /* positions[vertex] = index in heap (-1 if not in heap) */
    int64_t size;
    int64_t capacity;
    int64_t max_vertex;
} MinHeap;

/* Function declarations */
MinHeap* minheap_create(int64_t capacity, int64_t max_vertex);
void minheap_free(MinHeap *heap);
bool minheap_is_empty(MinHeap *heap);
void minheap_insert(MinHeap *heap, int64_t vertex, double priority);
HeapNode minheap_extract_min(MinHeap *heap);
void minheap_decrease_key(MinHeap *heap, int64_t vertex, double new_priority);
bool minheap_contains(MinHeap *heap, int64_t vertex);

#endif /* MINHEAP_H */

