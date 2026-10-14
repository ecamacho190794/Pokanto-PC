#ifndef POKANTO_DEV_TOOLS_H
#define POKANTO_DEV_TOOLS_H

#include <stdint.h>
#include <stdio.h>

#include "dev_config.h"
#include "gbrt.h"

enum {
    DEV_BAG_ITEM_CAPACITY = 20,
    DEV_RARE_CANDY_ITEM_ID = 0x28,
    DEV_MAX_ITEM_QUANTITY = 99,
};

static inline int dev_add_rare_candy(
    GBContext *ctx, uint16_t item_count_address, uint16_t items_address) {
    if (!DEVELOPMENT_MODE || !DEV_TOOL_RARE_CANDY) {
        return 0;
    }
    if (!ctx) {
        fprintf(stderr, "[DEV] Rare Candy grant failed: missing game context.\n");
        return 1;
    }

    const uint8_t item_count = gb_read8(ctx, item_count_address);
    if (item_count > DEV_BAG_ITEM_CAPACITY) {
        fprintf(stderr, "[DEV] Rare Candy grant failed: invalid bag item count.\n");
        return 1;
    }

    for (uint8_t i = 0; i < item_count; i++) {
        const uint16_t item_address = (uint16_t)(items_address + i * 2);
        if (gb_read8(ctx, item_address) != DEV_RARE_CANDY_ITEM_ID) {
            continue;
        }

        const uint16_t quantity_address = (uint16_t)(item_address + 1);
        const uint8_t quantity = gb_read8(ctx, quantity_address);
        if (quantity < DEV_MAX_ITEM_QUANTITY) {
            gb_write8(ctx, quantity_address, (uint8_t)(quantity + 1));
            fprintf(stderr, "[DEV] Added 1 Rare Candy to the bag.\n");
            return 1;
        }
    }

    if (item_count >= DEV_BAG_ITEM_CAPACITY) {
        fprintf(stderr, "[DEV] Rare Candy grant failed: the bag is full.\n");
        return 1;
    }

    const uint16_t new_item_address =
        (uint16_t)(items_address + item_count * 2);
    gb_write8(ctx, new_item_address, DEV_RARE_CANDY_ITEM_ID);
    gb_write8(ctx, (uint16_t)(new_item_address + 1), 1);
    gb_write8(ctx, (uint16_t)(new_item_address + 2), 0xFF);
    gb_write8(ctx, item_count_address, (uint8_t)(item_count + 1));
    fprintf(stderr, "[DEV] Added 1 Rare Candy to the bag.\n");
    return 1;
}

#endif
