#include "ds_blocklist.h"
#include <stdlib.h>

BlockList* blocklist_create(void) {
    BlockList *list = (BlockList*)malloc(sizeof(BlockList));
    if (!list) return NULL;
    
    list->head = NULL;
    list->tail = NULL;
    list->num_blocks = 0;
    
    return list;
}

void block_free(Block *block) {
    if (!block) return;
    free(block->vertices);
    free(block);
}

void blocklist_free(BlockList *list) {
    Block *current;
    
    if (!list) return;
    
    current = list->head;
    while (current) {
        Block *tmp = current;
        current = current->next;
        block_free(tmp);
    }
    
    free(list);
}

Block* block_create(double min_dist, double max_dist) {
    Block *block = (Block*)malloc(sizeof(Block));
    if (!block) return NULL;
    
    block->min_dist = min_dist;
    block->max_dist = max_dist;
    block->count = 0;
    block->capacity = 32;  /* Initial capacity */
    block->vertices = (int64_t*)malloc(block->capacity * sizeof(int64_t));
    block->next = NULL;
    
    if (!block->vertices) {
        free(block);
        return NULL;
    }
    
    return block;
}

void block_add_vertex(Block *block, int64_t vertex) {
    if (block->count >= block->capacity) {
        int64_t new_capacity = block->capacity * 2;
        int64_t *new_vertices = (int64_t*)realloc(block->vertices, 
                                                   new_capacity * sizeof(int64_t));
        if (!new_vertices) return;
        
        block->vertices = new_vertices;
        block->capacity = new_capacity;
    }
    
    block->vertices[block->count++] = vertex;
}

void blocklist_add_block(BlockList *list, Block *block) {
    if (!list->head) {
        list->head = block;
        list->tail = block;
    } else {
        list->tail->next = block;
        list->tail = block;
    }
    list->num_blocks++;
}

Block* blocklist_find_block(BlockList *list, double distance) {
    Block *current = list->head;
    while (current) {
        if (distance >= current->min_dist && distance < current->max_dist) {
            return current;
        }
        current = current->next;
    }
    return NULL;
}

