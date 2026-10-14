# Pokanto PC

**Versión actual: 0.0.1 estable.** No se ha publicado un release; esta versión
identifica el estado base de Pokanto PC. Este fork está basado en
[`mstan/PokemonRedAndBlueRecomp`](https://github.com/mstan/PokemonRedAndBlueRecomp).

A static recompilation of **Pokemon Red** and **Pokemon Blue** (Game Boy) for native PC.

This project uses [gb-recompiled](https://github.com/mstan/gbrecompiled) (forked from [arcanite24/gb-recompiled](https://github.com/arcanite24/gb-recompiled)) to translate the original Game Boy machine code into C, which is then compiled to a native x64 executable. The Game Boy's PPU, APU, and memory mapper are handled by the gb-recompiled runtime library.

[![Pokemon Red/Blue Recompiled - Demo](https://img.youtube.com/vi/pEgJCTf7kgY/0.jpg)](https://www.youtube.com/watch?v=pEgJCTf7kgY)

## Status

**Pokanto PC v0.0.1 is the stable local baseline for the Spanish build.** It has
not been published as a release. The Spanish executable has been built and
used on macOS; Windows and Linux instructions are documented but those builds
have not yet been verified. The inherited English Red/Blue branch remains the
upstream project's early working prototype.

- The game runs and is playable with both Red and Blue ROMs
- Some animations may lag or chug slightly (e.g., certain battle intro spirals)
- Minor visual glitches may occur in edge cases
- Code paths not yet discovered by the static analyzer will fall back to an interpreter — this works but is slower than recompiled code
- Audio works but may stutter briefly during animation-heavy scenes
- No link cable support

If you encounter a crash or a new interpreter fallback, please open an issue with the address logged to the console.

## Extended Edition (Gen 2 Graft)

Alongside the faithful **Stock** build, there is an **Extended** build that
back-ports the full **Johto Pokédex — 100 new Pokémon (#152–251)** from
[pret/pokecrystal](https://github.com/pret/pokecrystal) into the Gen 1 engine,
bringing Red and Blue to the complete **National Dex #1–251**, plus a batch of
Gen 2 moves and the real **Dark/Steel** types. Sprites use **native 48×48 back
sprites** for the grafted mon (no blocky 2× upscale). All of this is produced by
editing decomp **source** (`../PokemonYellowDecomp/inject_red.py` injecting
[pret/pokered](https://github.com/pret/pokered)) and reassembling a real ROM —
not by binary-patching a `.gbc`.

This gives a **bifurcation** of four packages — `{Red, Blue} × {Stock, Extended}`
— served by two recompiled exes (one per variant; each runs both games via CRC):

| Package | Exe | ROM |
|---|---|---|
| `Pokemon_Red_Stock`     | `Pokemon_Red_Blue.exe`     | stock Red |
| `Pokemon_Blue_Stock`    | `Pokemon_Red_Blue.exe`     | stock Blue |
| `Pokemon_Red_Extended`  | `Pokemon_Red_Extended.exe` | Gen 2 Red |
| `Pokemon_Blue_Extended` | `Pokemon_Red_Extended.exe` | Gen 2 Blue |

### Release Packaging

```bash
scripts/build.sh stock       # recompile stock exe + package Red/Blue Stock zips
scripts/build.sh extended    # inject Gen2, build both ROMs, recompile, package Extended zips
# or package an already-built variant directly:
scripts/package.sh <red|blue> <stock|extended> [version]
```

Each zip is self-contained (exe + auto-bundled runtime DLLs + `rom.gb` + `rom.cfg`
+ `run.bat`) and lands in `dist/` (gitignored). The zips bundle a ROM, so they
are **private/personal artifacts — do not distribute**.

## Quick Start

### Pre-built Release

Pokanto PC v0.0.1 does not have a published release. Build from source using
the instructions below and provide your own ROM.

### Building from Source

Requires CMake 3.20+, Ninja, SDL2 development files, and a C/C++ compiler. The
project builds natively for macOS, Linux, and Windows (on Windows, use the
MSYS2 MinGW64 shell and install `mingw-w64-x86_64-cmake`,
`mingw-w64-x86_64-ninja`, `mingw-w64-x86_64-SDL2`, and the MinGW GCC toolchain).
On macOS, install the prerequisites with Homebrew:

```sh
brew install cmake ninja sdl2
```

On Debian/Ubuntu Linux:

```sh
sudo apt install cmake ninja-build libsdl2-dev build-essential
```

```bash
git clone --recursive https://github.com/ecamacho190794/Pokanto-PC.git
cd Pokanto-PC
cp /path/to/your-pokemon-rom.gb roms/
./build.sh english all   # Full English build (ROM assembly + code gen + compile)
./build.sh run   # Build + launch
```

For the stock build, name the ROM `roms/Pokemon Red (UE) [S][!].gb` as
configured in `pokemon_red_blue.toml`; the English build checks its identity.
You must provide your own legally obtained ROM; it is not included in this
repository. RGBDS is also required to assemble the patched English Red/Blue
images from the pinned Pokered source. Keep both generated BPS files next to
the executable and the selected stock `.gb` ROM; the launcher chooses the Red
or Blue patch by CRC. The executable uses the host platform's native format
(for example, Mach-O on macOS).

Build commands:
- `./build.sh all` — Full rebuild (recompiler + regenerate + compile)
- `./build.sh game` — Incremental compile only
- `./build.sh regen` — Regenerate C code from ROM
- `./build.sh bank 00 03` — Regenerate + rebuild specific banks
- `./build.sh run` — Build + launch

### Compilación por idioma

El flujo de idioma se unifica desde el punto de entrada raíz. Las variantes
viven bajo [`languages/`](languages/) y se eligen con `./build.sh english` o
`./build.sh spanish`. Cada variante define su `variant.json`, su
`launcher_strings.h` y su script de build, pero comparte el launcher y el
runtime del proyecto; un cambio del launcher o del cierre del juego se aplica a
la lógica común y no se duplica por idioma.

El launcher comparte diseño y comportamiento: busca una ROM `.gb` válida junto
al ejecutable, muestra una alerta si falta, y presenta la ROM de forma compacta
con los ajustes de pantalla en el panel principal. Los textos se toman del
catálogo de cada idioma. El build español conserva su parche específico de
Pokered-es, pero el flujo general sigue siendo el mismo. Consulta
[`languages/README.md`](languages/README.md), [`spanish/README.md`](spanish/README.md)
y las notas de [`agents/`](agents/).

The English title menu includes `QUIT GAME`; the pause menu includes
`CLOSE GAME` and asks whether to save before exiting. These options are
assembled into both English Red and Blue images. The build and BPS verification
are documented in
[`agents/incidents/english-desktop-exit.md`](agents/incidents/english-desktop-exit.md).

## Controls

| GB Button | Keyboard |
|-----------|----------|
| D-Pad     | Arrow keys |
| A         | Z |
| B         | X |
| Start     | Enter |
| Select    | Tab |

| Hotkey | Action |
|--------|--------|
| TAB (hold) | Turbo (fast-forward) |

## How It Works

This is a **static recompiler**, not an emulator. The original SM83 (Game Boy CPU) machine code is translated to C at build time, then compiled to native x64. At runtime, the executable loads the original ROM file for its data (graphics, maps, text, Pokemon stats, etc.) while executing the recompiled native code.

Red and Blue share identical code layout — only data tables differ (Pokemon availability, title screen graphics, etc.). A single recompiled build accepts either ROM at runtime via CRC32 validation.

When the recompiler encounters a code path it didn't discover during static analysis, it falls back to an interpreter. These fallback addresses can be added to the configuration file (`pokemon_red_blue.toml`) to be included in the next build.

### Project Structure

- `pokemon_red_blue.toml` — Recompiler configuration (entry points, data regions, valid CRCs)
- `build.sh` — Build script (regen, compile, run)
- `generated/` — Auto-generated C code from the recompiler (not committed)
- `gb-recompiled/` — Framework submodule ([mstan/gbrecompiled](https://github.com/mstan/gbrecompiled))
- `INITIATIVE.md` — Tracked rendering and audio improvement work

## Credits

- **[arcanite24/gb-recompiled](https://github.com/arcanite24/gb-recompiled)** — The original static recompilation framework that this project is built on. All recompiler and runtime code is derived from this project.
- **[pret/pokered](https://github.com/pret/pokered)** — The pokered disassembly project, used as a reference for entry points and symbol information.

## Known Limitations

- Some animation-heavy scenes (e.g., certain battle intro effects) may experience frame drops
- Audio may stutter briefly during heavy rendering
- Undiscovered code paths fall back to interpreter (logged to console)
- No link cable or printer support
- Only tested with US/Europe ROM versions

## Legal

This project does not include any Nintendo copyrighted material. You must provide your own legally obtained Pokemon Red or Blue ROM file. The generated C code is not committed to this repository.

---

<p align="center">
  <sub><b>R.A.I.D. — Retro AI Development</b> · a Discord for AI-assisted retro reverse-engineering, decomp &amp; recomp</sub>
</p>

<p align="center">
  <a href="https://discord.gg/Ad9BwSzctP"><img src=".github/raid-discord.png" alt="Join the Retro AI Development (R.A.I.D.) Discord" width="200"></a>
</p>
