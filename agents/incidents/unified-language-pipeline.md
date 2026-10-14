# Flujo unificado por idioma y launcher compartido

Fecha: 2026-10-13
Estado: consolidado; compilación inglesa y española verificada.

## Síntoma

El proyecto mantenía dos caminos de compilación muy parecidos para inglés y
español: el script raíz y varios accesos rápidos por idioma. El launcher, la
lógica de runtime y la selección de ROM se mantenían parcialmente compartidos,
pero algunas rutas y documentación sugerían dos pipelines distintos. Esto hacía
que un cambio del launcher o del cierre del juego se tuviera que reimplementar en
más de un sitio y que añadir otra ROM/idioma necesitara tocar varios archivos.

## Causa confirmada

1. La variante española tenía su propio script (`build-spanish.sh`) y un flujo
   paralelo que no se reusaba desde la entrada general del proyecto.
2. La compilación del launcher y del runtime estaba claramente compartida, pero
   el catalogo del launcher se mantenía en dos archivos diferentes
   (`languages/en/launcher_strings.h` y `languages/es/launcher_strings.h`),
   con la duplicación y el riesgo de que se desalinearan.
3. El build raíz no ofrecía un patrón común para añadir otra variante por idioma
   sin crear más bifurcaciones.

## Cambios realizados

- Se unificó el punto de entrada del build raíz en
  [`../../build.sh`](../../build.sh): ahora despacha hacia las variantes de
  idioma bajo `languages/<id>/build.sh`.
- La variante española quedó documentada como una entrada más del sistema de
  idiomas, no como un pipeline independiente: se usa `./build.sh spanish` y el
  alias `./build-spanish.sh` queda como compatibilidad.
- Se normalizó el patrón de cada idioma con `languages/<id>/variant.json` y
  `launcher_strings.h`.
- Se mantiene un launcher compartido y un runtime compartido; el idioma solo
  redirige el catálogo, la ROM esperada, la regresión del parche y la
  configuración del build.
- Se dejó claro que los parches específicos del juego (por ejemplo, el de
  Pokered-es o un futuro parche italiano) siguen siendo específicos del idioma,
  mientras que el launcher y la lógica de cierre del juego son comunes.

## Regla general del flujo

- `build.sh` es el punto de entrada compartido.
- Cada idioma vive en `languages/<id>/`.
- Si un idioma necesita un parche de ensamblador o una ROM base distinta, ese
  archivo se mantiene separado dentro del idioma; el launcher no debe duplicarse.
- La traducción del launcher debe estar en un mismo catálogo por idioma, con
  nombres de macro estables para que cualquier variante pueda reutilizar la UI sin
  tocar la lógica del launcher.

## Verificación

Se verificó la compilación de ambas variantes en este checkout:

- `./build.sh english game` ✅
- `./build.sh spanish` ✅
- `./build-spanish.sh` (compatibilidad) ✅

La compilación confirma que el flujo unificado funciona y que el launcher
compartido, junto con la configuración por idioma, se mantiene operativo sin
duplicar el pipeline general.
