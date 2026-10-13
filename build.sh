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
RECOMP_DIR="$SCRIPT_DIR/gb-recompiled"
GEN_DIR="$SCRIPT_DIR/generated"
BUILD_DIR="$GEN_DIR/build"
RECOMP_BUILD="$RECOMP_DIR/build"
CONFIG="$SCRIPT_DIR/pokemon_red_blue.toml"
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
    log "Building recompiler..."
    cmake -S "$RECOMP_DIR" -B "$RECOMP_BUILD" -G Ninja \
        -DRECOMP_UI_ROOT="$SCRIPT_DIR/recomp-ui"
    cmake --build "$RECOMP_BUILD" --target gbrecomp
    log "Recompiler built: $GBRECOMP"
}

regenerate() {
    log "Regenerating C code from ROM..."
    cd "$SCRIPT_DIR"
    "$GBRECOMP" --config "$CONFIG"
    log "Regeneration complete. $(ls "$GEN_DIR/"*bank*.c 2>/dev/null | wc -l) bank files."
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
