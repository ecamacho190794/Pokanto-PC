# Pokanto PC: Pokémon Edición Roja en español

Versión del proyecto: **0.0.1 estable**. No hay release publicado.

Esta variante es independiente de la compilación inglesa. Usa los símbolos de
[`einstein95/pokered-es`](https://github.com/einstein95/pokered-es), el ROM
español aportado por el usuario y un ejecutable/configuración propios.

## Compilar

Desde la raíz del repositorio:

```sh
git submodule update --init --recursive
brew install rgbds
./build.sh recompiler
./build-spanish.sh
```

En Windows/Linux se requiere el RGBDS 1.0.1 usado por Pokered-es y las
dependencias nativas descritas en [`../agents/platform-builds.md`](../agents/platform-builds.md).
El script verifica que el ROM de entrada tenga SHA-1
`fc17c5b904d551b1b908054ccd1c493f755f832a`. Después reconstruye una imagen
local de Pokered-es con los cambios propios del proyecto en
`generated/Pokemon_Edicion_Roja_patched.gbc`; esa imagen se usa para generar el
código recompilado. También produce `generated/build/Pokemon_Edicion_Roja.bps`;
el launcher aplica ese parche a la ROM española original al iniciar y comprueba
que el resultado corresponda a esta compilación antes de cargar el juego. Deja
el BPS en la misma carpeta que el ejecutable.

El ejecutable queda en `spanish/generated/build/Pokemon_Edicion_Roja`. El ROM
de entrada para compilar se mantiene en `roms/Pokemon Edicion Roja.gb`; no se
incluye ni se modifica el archivo de ROM. Al iniciar, el ejecutable busca en su
propia carpeta archivos `.gb` y elige el primero, por nombre, cuyo CRC32 esté
aceptado por esta variante. El selector de ROM queda oculto. Si no encuentra
una ROM válida, muestra una alerta en español y se cierra. Por tanto, coloca la
ROM española válida junto al ejecutable.

## Componentes

- `pokemon_red_es.toml`: rutas y opciones para el análisis español.
- `extras.c`: validación del CRC32 español (`D8507D8A`) y nombre visible.
- `../build-spanish.sh`: valida la ROM original, aplica
  [`../patches/pokered-es-start-menu.patch`](../patches/pokered-es-start-menu.patch)
  al submódulo limpio, construye la versión local de Pokered-es, genera
  anotaciones y C, compila el ejecutable y crea el parche BPS requerido por el
  launcher.
- `../tools/generate_pokered_es_annotations.py`: convierte símbolos RGBDS en
  semillas de funciones, omitiendo etiquetas locales y nombres comunes de
  tablas/audio.
- `generated/`: archivos C/CMake derivados, símbolos/anotaciones locales y
  ejecutable. Se pueden regenerar con el script y están excluidos de Git porque
  incluyen datos derivados de la ROM y productos compilados.

## Estado y límites

La compilación arm64 de macOS terminó correctamente. La imagen ensamblada se
personaliza con cambios de este proyecto, así que ya no comparte el hash de la
ROM original; el ejecutable sigue validando esa ROM original al iniciar. La
salida del analizador aún informa 1,713 instrucciones sin decodificar en caminos
que llegan a bytes de datos; por ello, que el ejecutable
enlace no confirma que la partida completa sea jugable. Falta probar el arranque,
partida nueva, guardado/carga, combates y transiciones de mapas. No usar la
configuración inglesa `dispatch_misses.toml` para esta variante.

El launcher de la variante española busca un `.gb` con CRC aceptado junto al
ejecutable, sin mostrar selector. Consulta el flujo y su estado de verificación
en [`../agents/incidents/spanish-pokered-es.md`](../agents/incidents/spanish-pokered-es.md).
El menú principal también incluye `SALIR DEL JUEGO`, que cierra la aplicación
directamente sin una confirmación de guardado.
Durante la partida, la opción `CERRAR JUEGO` del menú de pausa pregunta si quieres
guardar. Sí guarda el estado actual antes de cerrar; No cierra sin guardar.
Su panel principal muestra sólo el estado de la ROM, región y archivo junto a
los controles de escala, pantalla completa, filtro lineal y modelo de pantalla;
el audio conserva los valores predeterminados del runtime y no ofrece controles
en el launcher. En el dashboard ancho, las tarjetas ROM y Player 1 ocupan una
columna y Pantalla la otra; en ventanas estrechas se muestran apiladas.
Los controles de teclado de Player 1 conservan las teclas secundarias WASD/J/K
predeterminadas además de las teclas configuradas; se revirtió la prueba que las
desactivaba porque las flechas no respondieron en macOS.
