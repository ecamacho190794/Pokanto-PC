# Opciones de relación de aspecto en el launcher inicial

Los perfiles Game Boy y Game Boy Color exponen en el launcher inicial una
selección de relación de aspecto: Original, 4:3, 16:9, 16:10 y 21:9. La
selección usa la lista de etiquetas de aspecto ya soportada por recomp-ui; el
nombre de la fila se localiza como “Aspect Ratio” o “Relación de aspecto” en
los catálogos inglés y español.

El seam guarda el índice en `video.aspect_index` de `runtime_prefs.ini`. El
runtime solicita un framebuffer de 160 px para Original, 192 px para 4:3,
256 px para 16:9, y 230 px para 16:10; el PPU conserva los 144 px verticales y
los píxeles originales, por lo que los modos ampliados muestran más escena a
los lados en vez de estirar la imagen. En el overworld, los márgenes usan las
columnas vecinas preparadas por Pokémon y, después, el tilemap circular y VRAM,
con los registros SCX/SCY del viewport; combates y estados sin mapa válido
muestran márgenes negros. El contenido
queda limitado al máximo del PPU (256×144): la opción
21:9 solicita ese modo máximo y, por tanto, actualmente ofrece el mismo campo
visible que 16:9, no 21:9 real. Esta ampliación de Pokémon genera el fondo;
los sprites conservan su comportamiento y límites actuales.

En modo ventana, el multiplicador se aplica al tamaño del framebuffer
efectivamente renderizado. En pantalla completa, el viewport conserva esa
proporción y se centra con barras si la pantalla no coincide. Los bordes SGB o
personalizados mantienen la proporción original de su marco, ya que el arte del
borde tiene dimensiones fijas. `Original` conserva el comportamiento
pixel-perfect anterior, salvo cuando está activa una vista extendida solicitada
por la preferencia runtime existente.

Las etiquetas de aspecto por juego se declaran en
`../recomp-ui/src/consoles/gb/gb_profile.h`; el parche persistente que las lleva
a los builds está en `../patches/recomp-ui-pokanto-launcher.patch`. La lectura y
persistencia del valor y el viewport están en el runtime, con sus cambios
persistentes en `../patches/gb-recompiled-pokanto-runtime.patch`.

La validación compartida del estado de mapa está en
`../pokemon_extended_view.h`; `../extras.c` y `../spanish/extras.c` aportan las
direcciones RAM correspondientes a cada ROM. No se agranda el buffer
superpuesto `wSurroundingTiles` ni se cambian datos serializados. La petición de
ancho del launcher, el viewport y su persistencia están en el parche runtime;
las etiquetas se transportan mediante `../patches/recomp-ui-pokanto-launcher.patch`.

La validez del mapa y sus coordenadas se capturan una vez por cuadro en LY 0.
Al entrar a un mapa o cambiar el origen/desplazamiento por tiles del viewport, se inicializan las celdas laterales del
tilemap circular a partir del mapa de bloques y los datos del tileset en ROM;
después el juego y el PPU vuelven a usar únicamente VRAM para que las orillas
sigan la misma animación de scroll que el viewport. Las direcciones RAM por ROM están en `../extras.c` y
`../spanish/extras.c`; la lógica compartida está en `../pokemon_extended_view.h`.

La compilación de ambas variantes terminó correctamente con
`cmake --build generated/build --parallel` y
`cmake --build spanish/generated/build --parallel`. También se verificó que el
parche runtime se aplique desde un worktree limpio.

## Tiles laterales que brincan al caminar (14-oct-2026)

El primer renderer reconstruía cada tile extra desde el mapa de bloques y el
tileset de la ROM. Esos datos describen la posición lógica que Pokémon ya está
cargando, mientras el viewport nativo presenta el tilemap circular de VRAM
sincronizado con SCX/SCY y con las transferencias por cuadro. Durante una
animación de paso, ambas fuentes podían quedar en fases distintas: el interior
se veía fluido y las columnas añadidas brincaban.

