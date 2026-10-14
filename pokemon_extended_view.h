#ifndef POKEMON_EXTENDED_VIEW_H
#define POKEMON_EXTENDED_VIEW_H

#include <stdint.h>
#include "game_extras.h"
#include "gb_widescreen.h"
#include "gbrt.h"

enum {
    POKERED_OVERWORLD_MAP_START = 0xC6E8,
    POKERED_OVERWORLD_MAP_END = 0xCBFC,
    POKERED_VISIBLE_TILEMAP = 0xC508,
    POKERED_VISIBLE_TILEMAP_WIDTH = 20,
    POKERED_VISIBLE_TILEMAP_HEIGHT = 18,
    POKERED_SCROLL_PREFETCH_PIXELS = 16,
};

typedef struct {
    uint16_t map_view_pointer;
    uint8_t map_height;
    uint8_t map_width;
    uint8_t x_block_coord;
    uint8_t y_block_coord;
    int valid;
} PokemonExtendedView;

static PokemonExtendedView s_extended_view;
/* Frame-stable snapshot bookkeeping. The whole overworld scene is captured
 * once at the top of the visible frame (LY 0) and reused for every margin
 * scanline; reading live guest fields per scanline tears scrolling margins. */
static int s_snapshot_valid = 0;
static uint8_t s_snapshot_ly = 0xFF;
static uint32_t s_seeded_view_key = 0xFFFFFFFFu;
static uint32_t s_extra_left = 0;
static uint32_t s_extra_right = 0;

static int pokemon_floor_divide(int value, int divisor) {
    if (value >= 0) {
        return value / divisor;
    }
    return -((-value + divisor - 1) / divisor);
}

static int pokemon_read_map_tile(struct GBContext *ctx,
                                 const PokemonExtendedView *view,
                                 int map_stride, int map_base_row,
                                 int map_base_column, uint8_t tileset_bank,
                                 uint16_t tileset_pointer, int tile_x,
                                 int tile_y, uint8_t *tile) {
    int block_x = pokemon_floor_divide(tile_x, 4);
    int block_y = pokemon_floor_divide(tile_y, 4);
    int map_row = map_base_row + block_y;
    int map_column = map_base_column + block_x;
    int tile_in_block_x = tile_x - block_x * 4;
    int tile_in_block_y = tile_y - block_y * 4;
    int map_address = POKERED_OVERWORLD_MAP_START +
        map_row * map_stride + map_column;
    uint8_t block;
    uint32_t tile_data_offset;
    uint32_t rom_address;

    if (map_row < 0 || map_row >= (int)view->map_height + 6 ||
        map_column < 0 || map_column >= map_stride ||
        map_address < POKERED_OVERWORLD_MAP_START ||
        map_address >= POKERED_OVERWORLD_MAP_END ||
        tile_in_block_x < 0 || tile_in_block_x >= 4 ||
        tile_in_block_y < 0 || tile_in_block_y >= 4) {
        return 0;
    }
    block = gb_read8(ctx, (uint16_t)map_address);
    tile_data_offset = (uint32_t)tileset_pointer - 0x4000u +
        (uint32_t)block * 16u + (uint32_t)tile_in_block_y * 4u +
        (uint32_t)tile_in_block_x;
    rom_address = (uint32_t)tileset_bank * 0x4000u + tile_data_offset;
    if (rom_address >= ctx->rom_size) {
        return 0;
    }
    *tile = ctx->rom[rom_address];
    return 1;
}

