# Variante española: Pokered-es

**Fecha:** 2026-10-13
**Síntoma/objetivo:** generar un ejecutable nativo independiente para
`Pokemon Edicion Roja.gb`, sin aceptar el ROM inglés por error.

## Evidencia

- El ROM español local tiene SHA-1
  `fc17c5b904d551b1b908054ccd1c493f755f832a` y CRC32 `D8507D8A`.
- La imagen de Pokered-es que usa el recompilador incluye ahora cambios propios
  del proyecto, por lo que su hash ya no coincide con la ROM original.
- La cabecera del ROM español declara MBC5; el runtime ya soporta MBC5.
- La primera pasada con el análisis agresivo incluyó miles de bytes de datos
  como si fueran instrucciones. Se desactivó esa exploración y se generan
  entradas desde `pokered.sym`, omitiendo símbolos locales y etiquetas conocidas
  de datos/audio.
- En la última generación, el recompiler registró 1,713 instrucciones sin
  decodificar en algunos caminos de ROM. El ejecutable se enlaza, pero esto no
  demuestra que el flujo entero del juego se haya recompilado correctamente.

## Implementación

- `third_party/pokered-es` está fijado como submódulo al commit
  `6caaf44d56f87db76cbf72c54afd5ec4af8c2fa3`.
- `spanish/pokemon_red_es.toml` define rutas/opciones separadas. Está fuera de la
  raíz para evitar que se cargue por accidente el `dispatch_misses.toml` inglés.
- `spanish/extras.c` acepta únicamente CRC32 `D8507D8A`; `spanish/generated/`
  tiene su propio código, CMake y ejecutable. No se enlazan los mocks/overlays
  ingleses, cuyos offsets todavía no se han portado.
- `tools/generate_pokered_es_annotations.py` crea anotaciones basadas en
  símbolos del build RGBDS.
- `build-spanish.sh` verifica el SHA-1 del ROM local, aplica
  `patches/pokered-es-start-menu.patch` al submódulo, reconstruye la imagen
  personalizada de Pokered-es, genera C, compila el binario y crea junto a él
  `Pokemon_Edicion_Roja.bps` para transformar la ROM española original en la
  misma imagen usada para generar el código.
- Guía de uso: [`../../spanish/README.md`](../../spanish/README.md). Dependencias
  por plataforma: [`../platform-builds.md`](../platform-builds.md).

## Verificación

`./build-spanish.sh` finalizó en macOS arm64 y produjo el ejecutable Mach-O
`spanish/generated/build/Pokemon_Edicion_Roja` y su parche BPS. Se validó el
SHA-1 de la ROM original durante el build, el enlace del ejecutable y que el
parche BPS reconstruya exactamente la imagen personalizada. La imagen modificada
tiene un hash distinto de la original. Aún hace falta abrir el juego y confirmar
el menú, la partida, imagen, guardado/carga y progreso; el build no sustituye
esas comprobaciones manuales ni resuelve las instrucciones que el analizador
marca como inválidas.

## Diagnóstico futuro

Si el ejecutable se cierra al iniciar o se congela, revisar primero la salida
del recompiler para `Undefined instruction`, `Unresolved JP HL` y dispatch
misses. No reutilizar `pokemon_red_blue.toml`, las semillas de
`dispatch_misses.toml` ni los overlays ingleses sin confirmar sus direcciones
contra el `.sym` español. Probar al menos: inicio de partida, movimiento en
Pueblo Paleta, combate, transición de mapa, guardado y carga.

## Incidente: bloqueo en el primer frame por cargar la ROM sin parche

El 13-oct-2026 el usuario informó que el ejecutable español abría pero se
congelaba en el primer frame, sin audio; el ejecutable inglés funcionaba.

### Causa confirmada

La generación española usa `Pokemon_Edicion_Roja_patched.gbc` como imagen base,
y el C generado configura `Pokemon_Edicion_Roja.bps` para adaptar el dump
original al iniciar. Sin embargo, `spanish/game_build.cmake` no definía
`GBRECOMP_APPLY_ROM_PATCH`. `launcher.c` solo entra a `resolve_or_patch()` bajo
ese define. Como `spanish/extras.c` acepta el CRC del dump original, el runtime
podía aceptar y cargar el archivo sin aplicarle el BPS: el código recompilado y
los datos/direcciones de ROM quedaban desincronizados. Esto concuerda con el
bloqueo reportado; antes de la corrección no había evidencia de un error de
shader ni de una caída del proceso.

Además, `spanish/game_build.cmake` tampoco definía
`GBRECOMP_HOST_EXIT_SIGNAL`, necesario para que el runtime consuma la firma `PK`
escrita por las opciones españolas de salida. Este segundo define no explica el
bloqueo inicial, pero sí es necesario para que la función de cerrar el juego
documentada arriba opere.

