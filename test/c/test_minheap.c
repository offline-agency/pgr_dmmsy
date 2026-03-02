/*
 * Unit tests for minheap.c
 */

#include <stdio.h>
#include <stdlib.h>
#include <assert.h>
#include "../../src/minheap.h"

#define TEST(name) printf("Testing %s...\n", name)
#define PASS() printf("  ✓ PASS\n")
#define FAIL(msg) do { printf("  ✗ FAIL: %s\n", msg); exit(1); } while(0)

void test_minheap_create(void) {
    TEST("minheap_create");
    
    MinHeap *heap = minheap_create(10, 100);
    assert(heap != NULL);
    assert(heap->size == 0);
    assert(heap->capacity == 10);
    assert(heap->max_vertex == 100);
    assert(minheap_is_empty(heap));
    
    minheap_free(heap);
    PASS();
}

void test_minheap_insert_extract(void) {
    TEST("minheap_insert_extract");
    
    MinHeap *heap = minheap_create(10, 100);
    
    minheap_insert(heap, 1, 10.0);
    minheap_insert(heap, 2, 5.0);
    minheap_insert(heap, 3, 15.0);
    
    assert(heap->size == 3);
    assert(!minheap_is_empty(heap));
    
    HeapNode min1 = minheap_extract_min(heap);
    assert(min1.vertex == 2);
    assert(min1.priority == 5.0);
    
    HeapNode min2 = minheap_extract_min(heap);
    assert(min2.vertex == 1);
    assert(min2.priority == 10.0);
    
    HeapNode min3 = minheap_extract_min(heap);
    assert(min3.vertex == 3);
    assert(min3.priority == 15.0);
    
    assert(minheap_is_empty(heap));
    
    minheap_free(heap);
    PASS();
}

void test_minheap_decrease_key(void) {
    TEST("minheap_decrease_key");
    
    MinHeap *heap = minheap_create(10, 100);
    
    minheap_insert(heap, 1, 10.0);
    minheap_insert(heap, 2, 20.0);
    minheap_insert(heap, 3, 30.0);
    
    /* Decrease key of vertex 3 to make it minimum */
    minheap_decrease_key(heap, 3, 5.0);
    
    HeapNode min = minheap_extract_min(heap);
    assert(min.vertex == 3);
    assert(min.priority == 5.0);
    
    minheap_free(heap);
    PASS();
}

void test_minheap_contains(void) {
    TEST("minheap_contains");
    
    MinHeap *heap = minheap_create(10, 100);
    
    minheap_insert(heap, 10, 5.0);
    minheap_insert(heap, 20, 10.0);
    
    assert(minheap_contains(heap, 10));
    assert(minheap_contains(heap, 20));
    assert(!minheap_contains(heap, 30));
    
    minheap_extract_min(heap);
    assert(!minheap_contains(heap, 10));
    assert(minheap_contains(heap, 20));
    
    minheap_free(heap);
    PASS();
}

void test_minheap_ordering(void) {
    TEST("minheap_ordering");
    
    MinHeap *heap = minheap_create(100, 1000);
    
    /* Insert in random order */
    minheap_insert(heap, 5, 50.0);
    minheap_insert(heap, 1, 10.0);
    minheap_insert(heap, 3, 30.0);
    minheap_insert(heap, 4, 40.0);
    minheap_insert(heap, 2, 20.0);
    
    /* Extract should give sorted order */
    double prev = -1.0;
    while (!minheap_is_empty(heap)) {
        HeapNode node = minheap_extract_min(heap);
        assert(node.priority >= prev);
        prev = node.priority;
    }
    
    minheap_free(heap);
    PASS();
}

void test_minheap_equal_priorities(void) {
    TEST("minheap_equal_priorities");
    
    MinHeap *heap = minheap_create(10, 100);
    
    minheap_insert(heap, 1, 10.0);
    minheap_insert(heap, 2, 10.0);
    minheap_insert(heap, 3, 10.0);
    
    /* All have same priority, should extract in some order */
    HeapNode n1 = minheap_extract_min(heap);
    HeapNode n2 = minheap_extract_min(heap);
    HeapNode n3 = minheap_extract_min(heap);
    
    assert(n1.priority == 10.0);
    assert(n2.priority == 10.0);
    assert(n3.priority == 10.0);
    
    minheap_free(heap);
    PASS();
}

