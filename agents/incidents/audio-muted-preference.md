# Audio inaudible por preferencia de mute

## Síntoma y evidencia

El juego inicializa SDL y abre el dispositivo de audio, pero no se escucha
sonido. En `spanish/generated/build/runtime_prefs.ini` se encontró:

```ini
audio.enabled=1
audio.muted=1
audio.volume_percent=100
```

El runtime carga `audio.muted` al iniciar y su callback entrega silencio cuando
el valor es `1`. Por eso, que SDL reporte un dispositivo inicializado no
garantiza que se oiga audio.

## Resolución

Cambiar `audio.muted=0` en el `runtime_prefs.ini` que está junto al ejecutable.
El archivo se genera localmente y no forma parte del código ni de los commits.

En la revisión posterior se retiraron los atajos de mute, turbo, velocidad
máxima, guardado/carga rápida, selección de ranura y overlay. Los bindings
antiguos para esas acciones se ignoran; solo se leen y escriben bindings para
los ocho controles de Game Boy. También se quitó la tecla de herramienta de
desarrollo `1` para evitar acciones accidentales durante el juego. Escape y
Enter permanecen porque se asignan a B y Start.

## Verificación y límites

En la ocasión inicial se cambió la preferencia local a `audio.muted=0`. Tras
retirar los atajos, `cmake --build spanish/generated/build --parallel` compiló
y enlazó `Pokemon_Edicion_Roja` correctamente. El compilador conservó avisos
preexistentes de OpenGL obsoleto en macOS y comentarios C. No se ejecutó el juego
para comprobar sonido audible; esa verificación requiere iniciar el ejecutable
y escuchar la salida.