static int pokemon_seed_margin_tilemap(struct GBContext *ctx,
                                       const PokemonExtendedView *view) {
    uint8_t seeded[32 * 32] = {0};
    uint8_t scx = ctx->io[0x43];
    uint8_t scy = ctx->io[0x42];
    uint16_t tilemap = (ctx->io[0x40] & 0x08) ? 0x9C00 : 0x9800;
    int tilemap_offset = tilemap - 0x8000;
    int map_stride = (int)view->map_width + 6;
    int map_base_offset = (int)view->map_view_pointer -
        POKERED_OVERWORLD_MAP_START;
    int map_base_row = map_base_offset / map_stride;
    int map_base_column = map_base_offset % map_stride;
    uint8_t tileset_bank = gb_read8(ctx, POKERED_TILESET_BANK);
    uint16_t tileset_pointer = (uint16_t)(
        gb_read8(ctx, POKERED_TILESET_BLOCKS_POINTER) |
        ((uint16_t)gb_read8(ctx, POKERED_TILESET_BLOCKS_POINTER + 1) << 8));
    int seeded_count = 0;

    if (map_stride <= 0 || tileset_pointer < 0x4000 ||
        tileset_pointer >= 0x8000) {
        return 0;
    }

    /* Verify the map reconstruction against the tile IDs the PPU actually
     * reads for the native viewport. wTileMap can be stale during map entry. */
    for (int y = 0; y < POKERED_VISIBLE_TILEMAP_HEIGHT; ++y) {
        for (int x = 0; x < POKERED_VISIBLE_TILEMAP_WIDTH; ++x) {
            uint8_t expected;
            int native_tile_x = (((x * 8) + scx) & 0xFF) / 8;
            int native_tile_y = (((y * 8) + scy) & 0xFF) / 8;
            uint8_t current = ctx->vram[tilemap_offset +
                native_tile_y * 32 + native_tile_x];
            int readable = pokemon_read_map_tile(ctx, view, map_stride, map_base_row,
                    map_base_column, tileset_bank, tileset_pointer,
                    (int)view->x_block_coord * 2 + x,
                    (int)view->y_block_coord * 2 + y, &expected);
            if (!readable || expected != current) {
                return 0;
            }
        }
    }

    /* Prefill two tile columns beyond each exposed margin. During a step,
     * Pokered updates map coordinates and VRAM on different frames; the lead
     * cells keep the next margin covered while the native tilemap catches up. */
    int prefetch = (s_extra_left || s_extra_right)
        ? POKERED_SCROLL_PREFETCH_PIXELS : 0;
    for (int x = -(int)s_extra_left - prefetch;
         x < 160 + (int)s_extra_right + prefetch; ++x) {
        if (x >= 0 && x < 160) {
            continue;
        }
        int tile_x = (int)view->x_block_coord * 2 +
            pokemon_floor_divide(x + scx, 8) -
            pokemon_floor_divide(scx, 8);
        for (int y = 0; y < 144; ++y) {
            int tile_y = (int)view->y_block_coord * 2 +
                pokemon_floor_divide(y + scy, 8) -
                pokemon_floor_divide(scy, 8);
            int dest_x = ((x + scx) & 0xFF) / 8;
            int dest_y = ((y + scy) & 0xFF) / 8;
            int dest_index = dest_y * 32 + dest_x;
            uint8_t tile;
            if (seeded[dest_index] || !pokemon_read_map_tile(ctx, view,
                    map_stride, map_base_row, map_base_column, tileset_bank,
                    tileset_pointer, tile_x, tile_y, &tile)) {
                continue;
            }
            seeded[dest_index] = 1;
            ctx->vram[tilemap_offset + dest_index] = tile;
            ++seeded_count;
        }
    }
    return seeded_count;
}

uint16_t game_max_view_width(void) {
    return GB_WS_MAX_VIEW_WIDTH;
}

void game_extended_view_init(struct GBContext *ctx,
                             uint32_t extra_left, uint32_t extra_right) {
    (void)ctx;
    s_extra_left = extra_left;
    s_extra_right = extra_right;
    /* Re-arm the view so the next visible frame captures fresh map metadata. */
    s_extended_view.valid = 0;
    s_snapshot_valid = 0;
    s_snapshot_ly = 0xFF;
    s_seeded_view_key = 0xFFFFFFFFu;
}