### Cambios y verificación

- Se añadieron `GBRECOMP_APPLY_ROM_PATCH=1` y
  `GBRECOMP_HOST_EXIT_SIGNAL=1` a `spanish/game_build.cmake`.
- Se regeneró la configuración y compiló el ejecutable español en macOS arm64.
- Se verificó que el `build.ninja` configurado incluya los dos defines y que el
  BPS local transforma el ROM original en la imagen personalizada esperada.

La compilación y la validación del artefacto no sustituyen la prueba interactiva.
Queda pendiente volver a ejecutar el binario corregido y confirmar que supera el
primer frame, reproduce sonido y que las dos opciones de salida cierran el juego.

## Lanzador: selección fija de ROM

La variante española compila `GBRECOMP_POKEMON_ES` solo en
`spanish/game_build.cmake`.
Antes de mostrar el launcher, `launcher_ui_seam.c` busca archivos `.gb` junto al
ejecutable y acepta el primero, ordenado por nombre, cuyo CRC esté en la lista
de `spanish/extras.c`. Actualiza `rom.cfg` con esa ruta y oculta el botón de
cambio de ROM. Si no encuentra una ROM válida, presenta una alerta SDL en
español y el runtime termina con código 1. El flujo inglés no define la macro y
conserva su selector.

La interfaz principal del launcher para esta variante muestra textos en
español. Después de cambiar este flujo, `./build-spanish.sh` terminó con éxito
y enlazó el ejecutable en macOS arm64. No se abrió el juego: queda pendiente
confirmar visualmente el inicio con una ROM junto al ejecutable y la alerta al
probar desde una carpeta sin ROM.

## Lanzador: panel principal compacto

La variante española no muestra el arte de caja: su tarjeta deja visible el
estado de verificación (marca verde cuando coincide el CRC aceptado), región y
nombre de archivo bajo el título ROM. En el dashboard ancho, ROM y Player 1
quedan apilados en la columna izquierda, con Pantalla en la columna derecha.
En ventanas estrechas se apilan las tres tarjetas. El botón de Ajustes se
oculta. Escala de ventana, pantalla completa, filtro lineal y modelo de pantalla
aparecen en la tarjeta Pantalla; sus etiquetas y opciones están en español.
El panel de audio no se presenta y la variante fija sus valores a los
predeterminados conocidos: SDL a 44,100 Hz y volumen al 100 %. Los cambios
siguen limitados por `GBRECOMP_POKEMON_ES`; no afectan el launcher inglés.

La compilación incremental de CMake terminó correctamente en macOS arm64
después de estos cambios. No se abrió el ejecutable, así que falta confirmar
visualmente el ajuste en varios tamaños de ventana y revisar que la marca verde
aparezca al cargar la ROM junto al binario.

## Incidente: opciones del título glitcheadas

Después de añadir `SALIR DEL JUEGO`, el usuario informó que las otras opciones
del título aparecían como `Cent. de cambio` y `Coliseo`, y que al elegirlas el
juego se glitcheaba. La causa era que el código recompilado usaba las direcciones
de la imagen personalizada de Pokered-es, pero `launcher_load_rom()` seguía
cargando los datos de juego desde la ROM original seleccionada. Las lecturas de
texto/datos quedaban desalineadas respecto al código y las direcciones nuevas.

La solución genera `Pokemon_Edicion_Roja.bps` desde la ROM original verificada
hacia `Pokemon_Edicion_Roja_patched.gbc`. Al arrancar, el launcher español aplica
ese BPS a la ROM seleccionada, verifica que la salida coincida con el SHA-256
esperado por el build y entrega esa imagen al runtime. La resolución está bajo
`GBRECOMP_POKEMON_ES`; el launcher inglés mantiene su flujo actual. El parche se
guarda junto al ejecutable y debe distribuirse con él. Si falta o no corresponde
a la ROM/build, el launcher rechaza la ROM en lugar de cargar datos incompatibles.

Verificación de esta corrección: `./build-spanish.sh` terminó en macOS arm64,
compiló `launcher.c` y enlazó el juego. `tools/create_bps_patch.py` confirmó que
el BPS generado reproduce byte por byte la imagen personalizada. No se abrió el
juego tras este arreglo; falta que el usuario confirme el menú y la selección de
las tres opciones. También se solicitó una captura del menú y saber si la partida
guardada era anterior al cambio; queda pendiente recibir esos datos.

## Controles Player 1: etiquetas e input exacto

En la tarjeta Player 1 de la variante española, `Keyboard`, `Configure` y
`Connected` se muestran como `Teclado`, `Configurar` y `Conectado`; también se
traduce la opción de teclado del selector y el estado sin asignar.

