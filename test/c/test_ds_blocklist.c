/*
 * test_ds_blocklist.c — 100% line and branch coverage for src/ds_blocklist.c
 *
 * Compile on Linux with:
 *   gcc -Wall -g -I../../src -DNO_PG_HEADERS -DWRAP_MALLOC \
 *       -o test_ds_blocklist test_ds_blocklist.c ../../src/ds_blocklist.c \
 *       -Wl,--wrap=malloc -Wl,--wrap=realloc -lm
 *
 * The WRAP_MALLOC guard keeps the file compilable on macOS (no --wrap);
 * malloc-failure tests are skipped silently there. Coverage is measured
 * in CI on Linux where --wrap is supported.
 */

#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <string.h>

#include "../../src/ds_blocklist.h"

/* ── malloc/realloc interception (GNU ld --wrap, Linux only) ──────── */
#ifdef WRAP_MALLOC

static int malloc_countdown = -1;  /* -1=never fail; 0=fail now; N=fail after N */
static int realloc_countdown = -1;

void *__real_malloc(size_t size);
void *__wrap_malloc(size_t size) {
    if (malloc_countdown == 0) { malloc_countdown = -1; return NULL; }
    if (malloc_countdown > 0) malloc_countdown--;
    return __real_malloc(size);
}

void *__real_realloc(void *ptr, size_t size);
void *__wrap_realloc(void *ptr, size_t size) {
    if (realloc_countdown == 0) { realloc_countdown = -1; return NULL; }
    if (realloc_countdown > 0) realloc_countdown--;
    return __real_realloc(ptr, size);
}

#define FAIL_MALLOC_AFTER(n) (malloc_countdown = (n))
#define FAIL_REALLOC_NEXT()  (realloc_countdown = 0)

#else  /* not Linux / no --wrap */

#define FAIL_MALLOC_AFTER(n) ((void)0)
#define FAIL_REALLOC_NEXT()  ((void)0)

#endif /* WRAP_MALLOC */

/* ── Test harness ─────────────────────────────────────────────────── */

static int tests_run    = 0;
static int tests_passed = 0;

#define RUN_TEST(fn) do { \
    tests_run++; \
    printf("  %-60s ", #fn); \
    if (fn()) { tests_passed++; printf("[PASS]\n"); } \
    else       {               printf("[FAIL]\n"); } \
} while (0)

/* ══════════════════════════════════════════════════════════════════
 * A — blocklist_create()
 * ══════════════════════════════════════════════════════════════════ */

/* Happy path: struct fields initialised to zero/NULL */
static int test_create_normal(void) {
    BlockList *bl = blocklist_create();
    if (!bl) return 0;
    int ok = (bl->head == NULL && bl->tail == NULL && bl->num_blocks == 0);
    blocklist_free(bl);
    return ok;
}

/* malloc failure → return NULL */
static int test_create_malloc_fail(void) {
#ifndef WRAP_MALLOC
    return 1;  /* skip on platforms without --wrap */
#else
    FAIL_MALLOC_AFTER(0);
    BlockList *bl = blocklist_create();
    return (bl == NULL);
#endif
}

/* ══════════════════════════════════════════════════════════════════
 * B — block_free()
 * ══════════════════════════════════════════════════════════════════ */

/* NULL guard — early return, must not crash */
static int test_block_free_null(void) {
    block_free(NULL);
    return 1;
}

/* Normal free of a valid block */
static int test_block_free_normal(void) {
    Block *b = block_create(0.0, 10.0);
    if (!b) return 0;
    block_free(b);
    return 1;
}

/* ══════════════════════════════════════════════════════════════════
 * C — blocklist_free()
 * ══════════════════════════════════════════════════════════════════ */

/* NULL guard — early return, must not crash */
static int test_blocklist_free_null(void) {
    blocklist_free(NULL);
    return 1;
}

/* Empty list — while loop runs 0 times */
static int test_blocklist_free_empty(void) {
    BlockList *bl = blocklist_create();
    if (!bl) return 0;
    blocklist_free(bl);
    return 1;
}

/* Single block — loop runs once */
static int test_blocklist_free_with_one_block(void) {
    BlockList *bl = blocklist_create();
    Block     *b  = block_create(0.0, 10.0);
    if (!bl || !b) { blocklist_free(bl); block_free(b); return 0; }
    blocklist_add_block(bl, b);
    blocklist_free(bl);   /* frees b as well */
    return 1;
}

