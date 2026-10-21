# Las Profundidades — Build de desarrollo

Prototipo autocontenido para **LÖVE 11.4**, creado con Lua y gráficos procedurales.

Para probarlo, arrastrá esta carpeta sobre `love.exe`. Como alternativa,
`JUGAR.bat` busca la instalación de LÖVE automáticamente.

La portada es deliberadamente neutra: oscuridad, título, una runa orbital
procedural y una única invitación a entrar. La premisa se descubre jugando.

## Ejecutar

1. Instalar LÖVE desde <https://love2d.org/>.
2. Arrastrar esta carpeta sobre `love.exe`, o ejecutar:

   ```powershell
   love "C:\Users\ASUS\Documents\proyectos varios\Prog Lua2d\Las Profundidades - Vertical Slice"
   ```

## Controles

- `A/D` o flechas: caminar.
- `Espacio`: saltar.
- `Espacio` mientras estás colgado: soltarte con impulso hacia arriba.
- Mouse: apuntar el gancho; el anclaje seleccionado queda resaltado.
- `E` o clic izquierdo: lanzar/soltar el gancho hacia el anclaje seleccionado.
- `W/S`: acortar o alargar la cuerda.
- Mantener `W` cerca de un anclaje sobre una plataforma: trepar al borde.
- `F` o `click derecho`: golpear con el pico hacia el cursor.
- `Q`: emitir un destello que consume batería y provoca al Custodio.
- `L`: encender/apagar la linterna (`LB` en mando).
- `R`: regresar al último refugio.
- `Tab`: abrir/cerrar el mapa recuperado.
- `E` junto a una pista: observar el dibujo recuperado.
- `1`–`4` dentro del mapa: abrir los dibujos disponibles en la galería.
- `F1`–`F6`: teletransportarse al comienzo de cada nivel para probarlo.
- `F9`: preparar el epílogo y aparecer frente a la puerta final; `E` la abre.
- `F10`: mostrar coordenadas, velocidad y nivel actual.
- `Esc`: pausa.

### Mando

- Stick izquierdo: movimiento.
- Stick derecho: apuntar el gancho.
- `A`: saltar/soltarse; `RB`: gancho; `X`: destello; `Y`: pico.
- `Back`: mapa; `Start`: pausa y opciones.

El pico no es un arma. Rompe vetas huecas, abre caminos opcionales y genera
un ruido localizado que puede atraer al Oyente o alterar criaturas cercanas.

## Producto y accesibilidad

- Guardado persistente de checkpoint, mapas, pistas, secretos, mejoras, rescates
  y encuentros superados; `C` continúa y `Enter/N` inicia una partida nueva.
- Menú de pausa con volumen de efectos, temblor de cámara, asistencia del gancho,
  anclajes de alto contraste y modo de mantener para usar el gancho.
- Soporte de teclado y gamepad con apuntado analógico.
- Arquitectura modular documentada en `ARCHITECTURE.md`.
- Cuerda procedural con eslabones, tensión, color y brillo por mejora.
- Paisaje sonoro procedural no musical por estrato: piedras, grietas, cadenas,
  madera y derrumbes que se vuelven más inquietantes con la profundidad,
  dejando libre la música de Ableton.
- Animaciones y voces procedurales propias para Custodios, Oyente y Vigía Astral.
- Poses exageradas y partículas diferenciadas para pico, gancho, soltada,
  salto, aterrizaje, destello, trepada, giro y caída del protagonista.

## Contenido del slice

- Movimiento con aceleración, salto con *coyote time* y cámara suave.
- Gancho físico con balanceo y ajuste de cuerda.
- Saltos encadenados entre anclajes conservando el impulso del balanceo.
- Objetivo asistido durante 0,9 segundos después de soltarse: la línea cambia
  inmediatamente al siguiente anclaje superior.
- Búfer de gancho: si `E` se pulsa apenas antes de entrar en alcance, el agarre
  se ejecuta automáticamente durante los siguientes 0,32 segundos.
- Asistencia de subida al borde para evitar quedar bloqueado bajo plataformas.
- Animación procedural permanente: zancada, brazos opuestos, rebote, inclinación,
  pose aérea y postura tímida durante la introducción.
- Pase de game feel: compresión al aterrizar, estiramiento en caída, anticipación
  al girar, respiración visual, microcongelamiento en impactos y partículas de acción.
- Cámara predictiva que mira hacia la marcha y amplía la visión durante las caídas.
- Respuesta física y visual del gancho: retroceso al disparar, torso inclinado y
  brazo extendido siguiendo la tensión de la cuerda.
