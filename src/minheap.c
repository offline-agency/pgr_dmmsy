#include "minheap.h"
#include <stdlib.h>
#include <string.h>

static void swap_nodes(MinHeap *heap, int64_t i, int64_t j) {
    HeapNode tmp = heap->nodes[i];
    heap->nodes[i] = heap->nodes[j];
    heap->nodes[j] = tmp;
    
    heap->positions[heap->nodes[i].vertex] = i;
    heap->positions[heap->nodes[j].vertex] = j;
}

static void heapify_up(MinHeap *heap, int64_t idx) {
    while (idx > 0) {
        int64_t parent = (idx - 1) / 2;
        if (heap->nodes[parent].priority <= heap->nodes[idx].priority) {
            break;
        }
        swap_nodes(heap, parent, idx);
        idx = parent;
    }
}

static void heapify_down(MinHeap *heap, int64_t idx) {
    while (true) {
        int64_t smallest = idx;
        int64_t left = 2 * idx + 1;
        int64_t right = 2 * idx + 2;
        
        if (left < heap->size && heap->nodes[left].priority < heap->nodes[smallest].priority) {
            smallest = left;
        }
        if (right < heap->size && heap->nodes[right].priority < heap->nodes[smallest].priority) {
            smallest = right;
        }
        
        if (smallest == idx) {
            break;
        }
        
        swap_nodes(heap, idx, smallest);
        idx = smallest;
    }
}

MinHeap* minheap_create(int64_t capacity, int64_t max_vertex) {
    MinHeap *heap = (MinHeap*)malloc(sizeof(MinHeap));
    if (!heap) return NULL;
    
    heap->nodes = (HeapNode*)malloc(capacity * sizeof(HeapNode));
    heap->positions = (int64_t*)malloc((max_vertex + 1) * sizeof(int64_t));
    
    if (!heap->nodes || !heap->positions) {
        free(heap->nodes);
        free(heap->positions);
        free(heap);
        return NULL;
    }
    
    heap->size = 0;
    heap->capacity = capacity;
    heap->max_vertex = max_vertex;
    
    for (int64_t i = 0; i <= max_vertex; i++) {
        heap->positions[i] = -1;
    }
    
    return heap;
}

void minheap_free(MinHeap *heap) {
    if (!heap) return;
    free(heap->nodes);
    free(heap->positions);
    free(heap);
}

bool minheap_is_empty(MinHeap *heap) {
    return heap->size == 0;
}

void minheap_insert(MinHeap *heap, int64_t vertex, double priority) {
    int64_t idx;
    
    if (heap->size >= heap->capacity || vertex > heap->max_vertex) {
        return;
    }
    
    idx = heap->size;
    heap->nodes[idx].vertex = vertex;
    heap->nodes[idx].priority = priority;
    heap->positions[vertex] = idx;
    heap->size++;
    
    heapify_up(heap, idx);
}

HeapNode minheap_extract_min(MinHeap *heap) {
    HeapNode min_node = heap->nodes[0];
    heap->positions[min_node.vertex] = -1;
    
    heap->size--;
    if (heap->size > 0) {
        heap->nodes[0] = heap->nodes[heap->size];
        heap->positions[heap->nodes[0].vertex] = 0;
        heapify_down(heap, 0);
    }
    
    return min_node;
}

void minheap_decrease_key(MinHeap *heap, int64_t vertex, double new_priority) {
    int64_t idx;
    
    if (vertex > heap->max_vertex) return;
    
    idx = heap->positions[vertex];
    if (idx < 0) return;
    
    heap->nodes[idx].priority = new_priority;
    heapify_up(heap, idx);
}

bool minheap_contains(MinHeap *heap, int64_t vertex) {
    if (vertex > heap->max_vertex) return false;
    return heap->positions[vertex] >= 0;
}

