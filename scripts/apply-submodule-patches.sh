#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"

apply_patch_once() {
    local submodule="$1"
    local patch_file="$2"

    if [[ ! -d "$submodule/.git" && ! -f "$submodule/.git" ]]; then
        echo "[ERROR] Submodule is not initialized: $submodule" >&2
        exit 1
    fi

    if git -C "$submodule" apply --unidiff-zero --reverse --check "$patch_file" >/dev/null 2>&1; then
        echo "[BUILD] Project patch already applied: ${patch_file#"$ROOT"/}"
    elif git -C "$submodule" apply --unidiff-zero --check "$patch_file" >/dev/null 2>&1; then
        git -C "$submodule" apply --unidiff-zero "$patch_file"
        echo "[BUILD] Applied project patch: ${patch_file#"$ROOT"/}"
    else
        echo "[ERROR] Cannot apply $patch_file to $submodule." >&2
        echo "        Verify the submodule revision and local changes." >&2
        exit 1
    fi
}

apply_patch_once "$ROOT/gb-recompiled" "$ROOT/patches/gb-recompiled-pokanto-runtime.patch"
apply_patch_once "$ROOT/recomp-ui" "$ROOT/patches/recomp-ui-pokanto-launcher.patch"
apply_patch_once "$ROOT/third_party/pokered-es" "$ROOT/patches/pokered-es-widescreen-objects.patch"