El primer intento de precarga desde `wSurroundingTiles` fue inválido: esa RAM se
superpone con `wTileMap`, y el juego ya la ha sobrescrito cuando se dibujan los
márgenes. Ahora, al detectar un mapa nuevo, el renderer reconstruye los IDs
vecinos directamente desde `wOverworldMap` y el puntero de bloques del tileset.
Antes de escribirlos, verifica que la reconstrucción coincida con los 20×18 IDs
del viewport para evitar precargar tiles desalineados. Luego copia los vecinos
una sola vez a las celdas laterales del tilemap circular. Durante el
juego `game_extended_view_bg_tile()` deja que cada píxel use exclusivamente la
ruta normal de VRAM. Así la precarga usa la fuente persistente correcta, pero el
movimiento conserva el scroll nativo y no consulta un buffer cambiante cada
frame. El mapa actual se identifica por `wCurMap` (dirección específica para
inglés y español). Se conserva el negro durante combate y cuando no hay mapa
válido.

La compilación verifica integración, pero no demuestra el resultado gráfico.
Confirmar en el laboratorio de Oak que el primer movimiento a la derecha muestra
las columnas extendidas desde el inicio y que no vuelven los saltos al caminar.

Verificación: `cmake --build generated/build --parallel` y
`cmake --build spanish/generated/build --parallel` terminaron correctamente en
macOS arm64. `git diff --check` no reportó errores. La prueba visual del
movimiento en 4:3 queda pendiente de confirmar en el juego, porque el build por
sí solo no acredita el resultado gráfico.


## Seguimiento: columna derecha sigue vacía en el primer acceso (14-oct-2026)

El usuario confirma que la precarga descrita arriba no cambió el síntoma: la
columna fuera del viewport sigue vacía hasta caminar hacia ella. Por tanto, la
compilación anterior no acreditó que la precarga estuviera funcionando; la
explicación anterior debe tratarse como una hipótesis, no como una solución.

La imagen muestra color uniforme de fondo en el margen derecho, mientras las
columnas que ya entraron en el área nativa se dibujan. Esto requiere separar
dos posibilidades con datos de ejecución: que no se hayan escrito los IDs
correctos en el tilemap circular, o que el ID esté escrito pero los datos del
tile gráfico no estén en VRAM. `LoadTilesetTilePatternData` en
`third_party/pokered-es/home/overworld.asm` carga 0x600 bytes del tileset a VRAM;
no debe asumirse que reconstruir solo los IDs del mapa inicializa gráficos que
no se hayan cargado.

Próximo diagnóstico: registrar temporalmente, al inicializar el mapa, el ID de
mapa, resultado/cantidad de celdas precargadas, los IDs escritos en las celdas
del margen derecho y los bytes de sus patrones en VRAM. Compararlos con la misma
columna después de caminar hasta ella. Ese contraste identifica si falla el
tilemap o la disponibilidad de patrones y evita otra modificación basada solo
en la imagen. No considerar resuelto hasta confirmar visualmente en 4:3 desde
la primera entrada, antes de caminar hacia el margen.

## Instrumentación temporal para comparar el margen (14-oct-2026)

Durante el diagnóstico, una variante española temporal registró líneas `[WIDE-DIAG]` solo en Oaks Lab (`wCurMap`
`0x28`). Cada registro incluye el puntero y coordenadas del mapa, SCX/SCY, el
resultado de la precarga y una firma de IDs de tile más sus 16 bytes de patrón
gráfico en VRAM para las columnas del margen derecho. Se emite al inicio y
cuando cambia la firma, con un máximo de 40 registros para mantener el log
manejable. Esta instrumentación es temporal y debe retirarse después de
identificar la fuente del fallo.

### Resultado del primer log instrumentado

