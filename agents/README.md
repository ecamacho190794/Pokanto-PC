# Guía de documentación para agentes

Esta carpeta conserva conocimiento operativo que debe sobrevivir entre sesiones
de IA y entre cambios de contexto. Antes de modificar el proceso de compilación o
diagnosticar un fallo, lee este archivo y luego las notas específicas pertinentes.

## Organización

- `../dev_config.h`: configuración universal de herramientas de desarrollo,
  compartida por todos los idiomas. `DEVELOPMENT_MODE` debe habilitar las
  opciones de desarrollo; cualquier bandera de herramienta futura debe
  ignorarse cuando este interruptor sea `false`. `DEV_TOOL_RARE_CANDY`
  habilita la tecla `1` para añadir un Caramelo Raro a la bolsa, respetando
  el límite de 99 por espacio y la capacidad de 20 espacios.
- `../dev_tools.h`: helpers compartidos para implementar herramientas de
  desarrollo sin duplicar la lógica entre idiomas.
- `incidents/dev-tools-runtime-controls.md`: configuración de Caramelo Raro,
  eliminación del menú de ajustes durante el juego y controles fijos de teclado.
- `incidents/widescreen-overworld-objects.md`: composición de sprites en los
  márgenes extendidos y ajuste del filtro de visibilidad de objetos de la ROM.
- `incidents/audio-muted-preference.md`: diagnóstico de audio inaudible cuando
  el runtime conserva `audio.muted=1` en `runtime_prefs.ini` y eliminación de
  atajos no relacionados con los controles del juego.
- `incidents/launcher-aspect-ratio-options.md`: opciones de relación de aspecto
  del launcher, generación de tiles laterales del overworld sincronizada por
  scanline, límite de ancho del PPU y comportamiento del viewport con escala de
  ventana y pantalla completa.
- `platform-builds.md`: requisitos, comandos y diferencias entre macOS, Linux y
  Windows. Actualízalo cuando cambien dependencias, herramientas o instrucciones
  de compilación.
- `incidents/`: una nota por incidente. Nombra cada archivo por plataforma y
  síntoma; incluye evidencia del log, causa confirmada, cambios hechos, cómo se
  verificó y qué falta comprobar.
- `incidents/spanish-pokered-es.md`: cómo se añadió la variante española, cómo
  se generan sus símbolos/anotaciones y qué validación de juego falta.
- `incidents/english-desktop-exit.md`: port de las opciones para cerrar desde
  los menús ingleses, parches Red/Blue y verificación del build.

## Cómo mantener estas notas

1. Separa hechos observados de hipótesis. No presentes un diagnóstico como
   confirmado hasta que el código o una reproducción lo respalde.
2. Registra las rutas y comandos relativos al repositorio, sin copiar ROMs,
   claves, datos privados ni logs completos que contengan información personal.
3. Anota si una verificación fue solo de compilación o si también se ejecutó la
   aplicación. Una compilación correcta no prueba el arranque ni el juego.
4. Actualiza la guía de plataforma cuando una solución de incidente cambie el
   flujo general. Enlaza las notas entre sí en lugar de duplicar largos bloques.
5. No borres notas anteriores al resolver un incidente; agrega el resultado y
   conserva lo que pueda servir para diagnosticar regresiones.

## Estado conocido

El build arm64 de macOS compiló en octubre de 2026. El primer arranque mostró un
error GLSL y no encontró el `rom.cfg` guardado por el launcher porque runtime y
preboot buscaban ese archivo en directorios distintos. Después, el usuario
reportó audio funcional pero pantalla negra; se añadió un VAO al shader pipeline
de OpenGL core y la recompilación terminó, pendiente de confirmar imagen en una
nueva ejecución. Ver
[`incidents/macos-glsl-y-romcfg.md`](incidents/macos-glsl-y-romcfg.md).

El flujo por idioma se unificó en un único dispatcher del proyecto. Las
variantes inglesa y española comparten launcher/runtime; una variante solo
informa su configuración, ROM válida, catálogo de textos y parche específico.
Compila con `./build.sh english` o `./build.sh spanish`; antes de modificar una
variante, lee [`../languages/README.md`](../languages/README.md),
[`incidents/unified-language-pipeline.md`](incidents/unified-language-pipeline.md)
y [`incidents/spanish-pokered-es.md`](incidents/spanish-pokered-es.md). La
variante española busca automáticamente una ROM `.gb` válida junto al
ejecutable; el incidente registra el flujo, la identidad de ROM y la relación del
BPS con el código recompilado. El parche de ensamblador sigue en
[`../patches/pokered-es-start-menu.patch`](../patches/pokered-es-start-menu.patch)
y lo aplica la entrada de idioma al submódulo limpio. El launcher compacto,
controles de pantalla, localización y búsqueda fija de ROM se comparten con
inglés; los catálogos por idioma están bajo `languages/` y el build general los
resuelve desde la misma ruta de entrada.

El 13-oct-2026 se corrigió un bloqueo de la variante española en el primer
frame: su CMake no activaba la aplicación obligatoria del BPS, por lo que podía
cargar el ROM original junto al código recompilado desde la imagen parcheada.
También se activó el define de runtime que maneja la señal de salida española.
Ver [`incidents/spanish-pokered-es.md`](incidents/spanish-pokered-es.md).

El build inglés usa una revisión fijada de Pokered y el parche propio de salida
en `patches/pokered-en-desktop-exit.patch`. Ensambla Red y Blue, recompila desde
Red y genera BPS separados para que el launcher aplique el correcto según el
CRC de la ROM seleccionada. El cierre desde pausa pregunta si se guarda; el del
menú de título cierra directamente. El build macOS arm64 y ambos BPS quedaron
verificados, pero falta probar la interacción dentro del juego. Ver
[`incidents/english-desktop-exit.md`](incidents/english-desktop-exit.md).

El runtime no incluye un menú de ajustes dentro del juego: Escape y Android
Back no lo abren, y tampoco existe una acción de menú asignable. Se conserva el
launcher previo al juego y el overlay de diagnóstico. En teclado, Escape siempre
envía B y Enter/Enter numérico siempre envían Start; estos dos controles no usan
ni modifican los bindings configurables. La tecla `1` agrega un Caramelo Raro
cuando `DEVELOPMENT_MODE` y `DEV_TOOL_RARE_CANDY` están habilitados. Estos
comportamientos son comunes a los idiomas y su integración persistente está en
`patches/gb-recompiled-pokanto-runtime.patch`. Ver
[`incidents/dev-tools-runtime-controls.md`](incidents/dev-tools-runtime-controls.md).
