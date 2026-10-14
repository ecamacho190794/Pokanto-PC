# Variantes por idioma

Cada subcarpeta de este directorio describe una compilación del juego. Los
archivos `variant.json` son el índice legible por herramientas: registran la
ROM esperada, sus CRC aceptados, catálogo del launcher y las entradas de
configuración/código específicas. `launcher_strings.h` contiene los textos que
ve la persona que usa el launcher; las claves deben mantenerse alineadas entre
idiomas.

## Compilar

Desde la raíz del proyecto:

```sh
./build.sh english   # también acepta: ./build.sh en
./build.sh spanish   # también acepta: ./build.sh es
```

La variante inglesa conserva sus comandos incrementales: `./build.sh english
game`, `regen`, `run`, `clean` y `all`. Su build completo requiere RGBDS y la
ROM Red stock exacta configurada en la raíz. Ensambla Red y Blue desde el
submódulo oficial fijado, recompila desde la imagen Red personalizada y genera
un BPS por cada CRC stock aceptado. Sin nombre de idioma, los comandos
históricos siguen apuntando a inglés. Para español se usa `./build.sh spanish`;
`./build-spanish.sh` se conserva como alias para atajos y documentación
anteriores.

## Añadir un idioma

1. Crea `languages/<código>/` con `variant.json`, `launcher_strings.h` y un
   `build.sh` ejecutable. El dispatcher de la raíz detecta automáticamente las
   carpetas que incluyen ese script.
2. Copia las claves del catálogo inglés y traduce sus valores; no cambies los
   nombres de las macros.
3. Apunta `variant.json` a la configuración de recompiler, extras, hooks de
   compilación y fuente de desensamblado pertinentes. Registra el hash/CRC de
   entrada verificado y limita el build a esa identidad.
4. Mantén los parches del juego en un archivo separado por idioma/versión y
   genera la ROM parcheada y su BPS localmente. No guardes ROMs, código C
   generado ni binarios en Git.
5. Conecta el catálogo y las opciones de compilación en el `game_build.cmake`
   de la variante. El runtime y el layout del launcher son compartidos; no
   dupliques esos fuentes para traducirlos.

El parche de ensamblador de cada ROM seguirá siendo específico: punteros,
longitudes de texto, espacios libres, símbolos, hashes y CRC cambian entre
traducciones. No se debe aplicar el parche español a otra ROM.