/* Three blocks — loop runs 3 times */
static int test_blocklist_free_with_multiple_blocks(void) {
    BlockList *bl = blocklist_create();
    Block *b1 = block_create(0.0,  5.0);
    Block *b2 = block_create(5.0, 10.0);
    Block *b3 = block_create(10.0, 20.0);
    if (!bl || !b1 || !b2 || !b3) {
        blocklist_free(bl); block_free(b1); block_free(b2); block_free(b3);
        return 0;
    }
    blocklist_add_block(bl, b1);
    blocklist_add_block(bl, b2);
    blocklist_add_block(bl, b3);
    blocklist_free(bl);
    return 1;
}

/* ══════════════════════════════════════════════════════════════════
 * D — block_create()
 * ══════════════════════════════════════════════════════════════════ */

/* Happy path: all fields correct */
static int test_block_create_normal(void) {
    Block *b = block_create(1.5, 9.5);
    if (!b) return 0;
    int ok = (b->min_dist == 1.5 &&
              b->max_dist == 9.5 &&
              b->count    == 0   &&
              b->capacity == 32  &&
              b->vertices != NULL &&
              b->next     == NULL);
    block_free(b);
    return ok;
}

/* First malloc (Block struct) fails → return NULL */
static int test_block_create_malloc_fail_block(void) {
#ifndef WRAP_MALLOC
    return 1;
#else
    FAIL_MALLOC_AFTER(0);
    Block *b = block_create(0.0, 1.0);
    return (b == NULL);
#endif
}

/* Second malloc (vertices array) fails → free(block); return NULL */
static int test_block_create_malloc_fail_vertices(void) {
#ifndef WRAP_MALLOC
    return 1;
#else
    FAIL_MALLOC_AFTER(1);   /* let Block alloc succeed, fail vertices */
    Block *b = block_create(0.0, 1.0);
    return (b == NULL);
#endif
}

/* ══════════════════════════════════════════════════════════════════
 * E — block_add_vertex()
 * ══════════════════════════════════════════════════════════════════ */

/* Normal add — two vertices, check values and count */
static int test_block_add_vertex_normal(void) {
    Block *b = block_create(0.0, 100.0);
    if (!b) return 0;
    block_add_vertex(b, 42);
    block_add_vertex(b, 7);
    int ok = (b->count == 2 && b->vertices[0] == 42 && b->vertices[1] == 7);
    block_free(b);
    return ok;
}

/* Add 33 vertices → triggers realloc (capacity 32 → 64) */
static int test_block_add_vertex_triggers_resize(void) {
    Block *b = block_create(0.0, 100.0);
    if (!b) return 0;
    for (int i = 0; i < 33; i++) block_add_vertex(b, (int64_t)i);
    int ok = (b->count == 33 && b->capacity == 64 && b->vertices[32] == 32);
    block_free(b);
    return ok;
}

/* realloc failure → early return, count stays at 32 */
static int test_block_add_vertex_realloc_fail(void) {
#ifndef WRAP_MALLOC
    return 1;
#else
    Block *b = block_create(0.0, 100.0);
    if (!b) return 0;
    /* fill exactly to capacity so next add triggers realloc */
    for (int i = 0; i < 32; i++) block_add_vertex(b, (int64_t)i);
    FAIL_REALLOC_NEXT();
    block_add_vertex(b, 999);   /* realloc fails — must not crash */
    int ok = (b->count == 32);  /* count unchanged */
    block_free(b);
    return ok;
#endif
}

/* ══════════════════════════════════════════════════════════════════
 * F — blocklist_add_block()
 * ══════════════════════════════════════════════════════════════════ */

/* First block: takes the !list->head branch (head = tail = block) */
static int test_blocklist_add_first_block(void) {
    BlockList *bl = blocklist_create();
    Block     *b  = block_create(0.0, 10.0);
    if (!bl || !b) { blocklist_free(bl); block_free(b); return 0; }
    blocklist_add_block(bl, b);
    int ok = (bl->head == b && bl->tail == b && bl->num_blocks == 1);
    blocklist_free(bl);
    return ok;
}

/* Second block: takes the else branch (tail->next = block; tail = block) */
static int test_blocklist_add_subsequent_blocks(void) {
    BlockList *bl = blocklist_create();
    Block *b1 = block_create(0.0,  5.0);
    Block *b2 = block_create(5.0, 10.0);
    if (!bl || !b1 || !b2) {
        blocklist_free(bl); block_free(b1); block_free(b2); return 0;
    }
    blocklist_add_block(bl, b1);
    blocklist_add_block(bl, b2);
    int ok = (bl->head == b1 && bl->tail == b2 &&
              b1->next == b2  && bl->num_blocks == 2);
    blocklist_free(bl);
    return ok;
}

/* ══════════════════════════════════════════════════════════════════
 * G — blocklist_find_block()
 * ══════════════════════════════════════════════════════════════════ */

