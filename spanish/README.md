# Pokémon Edición Roja (español)

La variante española comparte el runtime y el launcher con inglés, pero conserva
su configuración de recompilación, análisis de símbolos, ROM base, identidad y
parche de ensamblador propios. El catálogo del launcher está en
[`../languages/es/launcher_strings.h`](../languages/es/launcher_strings.h), y
el manifiesto de la variante en [`../languages/es/variant.json`](../languages/es/variant.json).

## Compilar

Desde la raíz, inicializa los submódulos e instala las herramientas comunes y
RGBDS 1.0.1 requerido por Pokered-es:

```sh
git submodule update --init --recursive
brew install cmake ninja sdl2 rgbds
./build.sh spanish
```

En Windows y Linux, consulta los paquetes y las limitaciones conocidas en
[`../agents/platform-builds.md`](../agents/platform-builds.md). El comando
`./build-spanish.sh` sigue funcionando como alias legado.

El build verifica el SHA-1
`fc17c5b904d551b1b908054ccd1c493f755f832a` de la ROM de entrada
`roms/Pokemon Edicion Roja.gb`. Luego aplica
[`../patches/pokered-es-start-menu.patch`](../patches/pokered-es-start-menu.patch)
al submódulo limpio, ensambla la ROM parcheada para generar el código y el BPS,
y compila el ejecutable en `spanish/generated/build/Pokemon_Edicion_Roja`.
El parche BPS se coloca junto al ejecutable para que el runtime adapte una copia
local de la ROM original antes de iniciar. No añade ni altera la ROM de entrada.

Al iniciar, busca en el directorio del ejecutable archivos `.gb` y elige el
primero por nombre cuyo CRC32 aceptado sea `D8507D8A`. No muestra un selector;
si falta una ROM válida, presenta una alerta en español y cierra el juego. Coloca
la ROM legal junto al ejecutable y distribuye el `.bps` que genera el build con
la aplicación.

## Datos exclusivos de esta variante

- [`pokemon_red_es.toml`](pokemon_red_es.toml): opciones y regiones analizadas.
- [`extras.c`](extras.c): CRC32 y nombre del juego.
- [`game_build.cmake`](game_build.cmake): catálogo español y define del runtime.
- `../patches/pokered-es-start-menu.patch`: ajustes de los menús y señal de
  salida propia de esta versión del juego.
- `../tools/generate_pokered_es_annotations.py`: deriva semillas de funciones
  desde los símbolos RGBDS.
- `generated/`: código recompilado, ROM parcheada, BPS y binarios locales; todo
  se regenera y permanece fuera de Git.

Los textos del juego viven en la ROM y deben modificarse mediante un parche
específico de esta fuente. Los textos del launcher se mantienen aparte para no
mezclar traducción de UI con el parche binario/ensamblador del juego.
