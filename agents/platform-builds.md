# Compilación por plataforma

Esta nota describe el proyecto Pokémon (raíz del repositorio) y su submódulo
`gb-recompiled`. Separa el build del generador (`gbrecomp`) de la generación del
código del juego y del ejecutable final. El ROM se requiere para generar el
código; cada usuario debe aportar su propia copia legal.

## Requisitos compartidos

- Git con submódulos inicializados (`gb-recompiled`, `recomp-ui`).
- CMake 3.20+, Ninja, compilador C/C++ moderno, SDL2 de desarrollo.
- En la raíz: `./build.sh all` compila el generador, genera `generated/` a partir
  de `pokemon_red_blue.toml` y compila el juego. `./build.sh run` construye y
  ejecuta. `./build.sh game` hace build incremental; `regen` regenera C.
- El archivo stock configurado es
  `roms/Pokemon Red (UE) [S][!].gb`. No versionar ni distribuir ROMs.
- Los artefactos en `generated/` son locales y regenerables. El ejecutable final
  se escribe en `generated/build/`.

## macOS

### Dependencias

```sh
brew install cmake ninja sdl2
```

Usa Apple Clang/Xcode Command Line Tools. El build se probó en Apple Silicon
arm64 con macOS SDK, Homebrew SDL2 compat, CMake y Ninja.

### Particularidades

- El ejecutable es Mach-O del host (arm64 en Apple Silicon). Para Intel, el
  compilador debe generar x86_64; para una app universal se necesitan dos builds
  o configurar los arquitectures de CMake.
- El runtime usa OpenGL de macOS en lugar de GLES. Los shaders escritos para
  GLES 1.00 se convierten a GLSL 1.50 en el código macOS.
- `launcher.c` usa `SDL_GetBasePath()` para guardar y leer `rom.cfg` junto al
  ejecutable, igual que el launcher previo al juego. Esto evita depender del
  directorio actual de Terminal/Finder.
- Ejecutar `./build.sh all`; al primer inicio, elegir el ROM aceptado por el
  build. Verifica el CRC del archivo si aparece una alerta de ROM inválido.
- La variante española cierra desde `SALIR DEL JUEGO` en la pantalla inicial y
  desde `CERRAR JUEGO` en el menú de pausa; en partida ofrece guardar antes de cerrar.
  Ambos usan la señal de salida SDL y deben verificarse en cada plataforma.
- Los helpers de empaquetado `scripts/package.sh` / `scripts/build.sh` están
  orientados al flujo Windows/MSYS2 y no crean por sí solos un `.app` de macOS.
- Para la variante española instala además RGBDS: `brew install rgbds`. Pokered-es
  fija RGBDS 1.0.1. Después ejecuta `./build.sh recompiler` y
  `./build-spanish.sh`; este último genera una imagen personalizada de
  Pokered-es con las opciones específicas del proyecto.

### Verificación conocida

El 13-oct-2026 se compiló `generated/build/Pokemon_Red_Blue` como Mach-O arm64.
Tras corregir el formato GLSL, la ubicación de `rom.cfg` y añadir un VAO para el
pipeline en contexto OpenGL core, la compilación sigue terminando correctamente.
El usuario informó audio sin imagen antes del último ajuste. Queda por confirmar
manualmente la imagen con el nuevo binario; el incidente está documentado en
[`incidents/macos-glsl-y-romcfg.md`](incidents/macos-glsl-y-romcfg.md).

## Linux

En Debian/Ubuntu:

```sh
sudo apt install build-essential cmake ninja-build libsdl2-dev
```

En Fedora instala `gcc-c++ cmake ninja-build SDL2-devel`; en Arch instala
`base-devel cmake ninja sdl2`. Se requiere un entorno gráfico compatible con SDL
y OpenGL. En Linux el runtime conserva el backend GLES 2 y enlaza OpenGL/Mesa.
Ejecuta `./build.sh all`, después `./build.sh run`.

La compilación de Linux no se ha verificado en este checkout. Si CMake no detecta
SDL2, revisa que estén instalados los paquetes de desarrollo y limpia/configura
de nuevo el directorio de build afectado.

La variante española requiere además `make`, `git`, `python3` y RGBDS 1.0.1
según Pokered-es/RGBDS. Inicializa los submódulos con
`git submodule update --init --recursive`; después ejecuta
`./build.sh recompiler` y `./build-spanish.sh`. El script genera un parche BPS
con Python estándar y lo coloca junto al ejecutable; distribuye ese archivo con
el binario español para que el launcher pueda adaptar la ROM original al código
recompilado. Este flujo español fue compilado en macOS; en Linux todavía no se
ha verificado y en Windows requiere RGBDS disponible en el PATH de MinGW64 (o
generar antes los archivos `.gbc` y `.sym` con WSL).

## Windows

El flujo documentado usa **MSYS2 MinGW64**, no MSVC. Instala MSYS2 y desde la
terminal MinGW64 instala:

```sh
pacman -S --needed mingw-w64-x86_64-gcc mingw-w64-x86_64-cmake \
  mingw-w64-x86_64-ninja mingw-w64-x86_64-SDL2 make python
```

Abre la shell MinGW64, entra a la raíz del repo y ejecuta `./build.sh all`.
`build.sh` detecta MSYS/MINGW/CYGWIN para usar los ejecutables `.exe`. El runtime
usa GLES mediante ANGLE (`GLESv2`, `EGL`); la distribución Windows también debe
colocar las DLL de ANGLE necesarias junto al ejecutable. El flujo de empaquetado
actual usa PowerShell y runtime DLL discovery de MSYS2.

Windows/MSYS2 es el entorno descrito originalmente por este repositorio, pero
esta revisión del flujo portable no se volvió a compilar en Windows. No asumir
que el resultado macOS prueba Windows o Linux.

Para la variante española instala RGBDS 1.0.1 para Windows y agrega sus
ejecutables (`rgbasm`, `rgbfix`, `rgbgfx`, `rgblink`) al PATH de MinGW64.
Inicializa los submódulos y ejecuta `./build.sh recompiler` y
`./build-spanish.sh` desde esa shell. Python 3 estándar genera el BPS al final
del build; incluye `Pokemon_Edicion_Roja.bps` junto al ejecutable en la
distribución. Si RGBDS no se puede ejecutar desde
MinGW64, genera `pokered.gbc` y `pokered.sym` con WSL y deja ambos archivos en
`third_party/pokered-es` antes de continuar en MinGW64.

## Diagnóstico rápido

- Error de CMake sin `generated/`: primero ejecuta `./build.sh all`, con el ROM
  en la ruta exacta de la configuración.
- `SDL2 not found`: instala la biblioteca de desarrollo de la plataforma; no
  basta con el runtime SDL instalado por el sistema.
- Para una configuración contaminada por otro compilador/arquitectura, elimina
  solo el directorio generado de build correspondiente y vuelve a configurar.
- Consulta `incidents/` antes de reabrir un fallo ya resuelto.