En la sesión compartida, todas las muestras de Oaks Lab muestran `seed=0` y
`seeded_map=FF`. La precarga no llega a registrar el mapa como preparado; los
IDs `7F` del margen son el estado no inicializado observado en ese momento. El
siguiente build agrega una única línea `[WIDE-DIAG-MISMATCH]` con la primera
coordenada donde la reconstrucción desde `wOverworldMap` difiere de `wTileMap`
(o donde no se puede leer el bloque), además de dimensiones, punteros y tileset.
Compilar correctamente no basta: esa coordenada permitirá corregir la fórmula
con evidencia de ejecución.


### Precarga habilitada tras el diagnóstico (14-oct-2026)

El primer `[WIDE-DIAG-MISMATCH]` fue `xy=0,0 readable=1 expected=00
current=7F`, con `seed=0`. El rechazo completo estaba ocurriendo por comparar
contra `wTileMap`, que no es una referencia válida en ese instante del cuadro.
La comparación ahora solo reporta el primer desacuerdo y continúa con la
precarga desde `wOverworldMap` y los datos del tileset. El siguiente arranque
en Oaks Lab debe mostrar `seed` positivo y `seeded_map=28`; si el margen sigue
vacío con esos valores, el diagnóstico siguiente es revisar los IDs/patrones
concretos que se escribieron. Build español y `git diff --check` correctos.


### Comparación con VRAM nativa

El segundo log fue concluyente: el seed reportó 72 celdas, pero las dos columnas
quedaron llenas de `00`; esa fue una precarga mal alineada y no debe conservarse.
La implementación volvió a bloquear la escritura salvo que los 20×18 IDs
reconstruidos coincidan con los IDs que el PPU está leyendo del tilemap nativo
con SCX/SCY actuales. La línea `[WIDE-DIAG-MISMATCH]` ahora imprime `expected`
frente a `vram`; comparte ese resultado para corregir el punto de origen y el
desplazamiento del mapa antes de volver a habilitar la precarga.


### Reprecarga al avanzar el viewport (14-oct-2026)

El último log mostró que una carga exitosa inicial (`seed=72`) llenó las celdas
visibles del margen, pero después, con `scx=8`, reaparecieron IDs `7F`. La
precarga estaba cacheada solo por ID de mapa, aunque el anillo de tilemap cambia
con el origen del viewport. Ahora se calcula una clave con mapa, puntero,
coordenadas de bloque y SCX/SCY por tiles; si cambia, se valida de nuevo contra
VRAM nativa y se precargan las celdas laterales para la posición actual. Build
español y `git diff --check` correctos. Falta confirmar visualmente que no vuelvan
los saltos ni los tiles vacíos durante el desplazamiento.

### Precarga anticipada durante movimiento (14-oct-2026)

El usuario confirma que el viewport inicial ya está correcto, pero al caminar
hay una pausa breve antes de que se complete la columna nueva. El log muestra
que una vista nueva suele fallar primero la validación de VRAM (`seed=0`) y
luego pasa cuando el buffer nativo termina de actualizarse (`seed=72` o `108`).
Para cubrir ese intervalo, la rutina ahora precarga 16 píxeles adicionales a
cada lado, fuera del viewport visible, además de los márgenes configurados. Esos
tiles quedan disponibles al desplazarse mientras el runtime espera una vista
coherente para actualizar la precarga. Compilación española y
`git diff --check` correctos; falta confirmar que el movimiento se vea continuo.

### Estado estable confirmado y limpieza de diagnóstico (14-oct-2026)

El usuario confirmó visualmente que la precarga anticipada resolvió los tiles
vacíos durante el movimiento horizontal en Oaks Lab. Se considera estable la
ruta de tiles extendidos: valida los IDs de la vista nativa, precarga el margen
más 16 píxeles de anticipación por lado y vuelve a hacerlo cuando cambia la
clave de viewport. Se retiraron los `fprintf` y firmas temporales `[WIDE-DIAG]`
del runtime; las muestras anteriores se conservan arriba como historial del
diagnóstico. Se compilaron ambas variantes (inglés y español) y
`git diff --check` terminó correctamente.
