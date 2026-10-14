/*
 * extras.c — PokemonRedAndBlueRecomp game-specific hooks.
 *
 * Red and Blue share engine code; the launcher accepts either ROM and feeds
 * the selected image into the same recompiled binary.
 */
#include <stdint.h>
#include "game_extras.h"
#include "dev_tools.h"

const uint32_t *game_get_valid_crcs(int *out_count) {
    static const uint32_t crcs[] = {
        0x9F7FDD53u,  /* Pokemon Red (UE) [S][!] */
        0xD6DA8A1Au,  /* Pokemon Blue (UE) [S][!] */
        0x79F23BC6u,  /* Pokemon Red Extended (Gen2 graft) */
        0x00C76296u,  /* Pokemon Blue Extended (Gen2 graft) */
    };
    if (out_count) *out_count = (int)(sizeof(crcs) / sizeof(crcs[0]));
    return crcs;
}

uint32_t game_get_expected_crc32(void) { return 0; }

int game_handle_dev_hotkey(struct GBContext *ctx, GBDevHotkey hotkey) {
    if (hotkey != GB_DEV_HOTKEY_RARE_CANDY) {
        return 0;
    }
    return dev_add_rare_candy(ctx, 0xD31D, 0xD31E);
}

const char *game_get_name(void) { return "Pok\xC3\xA9mon Red & Blue"; }

#define POKERED_W_IS_IN_BATTLE 0xD057
#define POKERED_CURRENT_MAP 0xD35E
#define POKERED_MAP_VIEW_POINTER 0xD35F
#define POKERED_Y_BLOCK_COORD 0xD363
#define POKERED_X_BLOCK_COORD 0xD364
#define POKERED_MAP_HEIGHT 0xD368
#define POKERED_MAP_WIDTH 0xD369
#define POKERED_TILESET_BANK 0xD52B
#define POKERED_TILESET_BLOCKS_POINTER 0xD52C
#include "pokemon_extended_view.h"
