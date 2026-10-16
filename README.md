# Marea Bruja

Juego de gestión de recursos y caza de entes para tablets Android, ambientado en Quicaví, Chiloé, en el otoño de 1960. Abdón Cárcamo es un pescador que de día pesca y ahuma, y de noche sale con su cuadrilla de Finaos (ahogados reanimados) a cazar Traucos y Fiuras y a defender el pueblo de las hordas de Cai Cai Vilú.

- [Lore](https://claude.ai/code/artifact/d64ba2b5-229e-43d2-ac3b-fb53f514c51f)
- [Diseño de juego](https://claude.ai/code/artifact/00e6d03e-0860-4677-80e3-ca232164365a)

## Estado

Primera demo jugable: los tres primeros días del acto I, con pixel art a 32 píxeles, música y efectos de sonido.

- Pesca con minijuego en el muelle, ahumadero, leña y el almacén de Lucio.
- Mesa de brujería para reanimar Finaos. Cada uno tiene un oficio, un rol de combate, frescura y moral.
- Los Finaos trabajan solos de día (ahumadero o muelle) y pelean de noche con cuatro órdenes: seguir, atacar, defender aquí y retirarse.
- Noches de caza con Traucos (paralizan a los Finaos) y Fiuras (su aliento los pudre).
- La tercera noche es de Marea Bruja: tres olas de ahogados suben del mar hacia la iglesia, y las barricadas de la playa los frenan.
- Medidores de Marea, Cerro, Juicio y Quicaví. Diálogos de Don Fermín. Guardado automático al amanecer.

## Controles

La interfaz cambia sola entre táctil y mando según lo último que se usó.

| Acción | Mando | Teclado | Táctil |
| --- | --- | --- | --- |
| Moverse | Stick izquierdo | WASD | Joystick a la izquierda |
| Acción | A / ✕ | E | Botón Acción |
| Arpón | X / □ | J | Botón Arpón |
| Esquivar | B / ○ | K | Botón Esquivar |
| Revisorio | Y / △ | L | Botón Revisorio |
| Órdenes | Mantener LT / L2 y elegir con un stick | Mantener Q y elegir con WASD | Botón Cuadrilla |
| Pausa | Menú / Options | Esc | Botón Menú |

## Cómo abrirlo

1. Instala [Godot 4.3](https://godotengine.org/download/archive/4.3-stable/).
2. Abre `project.godot` desde el gestor de proyectos y pulsa F5.

## Instalar en la tablet sin Godot

GitHub Actions arma un APK de depuración en cada cambio. En la pestaña **Actions** del repositorio, abre la última ejecución de **Prueba de la demo**, baja hasta **Artifacts** y descarga `marea-bruja-apk`. Descomprime el zip, copia el APK a la tablet y ábrelo. Android va a pedir permiso para instalar apps de origen desconocido.

## Cómo exportarlo a una tablet Android desde Godot

1. En Godot, ve a **Editor > Administrar plantillas de exportación** y descarga las de 4.3.
2. En **Editor > Configuración del editor > Exportar > Android**, configura el SDK de Android y un keystore de depuración (Godot puede crearlo solo).
3. Ve a **Proyecto > Exportar**, elige el preset **Android** y pulsa **Exportar proyecto**. Sale un `build/marea-bruja.apk`.
4. Copia el APK a la tablet y ábrelo, o instálalo con `adb install build/marea-bruja.apk`.

## Pruebas

La prueba automática juega los tres días a velocidad alta y revisa la pesca, el ahumadero, la tienda, los Finaos, las barricadas, la horda y el guardado:

```
godot --headless --path . --fixed-fps 60 -- --smoke
```

Los personajes miden 32 píxeles y todo usa una paleta propia de 30 colores (mar, neblina, monte, alerce, lana y fuego), definida en `tools/arte.py`. Al guardar, cada píxel se ajusta a la paleta.

Para sacar capturas (necesita pantalla, o `xvfb-run` en Linux):

```
godot --path . -- --screenshot=/tmp/dia.png
godot --path . -- --screenshot=/tmp/noche.png --night --touch
```

GitHub Actions corre la prueba automática en cada PR.

## Arte y sonido

Los sprites pixel art, la música (un vals chilote de día y un zumbido de mar de noche) y los efectos se generan con un script, para poder ajustarlos y volver a crearlos:

```
python3 -m pip install pillow numpy
python3 tools/generate_assets.py
```

Escribe en `assets/sprites` y `assets/audio`. Godot los importa con filtro de píxel nítido, y la música queda en bucle.

## Estructura

- `scripts/autoload/`: estado de la partida (`game_state.gd`) y entrada táctil/mando (`input_setup.gd`).
- `scripts/world/`: el mapa, la noche y las estaciones (muelle, ahumadero, mesa de brujería, barricadas...).
- `scripts/units/`: Abdón, los Finaos y los entes.
- `scripts/ui/`: la interfaz, los controles táctiles, la pesca y la rueda de órdenes.
- `scripts/autoload/audio.gd`: efectos y música, con fundido entre el día y la noche.
- `tools/generate_assets.py`: genera los sprites y los sonidos.
- `tools/arte.py`: la paleta y el dibujo de cada sprite.
