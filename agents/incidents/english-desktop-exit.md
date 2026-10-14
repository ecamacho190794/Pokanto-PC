# English build: desktop exit options

**Date:** 2026-10-13  
**Goal:** bring the two Spanish desktop exit actions to the shared English
Red/Blue build without applying a Spanish patch to an English ROM.

## Implementation

- The English source is pinned as the `third_party/pokered` submodule at
  `af519899719f0754965776faac0e836a3b906e6d`.
- `patches/pokered-en-desktop-exit.patch` adds `QUIT GAME` to the title menu
  and `CLOSE GAME` to the pause menu. Closing from pause asks whether to save;
  choosing Yes calls `SaveGameData`. Both actions send the host `PK` exit
  signature.
- The English build assembles pristine Red and Blue from Pokered, verifies the
  provided Red ROM by SHA-1, and verifies the stock Blue image by CRC32 before
  building both patched images. It uses patched Red for recompilation and
  creates a BPS for each stock source image.
- The runtime uses Red's base patch for CRC32 `9F7FDD53` and looks for the
  Blue companion `Pokemon_Red_Blue-D6DA8A1A.bps` for CRC32 `D6DA8A1A`. The BPS
  generator checks the source identity and reconstructs the target to verify
  each patch.
- `scripts/apply-submodule-patches.sh` applies the shared runtime and launcher
  patches idempotently for fresh submodule checkouts.
- The Windows stock packaging path now goes through the same English build and
  includes both BPS files.

## Build verification

On macOS arm64, `./build.sh english all` completed successfully on 2026-10-13.
The Pokered Red output matched the provided ROM's SHA-1, Blue stock assembled
with CRC32 `D6DA8A1A`, and both BPS files self-verified. The native executable
and both BPS files were produced under `generated/build/`. The recompiler log
still contains `[ERROR] Undefined instruction` diagnostics from static analysis;
despite those diagnostics, ROM generation, native compilation/linking, and BPS
generation completed with exit code 0. This does not establish that every game
path works at runtime.

This is a build/artifact verification only. The game has not been launched
interactively after this port; confirm both menu actions, save/no-save choices,
Red and Blue startup, sound, and saved-game behavior manually.

The stock English executable only has BPS patches for stock Red and Blue.
Extended ROMs belong to their separate Extended build and should not be used
with this executable.