void test_minheap_many_operations(void) {
    TEST("minheap_many_operations");
    
    MinHeap *heap = minheap_create(100, 1000);
    
    /* Insert many items */
    for (int i = 0; i < 50; i++) {
        minheap_insert(heap, i, (double)(50 - i));
    }
    
    assert(heap->size == 50);
    
    /* Decrease some keys */
    minheap_decrease_key(heap, 40, 1.0);
    minheap_decrease_key(heap, 30, 2.0);
    
    /* Extract all and verify ordering */
    double prev = -1.0;
    int count = 0;
    while (!minheap_is_empty(heap)) {
        HeapNode node = minheap_extract_min(heap);
        assert(node.priority >= prev);
        prev = node.priority;
        count++;
    }
    
    assert(count == 50);
    
    minheap_free(heap);
    PASS();
}

void test_minheap_zero_priority(void) {
    TEST("minheap_zero_priority");
    
    MinHeap *heap = minheap_create(10, 100);
    
    minheap_insert(heap, 1, 0.0);
    minheap_insert(heap, 2, 5.0);
    minheap_insert(heap, 3, 0.0);
    
    HeapNode min = minheap_extract_min(heap);
    assert(min.priority == 0.0);
    
    minheap_free(heap);
    PASS();
}

void test_minheap_free_null(void) {
    TEST("minheap_free_null");
    minheap_free(NULL);   /* must not crash */
    PASS();
}

void test_minheap_insert_when_full(void) {
    TEST("minheap_insert_when_full");
    MinHeap *heap = minheap_create(2, 100);
    minheap_insert(heap, 1, 10.0);
    minheap_insert(heap, 2, 20.0);
    /* capacity == 2; this insert is silently dropped */
    minheap_insert(heap, 3, 5.0);
    assert(heap->size == 2);
    minheap_free(heap);
    PASS();
}

void test_minheap_insert_vertex_overflow(void) {
    TEST("minheap_insert_vertex_overflow");
    MinHeap *heap = minheap_create(10, 5);   /* max_vertex = 5 */
    minheap_insert(heap, 6, 1.0);            /* vertex 6 > max_vertex → no-op */
    assert(heap->size == 0);
    minheap_free(heap);
    PASS();
}

void test_minheap_decrease_key_vertex_overflow(void) {
    TEST("minheap_decrease_key_vertex_overflow");
    MinHeap *heap = minheap_create(10, 5);
    minheap_insert(heap, 1, 10.0);
    minheap_decrease_key(heap, 6, 1.0);   /* vertex 6 > max_vertex → early return */
    assert(heap->size == 1);
    minheap_free(heap);
    PASS();
}

void test_minheap_decrease_key_not_in_heap(void) {
    TEST("minheap_decrease_key_not_in_heap");
    MinHeap *heap = minheap_create(10, 100);
    minheap_insert(heap, 1, 10.0);
    minheap_decrease_key(heap, 5, 1.0);   /* vertex 5 not inserted → idx<0 → early return */
    assert(heap->size == 1);
    minheap_free(heap);
    PASS();
}

void test_minheap_contains_vertex_overflow(void) {
    TEST("minheap_contains_vertex_overflow");
    MinHeap *heap = minheap_create(10, 5);
    bool result = minheap_contains(heap, 6);  /* vertex 6 > max_vertex → false */
    assert(!result);
    minheap_free(heap);
    PASS();
}

int main(void) {
    printf("=== MinHeap Unit Tests ===\n\n");

    test_minheap_create();
    test_minheap_insert_extract();
    test_minheap_decrease_key();
    test_minheap_contains();
    test_minheap_ordering();
    test_minheap_equal_priorities();
    test_minheap_many_operations();
    test_minheap_zero_priority();
    test_minheap_free_null();
    test_minheap_insert_when_full();
    test_minheap_insert_vertex_overflow();
    test_minheap_decrease_key_vertex_overflow();
    test_minheap_decrease_key_not_in_heap();
    test_minheap_contains_vertex_overflow();

    printf("\n✅ All minheap tests passed!\n");
    return 0;
}

