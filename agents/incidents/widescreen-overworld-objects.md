# Objetos del overworld fuera del viewport nativo

## Síntoma

En el laboratorio de Oak, al usar un aspecto ancho, la Poké Ball sobre la mesa
desaparece al caminar hacia la izquierda y salir del viewport nativo. Las
capturas comparativas confirman el cambio visual.

## Cambios realizados

En `gb-recompiled/runtime/src/ppu.c` y `runtime/include/ppu.h`, el PPU conserva
la selección nativa de 10 sprites para el viewport original y añade candidatos
OAM que intersectan las columnas extendidas. Los candidatos adicionales sólo
se componen en los márgenes. La composición de sprites también se habilita con
`g_gbws_active`, aunque el juego no use el sidecar X16.

Además, las paletas del margen (`BGP`, `OBP0`, `OBP1` y paletas CGB) ahora se
copian al final de cada scanline. Antes sólo se copiaban en `LY=0`, aunque el
juego puede cambiar los registros de paleta durante el cuadro.

El cambio persistente vive en `../patches/gb-recompiled-pokanto-runtime.patch`;
`gb-recompiled` es un submódulo y el parche se reaplica con
`../scripts/apply-submodule-patches.sh`.

## Diagnóstico actual

Los registros anteriores seguían los slots 4–7, que pertenecen a otro objeto
más abajo en la escena. La Poké Ball sobre la mesa corresponde al grupo OAM de
slots 8–11, con tiles 0x78–0x7B en la captura completa, y está en las líneas
60–75. El rastreo se corrigió para ese grupo; imprime selección y coordenadas en
`[OBJ-PPU]`, conteos de píxeles nativos y de margen en `[OBJ-PPU-PIXELS]`, el
RGB555 final de X=144..159 en `[OBJ-FINAL]`, y el color final del margen derecho
X=160..175 en `[OBJ-MARGIN-FINAL]`.

## Evidencia más reciente

En el nuevo registro, los slots 8–11 conservan la Poké Ball mientras se desplaza
hacia la derecha: sus X avanzan de 144/152 a 160/168. El contador llega a
`native=0 margin=112`, así que el PPU seleccionó sus píxeles, resolvió la
prioridad contra el fondo y escribió los colores al framebuffer del margen.
Luego OAM reutiliza esos slots para los tiles 0x18–0x1B. Esto descarta como
causa inmediata que el renderizador ignore por completo sprites fuera del área
nativa, pero aún no explica por qué la captura del usuario no los muestra.

El RGB final registrado antes sólo cubría X=144..159, por lo que no permitía
verificar los píxeles que ya estaban fuera del viewport. Se añadió
`[OBJ-MARGIN-FINAL]` para inspeccionar X=160..175 al terminar la línea 75. El
registro recibido muestra fondo en ese rango, excepto dos píxeles al extremo en
una posición intermedia. Eso no contradice los 112 píxeles contados en el
margen: el contador suma las 16 filas, mientras que el muestreo sólo miraba la
fila 75, cuyo borde inferior puede ser transparente.

`[OBJ-MARGIN-ROW]` registra X=160..175 después de componer cada fila LY=60..75.
El registro nuevo muestra los colores de la Poké Ball en esas filas cuando el
objeto cruza el borde nativo. El PPU sí conserva el objeto en el framebuffer.
Se amplió la ruta de presentación SDL para no recortar el ancho cuando está
activa la superposición SGB, pero el usuario reportó que el síntoma continúa;
por lo tanto, esa corrección no está validada y puede no ser suficiente.

La presentación ahora usa el ancho completo del framebuffer y desplaza su
origen para centrar la imagen extendida sobre la abertura nativa del marco SGB.
Así, la escena extendida ocupa los márgenes del marco.

El diagnóstico `[WIDE-PRESENT]` se había colocado dentro de una condición que
exigía `g_gbws_active`. El usuario confirmó que compartió el log completo y la
línea no aparecía, aunque el PPU del mismo log sí componía el margen. Quité esa
condición e incluí `active`, `border`, ancho de textura, márgenes y viewport.
El binario español contenía la cadena del diagnóstico (verificado con
`strings`) y se recompiló, pero el siguiente registro completo tampoco la
incluía.

