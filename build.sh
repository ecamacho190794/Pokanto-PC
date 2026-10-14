#!/bin/bash
# Pokemon Red/Blue recompiler build script
# Usage:
#   ./build.sh              # Rebuild game only (incremental)
#   ./build.sh all          # Full regenerate + rebuild
#   ./build.sh regen        # Regenerate C code only (no compile)
#   ./build.sh bank 01 03   # Regenerate + rebuild only specified banks
#   ./build.sh recompiler   # Rebuild the recompiler itself
#   ./build.sh clean        # Clean build artifacts
#   ./build.sh run          # Build + run
#   ./build.sh run --record inputs.txt   # Build + run with recording

set -e
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# One entry point for every supported language. Adding a language means adding
# languages/<id>/build.sh and its language-specific inputs/catalog; shared
# English build commands remain available without a language name.
if [ -z "${POKANTO_LANGUAGE_DISPATCHED:-}" ]; then
    case "${1:-}" in
        english) set -- en "${@:2}" ;;
        spanish) set -- es "${@:2}" ;;
    esac
    case "${1:-}" in
        languages|--languages|-h|--help)
            echo "Usage: $0 <language> [build command]"
            echo "Supported languages:"
            for language_script in "$SCRIPT_DIR"/languages/*/build.sh; do
                [ -f "$language_script" ] && printf '  %s\n' "$(basename "$(dirname "$language_script")")"
            done
            echo "Legacy English commands are also available: game, all, regen, run, ..."
            exit 0
            ;;
    esac
    if [ -f "$SCRIPT_DIR/languages/${1:-}/build.sh" ]; then
        language_script="$SCRIPT_DIR/languages/$1/build.sh"
        shift
        exec "$language_script" "$@"
    fi
fi

RECOMP_DIR="$SCRIPT_DIR/gb-recompiled"
GEN_DIR="$SCRIPT_DIR/generated"
BUILD_DIR="$GEN_DIR/build"
RECOMP_BUILD="$RECOMP_DIR/build"
CONFIG="$SCRIPT_DIR/pokemon_red_blue.toml"
POKERED_DIR="$SCRIPT_DIR/third_party/pokered"
POKERED_PATCH="$SCRIPT_DIR/patches/pokered-en-desktop-exit.patch"
ENGLISH_ROM="$SCRIPT_DIR/roms/Pokemon Red (UE) [S][!].gb"
ENGLISH_EXPECTED_SHA1="ea9bcae617fdf159b045185467ae58b2e4a48b9a"
ENGLISH_STOCK_RED="$GEN_DIR/Pokemon_Red_Blue_stock.gbc"
ENGLISH_STOCK_BLUE="$GEN_DIR/Pokemon_Blue_stock.gbc"
ENGLISH_PATCHED_RED="$GEN_DIR/Pokemon_Red_Blue_patched.gbc"
ENGLISH_PATCHED_BLUE="$GEN_DIR/Pokemon_Blue_patched.gbc"
EXE_SUFFIX=""
if [[ "$(uname -s)" == MINGW* || "$(uname -s)" == MSYS* || "$(uname -s)" == CYGWIN* ]]; then
    EXE_SUFFIX=".exe"
fi
GBRECOMP="$RECOMP_BUILD/bin/gbrecomp${EXE_SUFFIX}"
EXE="$BUILD_DIR/Pokemon_Red_Blue${EXE_SUFFIX}"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

log()  { echo -e "${GREEN}[BUILD]${NC} $*"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $*"; }
err()  { echo -e "${RED}[ERROR]${NC} $*"; }

build_recompiler() {
    "$SCRIPT_DIR/scripts/apply-submodule-patches.sh"
    log "Building recompiler..."
    cmake -S "$RECOMP_DIR" -B "$RECOMP_BUILD" -G Ninja \
        -DRECOMP_UI_ROOT="$SCRIPT_DIR/recomp-ui"
    cmake --build "$RECOMP_BUILD" --target gbrecomp
    log "Recompiler built: $GBRECOMP"
}

prepare_english_roms() {
    for tool in make rgbasm rgbfix rgbgfx rgblink python3 shasum; do
        if ! command -v "$tool" >/dev/null 2>&1; then
            err "Missing required English ROM build tool: $tool"
            exit 1
        fi
    done

    if [ ! -f "$ENGLISH_ROM" ]; then
        err "English Red ROM not found: $ENGLISH_ROM"
        exit 1
    fi
    local actual_sha1
    actual_sha1="$(shasum -a 1 "$ENGLISH_ROM" | awk '{print $1}')"
    if [ "$actual_sha1" != "$ENGLISH_EXPECTED_SHA1" ]; then
        err "English Red ROM SHA1 mismatch: $actual_sha1"
        exit 1
    fi

    if git -C "$POKERED_DIR" apply --unidiff-zero --reverse --check "$POKERED_PATCH" >/dev/null 2>&1; then
        git -C "$POKERED_DIR" apply --unidiff-zero --reverse "$POKERED_PATCH"
    elif ! git -C "$POKERED_DIR" apply --unidiff-zero --check "$POKERED_PATCH" >/dev/null 2>&1; then
        err "Cannot apply $POKERED_PATCH to the pinned Pokered source."
        exit 1
    fi

    mkdir -p "$GEN_DIR"
    if [ ! -f "$ENGLISH_STOCK_RED" ] || [ ! -f "$ENGLISH_STOCK_BLUE" ]; then
        log "Building pristine English Red/Blue ROMs from Pokered source..."
        make -C "$POKERED_DIR" red blue
        local assembled_red_sha1
        assembled_red_sha1="$(shasum -a 1 "$POKERED_DIR/pokered.gbc" | awk '{print $1}')"
        if [ "$assembled_red_sha1" != "$ENGLISH_EXPECTED_SHA1" ]; then
            err "Pokered source produced unexpected Red ROM SHA1: $assembled_red_sha1"
            exit 1
        fi
        cp "$POKERED_DIR/pokered.gbc" "$ENGLISH_STOCK_RED"
        cp "$POKERED_DIR/pokeblue.gbc" "$ENGLISH_STOCK_BLUE"
    fi

    local stock_red_sha1
    stock_red_sha1="$(shasum -a 1 "$ENGLISH_STOCK_RED" | awk '{print $1}')"
    if [ "$stock_red_sha1" != "$ENGLISH_EXPECTED_SHA1" ]; then
        err "Cached stock Red ROM SHA1 mismatch: $stock_red_sha1"
        exit 1
    fi
    local stock_blue_crc
    stock_blue_crc="$(python3 -c 'import binascii, pathlib, sys; print(f"{binascii.crc32(pathlib.Path(sys.argv[1]).read_bytes()) & 0xffffffff:08X}")' "$ENGLISH_STOCK_BLUE")"
    if [ "$stock_blue_crc" != "D6DA8A1A" ]; then
        err "Stock Blue ROM CRC32 mismatch: $stock_blue_crc"
        exit 1
    fi

    if ! git -C "$POKERED_DIR" apply --unidiff-zero --check "$POKERED_PATCH" >/dev/null 2>&1; then
        err "English desktop-exit patch cannot be applied to the Pokered source."
        exit 1
    fi
    git -C "$POKERED_DIR" apply --unidiff-zero "$POKERED_PATCH"
    log "Building patched English Red/Blue ROMs..."
    make -C "$POKERED_DIR" red blue
    cp "$POKERED_DIR/pokered.gbc" "$ENGLISH_PATCHED_RED"
    cp "$POKERED_DIR/pokeblue.gbc" "$ENGLISH_PATCHED_BLUE"
}

regenerate() {
    log "Preparing patched English Red/Blue ROMs..."
    prepare_english_roms
    log "Regenerating C code from patched English Red..."
    cd "$SCRIPT_DIR"
    "$GBRECOMP" --config "$CONFIG"
    log "Regeneration complete. $(ls "$GEN_DIR/"*bank*.c 2>/dev/null | wc -l) bank files."
}

build_english_patches() {
    for rom in "$ENGLISH_PATCHED_RED" "$ENGLISH_PATCHED_BLUE"; do
        if [ ! -s "$rom" ]; then
            err "Patched English ROM is missing or empty: $rom"
            exit 1
        fi
    done
    python3 "$SCRIPT_DIR/tools/create_bps_patch.py" \
        --source "$ENGLISH_ROM" \
        --target "$ENGLISH_PATCHED_RED" \
        --output "$BUILD_DIR/Pokemon_Red_Blue.bps" \
        --source-crc32 0x9F7FDD53
    python3 "$SCRIPT_DIR/tools/create_bps_patch.py" \
        --source "$ENGLISH_STOCK_BLUE" \
        --target "$ENGLISH_PATCHED_BLUE" \
        --output "$BUILD_DIR/Pokemon_Red_Blue-D6DA8A1A.bps" \
        --source-crc32 0xD6DA8A1A
}

build_game() {
    log "Building game..."
    # Ensure CMake is configured
    if [ ! -f build.ninja ]; then
        log "Running cmake..."
        cmake -S "$GEN_DIR" -B "$BUILD_DIR" -G Ninja
    fi

    # Reconfigure if CMakeLists changed
    if [ "$GEN_DIR/CMakeLists.txt" -nt build.ninja ]; then
        log "CMakeLists.txt changed, reconfiguring..."
        cmake -S "$GEN_DIR" -B "$BUILD_DIR" -G Ninja
    fi

    local start=$(date +%s)
    cmake --build "$BUILD_DIR" --parallel
    build_english_patches
    local end=$(date +%s)
    log "Build complete in $((end - start))s"
}

build_banks() {
    # Touch only specified bank files to force recompile
    local banks="$@"
    for bank in $banks; do
        local padded=$(printf "%02x" "0x$bank" 2>/dev/null || printf "%02x" "$bank")
        local bankfile="$GEN_DIR/Pokemon_Red_Blue_bank_${padded}.c"
        if [ -f "$bankfile" ]; then
            log "Marking bank $padded for rebuild"
            touch "$bankfile"
        else
            warn "Bank file not found: $bankfile"
        fi
    done
    build_game
}

run_game() {
    build_game
    log "Launching game..."
    exec "$EXE" "$@"
}

case "${1:-game}" in
    recompiler)
        build_recompiler
        ;;
    regen|regenerate)
        regenerate
        ;;
    all)
        build_recompiler
        regenerate
        build_game
        ;;
    bank|banks)
        shift
        if [ $# -eq 0 ]; then
            err "Usage: $0 bank <bank_hex> [bank_hex...]"
            err "Example: $0 bank 01 03 1e"
            exit 1
        fi
        regenerate
        build_banks "$@"
        ;;
    game|build)
        build_game
        ;;
    run)
        shift
        run_game "$@"
        ;;
    clean)
        log "Cleaning build..."
        cmake --build "$BUILD_DIR" --target clean 2>/dev/null || true
        log "Done."
        ;;
    *)
        echo "Pokemon Red/Blue Recompiler Build Script"
        echo ""
        echo "Usage: $0 <command> [args]"
        echo ""
        echo "Commands:"
        echo "  game          Build game only (incremental, default)"
        echo "  all           Full rebuild (recompiler + regen + game)"
        echo "  regen         Regenerate C code from ROM"
        echo "  bank 01 03    Regen + rebuild specific banks"
        echo "  recompiler    Rebuild the recompiler"
        echo "  run [args]    Build + launch (pass extra args to exe)"
        echo "  clean         Clean build artifacts"
        ;;
esac
