# Marea Bruja

Juego de gestión de recursos y caza de entes para tablets Android, ambientado en Quicaví, Chiloé, en el otoño de 1960. Abdón Cárcamo es un pescador que de día pesca y ahuma, y de noche sale con su cuadrilla de Finaos (ahogados reanimados) a cazar Traucos y Fiuras y a defender el pueblo de las hordas de Cai Cai Vilú.

- [Lore](https://claude.ai/code/artifact/d64ba2b5-229e-43d2-ac3b-fb53f514c51f)
- [Diseño de juego](https://claude.ai/code/artifact/00e6d03e-0860-4677-80e3-ca232164365a)

## Estado

Primera demo jugable: los tres primeros días del acto I, con pixel art con luz y sombra, música y efectos de sonido.

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

## Motor

El juego está hecho en [Defold](https://defold.com) 1.10 con Lua. La versión anterior en Godot quedó en el historial de git (rama `demo-acto-1`).

## Cómo abrirlo

1. Instala [Defold](https://defold.com/download/) 1.10.
2. Abre `game.project` y pulsa **Proyecto > Compilar** (Ctrl+B).

## Instalar en la tablet

GitHub Actions arma un APK de depuración en cada cambio. En la pestaña **Actions** del repositorio, abre la última ejecución de **Prueba de la demo**, baja hasta **Artifacts** y descarga `marea-bruja-apk`. Descomprime el zip, copia el APK a la tablet y ábrelo. Android va a pedir permiso para instalar apps de origen desconocido.

Para armarlo a mano no hace falta el SDK de Android, solo Java 21 y `bob.jar` de la misma versión de Defold:

```
java -jar bob.jar --root . --platform arm64-android --architectures arm64-android \
  --variant debug --archive --bundle-format apk --bundle-output build/android resolve build bundle
```

## Pruebas

La prueba automática juega los tres días a velocidad alta y revisa la pesca, el ahumadero, la tienda, los Finaos, las barricadas, la horda, los subjefes y el guardado. La lógica del juego no depende del motor, así que corre también con LuaJIT a secas:

```
luajit tools/prueba.lua
```

Y dentro del motor, con la versión compilada para Linux:

```
java -jar bob.jar --root . --platform x86_64-linux --variant debug --archive --bundle-output build/linux resolve build bundle
"build/linux/Marea Bruja/MareaBruja.x86_64" --config=prueba.automatica=1
```

Para sacar capturas (en Linux, con xvfb e ImageMagick). Las opciones arman la escena: `noche`, `jefes`, `tactil`, `tienda`, `finao`, `dialogo` o `inicio`; también se puede dar el tamaño de pantalla:

```
tools/captura.sh /tmp/noche.png "noche jefes tactil" 2400 1080
```

GitHub Actions corre las dos pruebas en cada PR.

## Arte y sonido

Los sprites pixel art, la música (un vals chilote de día y un zumbido de mar de noche) y los efectos se generan con un script, para poder ajustarlos y volver a crearlos:

```
python3 -m pip install pillow numpy
python3 tools/generate_assets.py
```

Escribe en `assets/sprites` y `assets/audio`. Después `tools/defold.py` hornea el suelo del mapa, dibuja las piezas de la interfaz y el ícono, y escribe los atlas de `main/` y `juego/tamanos.lua`.

Los personajes y entes miden 64 píxeles, con luz y sombra suave, y tienen tres vistas (frente, espalda y lado) con cuadros de paso y de ataque. Al morir se caen y se apagan. Se dibujan en `tools/figuras.py` con formas simples a cuatro veces su tamaño que luego se reducen. Los suelos y edificios usan una paleta de 30 colores definida en `tools/arte.py`.

## Estructura

- `juego/`: la lógica en Lua sin nada del motor: estado y calendario, mundo y noche, Abdón, Finaos, entes, estaciones, tienda, pesca y la prueba. `juego/vista.lua` es lo único que dibuja.
- `main/`: la colección principal, `main.script` (mueve el mundo, sonidos y música), `hud.gui_script` (interfaz, menús, mando y táctil), atlas, fuentes y sonidos.
- `render/`: la cámara que sigue a Abdón y la interfaz encima.
- `input/`: teclado, mando y pantalla táctil.
- `tools/`: arte, sonido, prueba y capturas.