Se añadió `[WIDE-PRESENT-ENTRY]` al inicio de `render_frame_internal`, antes de
las salidas tempranas. Registra los cambios de `active` y ancho para comprobar
si SDL recibe el frame y si su runtime ve el modo extendido. Si también falta
este marcador mientras aparecen trazas del PPU, la ejecución no pasa por esta
función o usa otro ejecutable.

El siguiente adjunto vuelve a carecer de ambas trazas de presentación y coincide
byte por byte con el adjunto anterior. Para localizar la desconexión un nivel
antes, se añadió temporalmente `[GAME-PRESENT-CALL]` justo antes de que el
`main` español invoque `gb_platform_render_frame`. Este marcador confirma que el
bucle del juego alcanza el callback; el runtime debe imprimir después
`[WIDE-PRESENT-ENTRY]`.

La sincronización de paletas del margen se mantiene porque sigue siendo
necesaria para usar los registros vigentes de cada scanline.

El registro más reciente confirma que la salida PPU/OpenGL no era la causa
principal. En el borde, los tiles 0x78–0x7B aparecen en OAM y los píxeles llegan
al margen; al avanzar la escena, esos slots cambian a 0x18–0x1B y la bola deja
de estar seleccionada. En `engine/overworld/movement.asm`,
`CheckSpriteAvailability` marcaba invisibles los objetos más allá de la mitad
del viewport nativo. La ROM, por tanto, los quitaba antes de que el PPU pudiera
dibujarlos de forma estable.

## Corrección del recorte de objetos

El parche `../patches/pokered-es-widescreen-objects.patch` reserva un byte en
el espacio WRAM que ya estaba sin usar y ensancha dinámicamente el límite
horizontal de `CheckSpriteAvailability` cuando la vista extendida está activa.
El runtime escribe el número de tiles adicionales según el margen más ancho;
en aspecto 4:3 equivale a una columna de tiles por lado. Con la vista nativa o
en batalla, el valor queda en cero. El byte nuevo se colocó en el padding para
no desplazar las direcciones WRAM existentes.

`scripts/apply-submodule-patches.sh` aplica este parche al submódulo español en
los builds futuros. `pokemon_extended_view.h` sincroniza el radio con la vista
activa. Así Oak y la Poké Ball siguen siendo objetos visibles para el propio
juego y no dependen de que ya existan en OAM por casualidad.

## Protección de la subida a OpenGL

El framebuffer del PPU contiene el margen y el volcado `[OBJ-MARGIN-ROW]`
confirma que los píxeles llegan a memoria. La textura de SDL/OpenGL, por tanto,
debe tener exactamente el mismo ancho antes de subir cada cuadro. El runtime
ahora guarda las dimensiones asignadas a la textura y la vuelve a crear si el
ancho del framebuffer extendido cambia o el renderer se reinicia. También fija
`GL_UNPACK_ALIGNMENT` y restablece `GL_UNPACK_ROW_LENGTH` antes de subir el
buffer compacto, evitando que estado global previo de OpenGL interprete las
filas con un stride incorrecto.

La protección de dimensiones/stride de OpenGL anterior se conserva como
defensa, pero no resolvió el síntoma por sí sola. La compilación completa de
`./languages/es/build.sh` ahora también reconstruye la ROM, genera el
recompilado español y produce el BPS actualizado. El usuario confirmó que el
filtro ampliado hizo que la Poké Ball permaneciera visible al caminar por el
límite del viewport.

## Verificación

Compilar con `cmake --build generated/build --parallel` y
`cmake --build spanish/generated/build --parallel`. Para validar que el parche
de runtime pueda retirarse, ejecutar
`git -C gb-recompiled apply --unidiff-zero --reverse --check` desde la raíz.

La verificación de esta corrección se hizo con `./languages/es/build.sh` y una
recompilación incremental de `spanish/generated/build`; ambas terminaron bien.
El parche nuevo de Pokered-es pasa la comprobación inversa, que confirma que se
aplica sobre el commit fijado del submódulo. El arreglo quedó confirmado en
juego por el usuario. Los cambios de visibilidad ROM son específicos de
Pokered-es; una futura variante de idioma debe portar el cambio equivalente a
su fuente ensamblador y reservar una dirección de RAM compatible.
