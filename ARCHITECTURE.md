# Arquitectura

`main.lua` conserva el ciclo de LÖVE y coordina los sistemas. El código nuevo no
debe agregar datos, persistencia, audio ni renderizadores reutilizables allí.

## Módulos

- `game/world.lua`: construcción declarativa del mapa, regiones y spawns de debug.
- `game/player.lua`: estado inicial y contrato de datos del protagonista.
- `game/content.lua`: textos narrativos, nombres y progresión del gancho.
- `game/settings.lua`: preferencias persistentes y valores predeterminados.
- `game/save.lua`: serialización segura del progreso en el directorio de LÖVE.
- `systems/input.lua`: teclado y gamepad bajo acciones comunes.
- `systems/audio.lua`: síntesis y reproducción de efectos procedurales.
- `systems/ambience.lua`: eventos ambientales no musicales por región.
- `systems/camera.lua`: seguimiento predictivo y visión durante caídas.
- `systems/particles.lua`: ciclo de vida y render de partículas de acción.
- `systems/puzzles.lua`: reglas, estados y dibujo procedural de contrapesos,
  resonancia, raíces fotosensibles, sombras y memoria cartográfica.
- `systems/enemies.lua`: creación, tipos y consultas globales de enemigos.
- `systems/player_animation.lua`: eventos, duración y estado de poses del protagonista.
- `render/rope.lua`: cuerda/eslabones por nivel de mejora y tensión.
- `render/lighting.lua`: luz local y distorsión del estrato astral.
- `render/enemies.lua`: siluetas, poses, anticipaciones y animación por especie.
- `render/player.lua`: pose corporal, ropa, herramientas y exageración por acción.

## Reglas

1. Los módulos no conocen rutas absolutas ni la carpeta de desarrollo.
2. El guardado contiene sólo datos; nunca funciones ni referencias de LÖVE.
3. La música permanece fuera del runtime procedural para permitir la mezcla de Ableton.
4. Los spawns y marcadores se editan únicamente en `game/world.lua`.
5. Una acción nueva de control debe incorporarse a `systems/input.lua` antes de usarse.
6. Todo módulo debe poder fallar sin impedir el arranque cuando su función sea opcional.

## Guardados

LÖVE escribe `save.lua` y `settings.lua` dentro de su directorio de identidad
`las_profundidades_vertical_slice`. El código sólo carga tablas locales generadas
por estos módulos y no evalúa contenido procedente de red.
