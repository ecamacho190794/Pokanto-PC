# macOS: shader GLSL inválido y ROM no reencontrado

Fecha: 2026-10-13
Estado: las correcciones compilan en arm64; verificación visual final pendiente.

## Síntomas

Después de elegir el ROM en el launcher y pulsar **Play**, el log proporcionado
incluyó:

```text
[GL] vendor=Apple | renderer=Apple M1 Pro | version=4.1 Metal - 89.4 | glsl=4.10 | shader_compiler=yes
[shader] compile failed (sharp): ERROR: 0:2: '' : #version required and missing.
ERROR: 0:3: '' : #version must occur before any other statement in the program
[Launcher] No ROM specified and no file picker available on this platform.
[Pokemon_Red_Blue] No ROM selected — exiting.
```

El proceso no llegó a cargar una partida. El mensaje final corresponde a una
salida ordenada tras no recibir una ruta, además del error de shader; no hay en
ese log un stack trace de una caída del proceso.

En una ejecución posterior el usuario confirmó que el juego arrancó y el audio
funcionaba, pero la imagen quedó negra. No se recibió un nuevo log de esa
ejecución, así que el diagnóstico gráfico siguiente se basa en el backend
seleccionado y el contexto OpenGL 3.2 core de macOS.

## Causas confirmadas

1. El shader GLES embebido empieza con un salto de línea. La conversión a GLSL
   desktop insertaba `out vec4 frag_color` antes de `#version`, y el compilador
   OpenGL de Apple exige `#version` al inicio del shader.
2. El launcher previo al juego escribe la selección en `rom.cfg` al lado del
   ejecutable usando `SDL_GetBasePath()`. En macOS/Linux `launcher_init()` leía
   `rom.cfg` desde el directorio de trabajo actual. Al iniciar desde Terminal,
   Finder o el shell, esos directorios pueden diferir. Entonces el runtime
   intentaba el selector antiguo: Windows-only, y no obtenía ROM.

## Cambios realizados

- `gb-recompiled/runtime/src/shader_pipeline.cpp`: la conversión macOS quita el
  espacio inicial, pone `#version 150` primero, convierte `attribute`/`varying`/
  `texture2D` y declara la salida del fragment shader.
- `gb-recompiled/runtime/src/platform_sdl.cpp` y `runtime/CMakeLists.txt`: macOS
  usa OpenGL de Apple, contexto desktop y backend ImGui GLSL 150; Windows/Linux
  conservan GLES2.
- `gb-recompiled/runtime/src/launcher.c`: en builds con SDL2 usa
  `SDL_GetBasePath()` para que `rom.cfg` se lea desde el mismo directorio en el
  que lo escribe el preboot launcher. Sin SDL2, conserva el fallback cwd.

## Pantalla negra posterior: hipótesis en verificación

La ejecución con audio y sin imagen ocurrió después de resolver el ROM. No hay
un log gráfico de esa sesión. El contexto de macOS es OpenGL 3.2 core; ese perfil
requiere un VAO activo al definir atributos de vértice. El shader pipeline tenía
un VBO pero no un VAO, lo cual puede impedir que el quad que presenta el
framebuffer se dibuje.

- `gb-recompiled/runtime/src/shader_pipeline.cpp`: el pipeline ahora crea,
  enlaza, usa y destruye un VAO en macOS. El perfil OpenGL core requiere un VAO
  activo al configurar atributos y dibujar; el VBO por sí solo no basta. Este
  cambio está compilado, pero falta confirmarlo ejecutando el juego.

## Verificación

- El ROM elegido previamente coincide con Pokémon Red USA/Europe: CRC32
  `9F7FDD53`, tamaño 1 MiB.
- `./build.sh all` generó el C y llegó al error original de headers GLES2.
- Tras añadir el backend desktop macOS, `cmake -S generated -B generated/build
  -G Ninja && cmake --build generated/build --parallel` terminó con el ejecutable
  Mach-O arm64.
- Tras añadir el VAO al pipeline, `cmake --build generated/build --parallel`
  volvió a terminar con el ejecutable Mach-O arm64.
- La hipótesis del VAO aún debe confirmarse ejecutando el nuevo binario. En la
  próxima prueba, confirma que `generated/build/rom.cfg` contiene la ruta elegida,
  que no aparece error de compilación de shader y que el juego llega al primer
  frame con imagen.

## Siguiente diagnóstico si persiste

- Si vuelve a faltar el ROM, comprueba que exista
  `generated/build/rom.cfg` junto al ejecutable y que apunte a un archivo
  existente. No uses `~/rom.cfg` como criterio: el runtime ahora ancla la ruta al
  ejecutable cuando SDL2 está disponible.
- Si hay otro error de shader, registra el shader afectado y su log completo;
  los archivos personalizados en `shaders/*.frag.glsl` también pasan por la
  conversión GLSL ES → GLSL desktop.
- Si el audio sigue funcionando pero la pantalla permanece negra, captura el
  log desde `[GL]` hasta varios segundos después del arranque y revisa errores
  `[shader]`, GL errors y si se está llamando a `gb_shader_pipeline_draw()`.
- Diferencia mensajes de salida normal de una caída: busca `Abort trap`, señal,
  backtrace o crash report. El log original solo muestra que el runtime salió
  porque `launcher_get_rom_path()` retornó `NULL`.
