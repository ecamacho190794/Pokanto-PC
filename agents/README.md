# Guía de documentación para agentes

Esta carpeta conserva conocimiento operativo que debe sobrevivir entre sesiones
de IA y entre cambios de contexto. Antes de modificar el proceso de compilación o
diagnosticar un fallo, lee este archivo y luego las notas específicas pertinentes.

## Organización

- `platform-builds.md`: requisitos, comandos y diferencias entre macOS, Linux y
  Windows. Actualízalo cuando cambien dependencias, herramientas o instrucciones
  de compilación.
- `incidents/`: una nota por incidente. Nombra cada archivo por plataforma y
  síntoma; incluye evidencia del log, causa confirmada, cambios hechos, cómo se
  verificó y qué falta comprobar.
- `incidents/spanish-pokered-es.md`: cómo se añadió la variante española, cómo
  se generan sus símbolos/anotaciones y qué validación de juego falta.

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

La variante española está separada de la inglesa y se construye con
`./build-spanish.sh`; antes de tocarla, lee
[`incidents/spanish-pokered-es.md`](incidents/spanish-pokered-es.md) y
[`../spanish/README.md`](../spanish/README.md).
La variante española busca automáticamente una ROM `.gb` válida junto al
ejecutable; el mismo incidente documenta el flujo y el alcance de los textos
localizados. La nota también registra el launcher español compacto, con los
controles de pantalla en la vista principal y el panel de audio oculto.
También documenta el puente entre los controles de Player 1 y las ranuras de
teclado que consume el runtime, la salida directa en la pantalla inicial y la
salida desde `CERRAR JUEGO` en el menú de pausa con pregunta de guardado. El incidente más
reciente registra por qué recompilar
Pokered-es requiere aplicar su BPS a la ROM cargada en runtime: usar el código
de la ROM personalizada con datos de la ROM original desalineaba el menú.
Las modificaciones ensambladoras de Pokered-es están en
[`../patches/pokered-es-start-menu.patch`](../patches/pokered-es-start-menu.patch)
y `build-spanish.sh` las aplica al submódulo limpio.