/* Empty list: loop runs 0 times → NULL */
static int test_find_block_empty_list(void) {
    BlockList *bl = blocklist_create();
    if (!bl) return 0;
    Block *found = blocklist_find_block(bl, 5.0);
    blocklist_free(bl);
    return (found == NULL);
}

/* Distance inside [0,10) matches the first block */
static int test_find_block_found_first(void) {
    BlockList *bl = blocklist_create();
    Block     *b  = block_create(0.0, 10.0);
    if (!bl || !b) { blocklist_free(bl); block_free(b); return 0; }
    blocklist_add_block(bl, b);
    Block *found = blocklist_find_block(bl, 5.0);
    int ok = (found == b);
    blocklist_free(bl);
    return ok;
}

/* Distance 15.0 not in [0,10) → NULL */
static int test_find_block_not_found(void) {
    BlockList *bl = blocklist_create();
    Block     *b  = block_create(0.0, 10.0);
    if (!bl || !b) { blocklist_free(bl); block_free(b); return 0; }
    blocklist_add_block(bl, b);
    Block *found = blocklist_find_block(bl, 15.0);
    int ok = (found == NULL);
    blocklist_free(bl);
    return ok;
}

/* Two blocks: loop iterates over first, matches second */
static int test_find_block_found_second(void) {
    BlockList *bl = blocklist_create();
    Block *b1 = block_create(0.0,  5.0);
    Block *b2 = block_create(5.0, 10.0);
    if (!bl || !b1 || !b2) {
        blocklist_free(bl); block_free(b1); block_free(b2); return 0;
    }
    blocklist_add_block(bl, b1);
    blocklist_add_block(bl, b2);
    Block *found = blocklist_find_block(bl, 7.5);  /* [5,10) → b2 */
    int ok = (found == b2);
    blocklist_free(bl);
    return ok;
}

/* distance == min_dist: condition is `>= min_dist` → should match */
static int test_find_block_boundary_min(void) {
    BlockList *bl = blocklist_create();
    Block     *b  = block_create(5.0, 10.0);
    if (!bl || !b) { blocklist_free(bl); block_free(b); return 0; }
    blocklist_add_block(bl, b);
    Block *found = blocklist_find_block(bl, 5.0);
    int ok = (found == b);
    blocklist_free(bl);
    return ok;
}

/* distance == max_dist: condition is `< max_dist` → should NOT match */
static int test_find_block_boundary_max(void) {
    BlockList *bl = blocklist_create();
    Block     *b  = block_create(0.0, 5.0);
    if (!bl || !b) { blocklist_free(bl); block_free(b); return 0; }
    blocklist_add_block(bl, b);
    Block *found = blocklist_find_block(bl, 5.0);
    int ok = (found == NULL);
    blocklist_free(bl);
    return ok;
}

/* ══════════════════════════════════════════════════════════════════
 * main
 * ══════════════════════════════════════════════════════════════════ */

int main(void) {
    printf("=== ds_blocklist Coverage Tests ===\n\n");

    /* A: blocklist_create */
    RUN_TEST(test_create_normal);
    RUN_TEST(test_create_malloc_fail);

    /* B: block_free */
    RUN_TEST(test_block_free_null);
    RUN_TEST(test_block_free_normal);

    /* C: blocklist_free */
    RUN_TEST(test_blocklist_free_null);
    RUN_TEST(test_blocklist_free_empty);
    RUN_TEST(test_blocklist_free_with_one_block);
    RUN_TEST(test_blocklist_free_with_multiple_blocks);

    /* D: block_create */
    RUN_TEST(test_block_create_normal);
    RUN_TEST(test_block_create_malloc_fail_block);
    RUN_TEST(test_block_create_malloc_fail_vertices);

    /* E: block_add_vertex */
    RUN_TEST(test_block_add_vertex_normal);
    RUN_TEST(test_block_add_vertex_triggers_resize);
    RUN_TEST(test_block_add_vertex_realloc_fail);

    /* F: blocklist_add_block */
    RUN_TEST(test_blocklist_add_first_block);
    RUN_TEST(test_blocklist_add_subsequent_blocks);

    /* G: blocklist_find_block */
    RUN_TEST(test_find_block_empty_list);
    RUN_TEST(test_find_block_found_first);
    RUN_TEST(test_find_block_not_found);
    RUN_TEST(test_find_block_found_second);
    RUN_TEST(test_find_block_boundary_min);
    RUN_TEST(test_find_block_boundary_max);

    printf("\n=== Results: %d/%d passed ===\n", tests_passed, tests_run);
    if (tests_passed == tests_run)
        printf("✅ All ds_blocklist tests passed!\n");
    return (tests_passed == tests_run) ? 0 : 1;
}
