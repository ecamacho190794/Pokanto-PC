# Herramientas de desarrollo y controles fijos del runtime

## Comportamiento

- `dev_config.h` es la configuración de desarrollo común a todos los idiomas.
  `DEVELOPMENT_MODE` debe ser verdadero para habilitar cualquier herramienta;
  cada opción también debe estar habilitada individualmente. Actualmente,
  `DEV_TOOL_RARE_CANDY` habilita la tecla `1`.
- La tecla `1` agrega un Caramelo Raro al inventario. El helper compartido de
  `dev_tools.h` usa el ID de objeto `0x28`, incrementa una pila existente hasta
  99 y respeta el límite de 20 espacios. Las direcciones de memoria específicas
  del inventario se mantienen en los `extras.c` de cada idioma, no en el helper.
- El menú de ajustes accesible durante el juego fue eliminado, junto con sus
  rutas de apertura por Escape/Android Back, Guide/Home y atajos. Se mantienen
  el launcher inicial y el overlay de diagnóstico.
- Escape envía siempre B; Enter y Enter del teclado numérico envían siempre
  Start. Estos controles fijos se mantienen separados de los bindings guardados
  y no se pueden capturar como reasignaciones.

## Implementación persistente

Los hooks y cambios comunes del runtime están en
`../patches/gb-recompiled-pokanto-runtime.patch`; los hooks por juego/idioma
están en `../extras.c` y `../spanish/extras.c`. El script
`../scripts/apply-submodule-patches.sh` aplica el parche al submódulo `gb-recompiled`
o detecta que ya está aplicado. No dependas únicamente de modificaciones locales
del submódulo: el parche del repositorio debe reflejar cualquier cambio común
para que se reproduzca en un checkout limpio.

## Verificación

Compilar las dos variantes desde la raíz:

```sh
./build.sh english game
./build.sh spanish game
```

La compilación comprueba integración y generación de los artefactos BPS; no
reemplaza una prueba manual de los controles ni del uso de Caramelo Raro dentro
del juego.
