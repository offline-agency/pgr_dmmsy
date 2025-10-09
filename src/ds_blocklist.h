#ifndef DS_BLOCKLIST_H
#define DS_BLOCKLIST_H

#include <stdint.h>
#include <stdbool.h>

/* Block structure for organizing vertices by distance ranges */
typedef struct Block {
    double min_dist;
    double max_dist;
    int64_t *vertices;
    int64_t count;
    int64_t capacity;
    struct Block *next;
} Block;

/* Block list structure */
typedef struct {
    Block *head;
    Block *tail;
    int64_t num_blocks;
} BlockList;

/* Function declarations */
BlockList* blocklist_create(void);
void blocklist_free(BlockList *list);
Block* block_create(double min_dist, double max_dist);
void block_free(Block *block);
void block_add_vertex(Block *block, int64_t vertex);
void blocklist_add_block(BlockList *list, Block *block);
Block* blocklist_find_block(BlockList *list, double distance);

#endif /* DS_BLOCKLIST_H */

