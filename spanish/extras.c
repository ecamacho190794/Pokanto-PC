/* ROM identity hooks for the Pokered-es Spanish Red build. */
#include <stdint.h>
#include "game_extras.h"

const uint32_t *game_get_valid_crcs(int *out_count) {
    static const uint32_t crcs[] = { 0xD8507D8Au };
    if (out_count) *out_count = (int)(sizeof(crcs) / sizeof(crcs[0]));
    return crcs;
}

uint32_t game_get_expected_crc32(void) { return 0; }

const char *game_get_name(void) { return "Pokémon Edición Roja"; }