void game_extended_view_update(struct GBContext *ctx) {
    uint8_t ly;

    if (!ctx || !ctx->rom || !ctx->wram || !ctx->vram) {
        return;
    }

    /* Current visible scanline (LY, 0xFF44). Kept in sync by the PPU. */
    ly = ctx->io[0x44];

    /* Capture the whole overworld scene exactly once per visible frame, at the
     * top scanline (LY 0), then reuse that frame-stable snapshot for every
     * remaining margin scanline.
     *
     * While the player steps, Pokered updates map metadata and streams VRAM
     * columns as separate operations. Keep only the validity check frame-stable
     * so a transient coordinate does not make the margins appear/disappear.
     * The actual added pixels below are read from live VRAM with the same SCX,
     * SCY and tilemap path as the native viewport.
     *
     * LY increases monotonically 0..143 within the visible frame and only
     * decreases by wrapping back to 0, so a new frame is detected either by
     * reaching LY 0 or by LY dropping below the captured scanline. */
    if (s_snapshot_valid && ly != 0 && ly > s_snapshot_ly) {
        return;
    }

    {
        PokemonExtendedView next = {0};
        uint8_t in_battle = gb_read8(ctx, POKERED_W_IS_IN_BATTLE);
        next.map_height = gb_read8(ctx, POKERED_MAP_HEIGHT);
        next.map_width = gb_read8(ctx, POKERED_MAP_WIDTH);
        next.map_view_pointer = (uint16_t)(
            gb_read8(ctx, POKERED_MAP_VIEW_POINTER) |
            ((uint16_t)gb_read8(ctx, POKERED_MAP_VIEW_POINTER + 1) << 8));
        next.x_block_coord = gb_read8(ctx, POKERED_X_BLOCK_COORD);
        next.y_block_coord = gb_read8(ctx, POKERED_Y_BLOCK_COORD);
        next.valid = !in_battle &&
            next.map_height > 0 && next.map_width > 0 &&
            ((uint32_t)next.map_width + 6u) *
                ((uint32_t)next.map_height + 6u) <= 1300u &&
            next.x_block_coord <= 1 && next.y_block_coord <= 1 &&
            next.map_view_pointer >= POKERED_OVERWORLD_MAP_START &&
            next.map_view_pointer < POKERED_OVERWORLD_MAP_END;

        /* During a step, the ROM updates the block coordinate, map pointer,
         * and streamed tile buffer in separate instructions. A snapshot can
         * therefore observe a transient combination (notably block coord 2)
         * even though the previous frame's view is still valid. Do not turn
         * that one-instruction state into a black/flickering margin frame:
         * retain the last coherent snapshot until a complete valid one is
         * available. Battles explicitly disable the extended map. */
        if (in_battle) {
            s_extended_view.valid = 0;
            g_gbws_pillarbox = 1;
            g_gbws_pillarbox_left = 1;
            g_gbws_pillarbox_right = 1;
        } else if (next.valid) {
            s_extended_view = next;
            uint8_t map_id = gb_read8(ctx, POKERED_CURRENT_MAP);
            uint32_t view_key = 2166136261u;
            view_key = (view_key ^ map_id) * 16777619u;
            view_key = (view_key ^ next.map_view_pointer) * 16777619u;
            view_key = (view_key ^ next.x_block_coord) * 16777619u;
            view_key = (view_key ^ next.y_block_coord) * 16777619u;
            view_key = (view_key ^ (ctx->io[0x43] >> 3)) * 16777619u;
            view_key = (view_key ^ (ctx->io[0x42] >> 3)) * 16777619u;
            if (view_key != s_seeded_view_key &&
                pokemon_seed_margin_tilemap(ctx, &next) > 0) {
                    s_seeded_view_key = view_key;
            }
            g_gbws_pillarbox = 0;
            g_gbws_pillarbox_left = 0;
            g_gbws_pillarbox_right = 0;
        } else if (!s_extended_view.valid) {
            g_gbws_pillarbox = 1;
            g_gbws_pillarbox_left = 1;
            g_gbws_pillarbox_right = 1;
        }
        s_snapshot_valid = 1;
        s_snapshot_ly = ly;
    }
}

int game_extended_view_bg_tile(struct GBContext *ctx, int screen_x,
                               uint8_t scanline, uint8_t *tile,
                               uint8_t *attr) {
    (void)screen_x;
    (void)scanline;
    (void)tile;
    (void)attr;
    if (!ctx || !ctx->io || !s_extended_view.valid) {
        return -1;
    }
    return 0;
}

#endif