- Pico y paredes rompibles.
- Linterna con batería y recarga en el refugio.
- Criatura que despierta al acercarse con luz.
- Encuentro-puzle contra el Custodio: provocarlo con luz, esquivar su embestida
  y lograr que rompa la roca reforzada con su propia fuerza.
- Daño y checkpoint durante la partida; cada nueva ejecución comienza arriba.
- Hallazgo narrativo de la hija.
- Final jugable ante una puerta místico-tecnológica que se abre lateralmente
  después de atar al Vigía.
- Interfaz, partículas, temblor de cámara y atmósfera procedural.
- Un descenso de 92 filas y 52 columnas, con cuatro niveles amplios que alternan
  travesía vertical y exploración lateral.
- Cuatro identidades visuales progresivas: mina abandonada, galerías orgánicas,
  ciudad enterrada y umbral astral.
- Decoración ambiental basada en la biblia: rieles, vigas, cables, herramientas
  y carros; raíces, símbolos y arcos antiguos; arquitectura monumental y un
  mural de la hija; geometrías flotantes y espacios contradictorios.
- Refugios que crecen visualmente durante el descenso con mantas, equipamiento,
  tiendas improvisadas y artefactos de interpretación.
- Sistema de cartografía: cada nivel es desconocido hasta recuperar su fragmento;
  el mapa indica rutas, anclajes y refugios y conserva la posición del jugador.
- Cinco pistas de la hija que transforman la búsqueda: dibujos, mapas, el mural
  imposible de la ciudad y la confirmación de que descendió voluntariamente.
- Visor de pistas con cuatro ilustraciones procedurales completas y galería
  integrada al mapa para revisarlas en cualquier momento.
- Dos rescates opcionales —un cartógrafo y una arqueóloga— que pasan a vivir
  físicamente en los refugios y hacen visible el crecimiento de la comunidad.
- Progresión completa del gancho: hierro, magnético con mayor alcance, rúnico
  para revelar anclajes antiguos y divino para materializar arquitectura invisible.
- Cuatro secretos opcionales y resumen de descubrimientos al finalizar.
- Presentaciones cinematográficas para Custodios, Oyente y Vigía Astral.
- Un Custodio tutorial en la primera mina y dos Custodios en las galerías: todos
  deben destruir la roca reforzada con sus propias embestidas.
- El Resonante en las galerías: un depredador volador y ciego que acumula el
  ruido de picos y caídas, persigue su última fuente y puede ser engañado con
  las campanas minerales hasta sellar su propio nido.
- Seis estratos y cinco puzzles encadenados: Custodios convertidos en
  contrapesos, una cámara que conserva el ruido, raíces que cambian con la
  linterna, puentes materializados por destellos y arquitectura que sólo
  existe cerca del aura del Vigía.
- El Oyente en la ciudad enterrada: es ciego, sigue el sonido del destello y
  debe ser atraído para que atraviese un sello verde.
- El Vigía Astral como subjefe final: atraviesa la mina, materializa caminos
  cercanos y queda atado al tocar tres círculos diferentes.
- Cuatro refugios de sesión distribuidos a lo largo del recorrido.
- Objetivos y tutoriales contextuales para cada tramo.
- Sonidos procedurales para las acciones principales.
- Variación tonal en pasos e impactos y crujido de cuerda según su tensión. La
  capa de música/ambiente continuo queda deliberadamente libre para Ableton.
- Carteles de presentación al cruzar cada estrato y estadísticas de tiempo,
  mapas recuperados y caídas al terminar la demo.
- Cinemática inicial desde el interior de la mina: túnel vacío, explosión súbita
  de la pared izquierda, destello, cascotes y entrada tímida del protagonista
  desde fuera de cuadro.
- Cinemática final extendida: la puerta se aparta, el protagonista duda y cruza
  bajo la inscripción «Quien cruce este umbral ya no será quien descendió».

## Audio procedural

Los efectos se generan íntegramente en Lua al iniciar. El destello usa un tono
principal de 620 Hz combinado con un armónico de 310 Hz, una duración de 0,22 s
y una envolvente rápida de entrada y salida.

La paleta procedural también incluye pasos y aterrizajes basados en ruido
filtrado, barridos para salto, daño, alertas y embestidas, tonos armónicos para
refugios y descubrimientos, y frecuencias graves para derrumbes, Custodios y la
puerta final. No se requieren archivos de audio externos.

El checkpoint dura durante la sesión actual. Al cerrar y volver a abrir el juego,
la demo comienza nuevamente desde la entrada de la mina.