El editor del launcher guarda las teclas de juego en la ranura primaria
(`keyboard.<acción>.0`). Se probó desactivar las asignaciones secundarias para
forzar exclusivamente las teclas elegidas, pero las flechas todavía no
respondieron en macOS. Se revirtió ese cambio: el runtime vuelve a conservar y
aceptar la ranura secundaria predeterminada (WASD y J/K), además de la primaria.
Esto restaura el control que funcionaba antes, aunque no corrige el motivo por
el que las flechas no generan movimiento en este entorno.

Verificación del rollback: la compilación incremental de macOS terminó y
actualizó `spanish/generated/build/Pokemon_Edicion_Roja`. El compilador mostró
advertencias existentes de OpenGL deprecado y comentarios; no hubo errores.
Falta confirmar en una partida que WASD vuelva a mover al personaje.

## Menú principal: salir del juego

Se añadió `SALIR DEL JUEGO` después de `OPCIONES` para partidas nuevas y para
partidas con archivo guardado. Se ampliaron las cajas del menú para mostrar la
tercera opción, sin cambiar las rutas de Juego nuevo, Continuar u Opciones. Al
seleccionarla, el juego cierra directamente, sin confirmación de guardado.

La rutina Pokered-es escribe la firma `PK` en los registros no usados `FF7E` y
`FF7F`; el runtime español la reconoce en `gb_platform_poll_events()` y termina
el bucle SDL. Esta ruta se compila solo con `GBRECOMP_POKEMON_ES`, así que el
ejecutable inglés no cambia.

`build-spanish.sh` copia la imagen ensamblada personalizada a
`spanish/generated/Pokemon_Edicion_Roja_patched.gbc` y la usa tanto para generar
anotaciones como para recompilar el juego. La ROM original del usuario sigue
siendo la identidad requerida para el launcher; su SHA-1 se verifica antes de
construir.

Verificación: `./build-spanish.sh` terminó y enlazó el ejecutable macOS arm64.
El código generado contiene la rutina que escribe la señal de cierre. Falta
abrir una partida y comprobar visualmente la tercera opción y que seleccionarla
cierre la ventana.

Rollback solicitado: el usuario confirmó que la opción directa de salida ya
funcionaba antes de añadir la confirmación de guardado. Se revirtió esa
confirmación y el puente host alternativo, restaurando `SALIR DEL JUEGO`, la
firma `PK` de dos bytes y la ruta que ya había funcionado tras corregir el
desajuste de ROM. La salida vuelve a ser inmediata y no guarda antes de cerrar.
Se recompiló la variante española y se regeneró el parche BPS. Pendiente de
confirmación del usuario de que esta versión conserva el cierre del proceso.

## Menú de pausa: salir con confirmación de guardado

La petición posterior es distinta de la salida de la pantalla inicial: el
usuario quiere salir desde el menú de pausa durante la partida, donde aparecen
`Pokémon` y `Objetos`. En `home/start_menu.asm`, la última opción se llama
`CERRAR JUEGO` y muestra la pregunta estándar `¿Quieres GUARDAR el juego?` con Sí/No.
Sí invoca `SaveGameData` para guardar el estado actual; No omite el guardado.
Ambas respuestas escriben la firma `PK` en `FF7E`/`FF7F` y cierran mediante el
flujo SDL existente. Para que quepa la etiqueta, el recuadro conserva su borde
derecho y altura, se ensancha hacia la izquierda y la lista/cursor se desplazan
cinco columnas a la izquierda. La opción de salida del título permanece directa
y sin confirmación.

Verificación de implementación: `./build-spanish.sh` terminó en macOS arm64,
compiló el runtime y regeneró el parche BPS (27,080 bytes). El build confirma
ensamblado RGBDS, generación C, enlace y reproducción de la ROM parcheada. Falta
probar en partida las respuestas Sí y No, confirmar el cierre del proceso y
verificar que el guardado persista al reiniciar.

Actualización de etiqueta: el usuario pidió un texto más claro que `SALIR`.
La opción de pausa ahora dice `CERRAR JUEGO`; se amplió el recuadro hacia la
izquierda y se desplazaron la lista y el cursor para conservar el borde derecho.
`./build-spanish.sh` terminó correctamente en macOS arm64 y generó el BPS
actualizado (27,087 bytes). La comprobación visual en juego aún está pendiente.

Actualización de texto: a petición del usuario, la opción `OPCIÓN` del mismo
menú de pausa cambió a `OPCIONES`. El ancho actual del recuadro ya admite la
etiqueta sin modificar más su geometría. `./build-spanish.sh` terminó
correctamente en macOS arm64 y generó el BPS actualizado (27,089 bytes). La
comprobación visual de la etiqueta dentro del juego queda pendiente.
