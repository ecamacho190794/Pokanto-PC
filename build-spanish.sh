#!/usr/bin/env bash
# Build the Spanish Pokémon Red recompilation using the Pokered-es symbols.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
SOURCE="$ROOT/third_party/pokered-es"
SOURCE_PATCH="$ROOT/patches/pokered-es-start-menu.patch"
ROM="$ROOT/roms/Pokemon Edicion Roja.gb"
EXPECTED_SHA1="fc17c5b904d551b1b908054ccd1c493f755f832a"
RECOMP="$ROOT/gb-recompiled/build/bin/gbrecomp"
ANNOTATIONS="$ROOT/spanish/generated/pokered-es.annotations"
PATCHED_ROM="$ROOT/spanish/generated/Pokemon_Edicion_Roja_patched.gbc"
PATCH_FILE="$ROOT/spanish/generated/build/Pokemon_Edicion_Roja.bps"
CONFIG="$ROOT/spanish/pokemon_red_es.toml"

for tool in make rgbasm rgbfix rgbgfx rgblink python3 shasum cmake ninja; do
    if ! command -v "$tool" >/dev/null 2>&1; then
        echo "[ERROR] Missing required tool: $tool" >&2
        exit 1
    fi
done
if [[ ! -f "$ROM" ]]; then
    echo "[ERROR] Spanish ROM not found: $ROM" >&2
    exit 1
fi
if [[ ! -x "$RECOMP" ]]; then
    echo "[ERROR] gbrecomp is missing; run ./build.sh recompiler first." >&2
    exit 1
fi

actual_sha1="$(shasum -a 1 "$ROM" | awk '{print $1}')"
if [[ "$actual_sha1" != "$EXPECTED_SHA1" ]]; then
    echo "[ERROR] Spanish ROM SHA1 mismatch: $actual_sha1" >&2
    exit 1
fi

echo "[BUILD] Building Pokered-es ROM and symbols..."
if git -C "$SOURCE" apply --unidiff-zero --reverse --check "$SOURCE_PATCH" >/dev/null 2>&1; then
    echo "[BUILD] Project menu changes already applied to Pokered-es."
elif git -C "$SOURCE" apply --unidiff-zero --check "$SOURCE_PATCH" >/dev/null 2>&1; then
    git -C "$SOURCE" apply --unidiff-zero "$SOURCE_PATCH"
    echo "[BUILD] Applied project menu changes to Pokered-es."
else
    echo "[ERROR] Cannot apply $SOURCE_PATCH to the initialized Pokered-es submodule." >&2
    echo "        Check that its commit matches the version documented in agents/." >&2
    exit 1
fi
make -C "$SOURCE" red
mkdir -p "$(dirname "$PATCHED_ROM")"
cp "$SOURCE/pokered.gbc" "$PATCHED_ROM"
echo "[BUILD] Using locally patched Pokered-es image: $PATCHED_ROM"

echo "[BUILD] Preparing Spanish entry-point annotations..."
python3 "$ROOT/tools/generate_pokered_es_annotations.py" \
    --symbols "$SOURCE/pokered.sym" --rom "$PATCHED_ROM" --output "$ANNOTATIONS"

echo "[BUILD] Generating the Spanish recompiled project..."
"$RECOMP" --config "$CONFIG" --symbols "$SOURCE/pokered.sym" \
    --annotations "$ANNOTATIONS"

echo "[BUILD] Compiling Pokémon Edición Roja..."
cmake -S "$ROOT/spanish/generated" -B "$ROOT/spanish/generated/build" -G Ninja
cmake --build "$ROOT/spanish/generated/build" --parallel
python3 "$ROOT/tools/create_bps_patch.py" \
    --source "$ROM" --target "$PATCHED_ROM" --output "$PATCH_FILE"
echo "[BUILD] Executable: $ROOT/spanish/generated/build/Pokemon_Edicion_Roja"
