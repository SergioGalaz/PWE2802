"""Prepara el arte para Defold: hornea el mapa, dibuja la interfaz y escribe los atlas.

Lo llama tools/generate_assets.py después de dibujar los sprites. Escribe:

- assets/mapa: el suelo del mapa ya armado (a la mitad de tamaño, se dibuja al doble),
  los dos cuadros del mar, el piso del palafito y el muelle.
- assets/ui: piezas de la interfaz (paneles, círculos, la luz de la linterna).
- assets/icono: el ícono de la app en los tamaños de Android.
- main/*.atlas: los atlas que usa el juego.
- juego/tamanos.lua: el tamaño de cada sprite, para apoyarlos por los pies.
"""
import math

from PIL import Image, ImageDraw

from arte import ROOT, SPRITES

MAPA = ROOT / "assets" / "mapa"
UI = ROOT / "assets" / "ui"
ICONO = ROOT / "assets" / "icono"
MAIN = ROOT / "main"

## Medidas del mundo (iguales a las de juego/mundo.lua).
ANCHO, ALTO = 3200, 2000
MONTE_FIN, PLAYA_INICIO, MAR_INICIO = 700, 1360, 1520
## El suelo se hornea a la mitad y se dibuja al doble, como las baldosas de 32 píxeles.
ESCALA = 2


def _sprite(nombre):
    return Image.open(SPRITES / f"{nombre}.png").convert("RGBA")


def _baldosa(img, nombre, x, y, w, h):
    """Repite una baldosa en un rectángulo del mundo, empezando en su esquina."""
    tile = _sprite(nombre)
    x, y, w, h = x // ESCALA, y // ESCALA, w // ESCALA, h // ESCALA
    zona = Image.new("RGBA", (w, h))
    for ty in range(0, h, tile.height):
        for tx in range(0, w, tile.width):
            zona.paste(tile, (tx, ty))
    img.alpha_composite(zona, (x, y))


def _franja(img, y0, y1, color):
    capa = Image.new("RGBA", img.size, (0, 0, 0, 0))
    ImageDraw.Draw(capa).rectangle((0, y0, img.width, y1 - 1), fill=color)
    img.alpha_composite(capa)


def suelo():
    img = Image.new("RGBA", (ANCHO // ESCALA, MAR_INICIO // ESCALA))
    _baldosa(img, "monte", 0, 0, ANCHO, MONTE_FIN)
    _baldosa(img, "pasto", 0, MONTE_FIN, ANCHO, PLAYA_INICIO - MONTE_FIN)
    _baldosa(img, "arena", 0, PLAYA_INICIO, ANCHO, MAR_INICIO - PLAYA_INICIO)
    _baldosa(img, "camino", 1270, 1124, 1630, 52)
    _baldosa(img, "camino", 2224, 1100, 52, 300)
    # Espuma de la orilla.
    _franja(img, (MAR_INICIO - 6) // ESCALA, MAR_INICIO // ESCALA, (217, 230, 242, 90))
    return img


def mar(cuadro):
    img = Image.new("RGBA", (ANCHO // ESCALA, (ALTO - MAR_INICIO) // ESCALA))
    _baldosa(img, f"mar_{cuadro}", 0, 0, ANCHO, ALTO - MAR_INICIO)
    _franja(img, 0, 2, (217, 230, 242, 90))
    return img


def piso():
    """El piso de tablas del palafito, con su borde y la sombra de la mesa."""
    w, h = 624 // ESCALA, 336 // ESCALA
    img = Image.new("RGBA", (w, h))
    _baldosa(img, "tablas", 0, 0, 624, 336)
    d = ImageDraw.Draw(img)
    d.rectangle((0, 0, w - 1, h - 1), outline=(31, 20, 15, 255), width=2)
    capa = Image.new("RGBA", img.size, (0, 0, 0, 0))
    ImageDraw.Draw(capa).rectangle(((780 - 648) // 2, (1212 - 976) // 2, (780 - 648 + 184) // 2 - 1, (1212 - 976 + 76) // 2 - 1), fill=(0, 0, 0, 64))
    img.alpha_composite(capa)
    return img


def muelle():
    """El muelle: tablas a lo largo y dos pilotes que bajan al agua."""
    w, h = 96 // ESCALA, 220 // ESCALA
    img = Image.new("RGBA", (w, h))
    d = ImageDraw.Draw(img)
    for x in (3, w - 8):
        d.rectangle((x, 0, x + 4, h - 1), fill=(64, 46, 31, 255))
    tabla = Image.new("RGBA", (w, 100))
    _baldosa(tabla, "tablas_v", 0, 0, 96, 200)
    img.alpha_composite(tabla, (0, 0))
    ImageDraw.Draw(img).rectangle((0, 0, w - 1, 99), outline=(0, 0, 0, 128), width=1)
    return img


# --- Interfaz ---

def _guardar(img, carpeta, nombre):
    carpeta.mkdir(parents=True, exist_ok=True)
    img.save(carpeta / f"{nombre}.png")


def piezas_ui():
    blanco = (255, 255, 255, 255)
    _guardar(Image.new("RGBA", (8, 8), blanco), UI, "blanco")
    for nombre, grosor in (("circulo", 0), ("anillo", 5)):
        img = Image.new("RGBA", (128, 128))
        d = ImageDraw.Draw(img)
        if grosor:
            d.ellipse((1, 1, 126, 126), outline=blanco, width=grosor)
        else:
            d.ellipse((1, 1, 126, 126), fill=blanco)
        _guardar(img, UI, nombre)
    img = Image.new("RGBA", (48, 48))
    ImageDraw.Draw(img).rounded_rectangle((0, 0, 47, 47), radius=12, fill=blanco)
    _guardar(img, UI, "redondo")
    img = Image.new("RGBA", (48, 48))
    ImageDraw.Draw(img).rounded_rectangle((0, 0, 47, 47), radius=12, outline=blanco, width=4)
    _guardar(img, UI, "borde")
    # La linterna: transparente al centro y opaca hacia el borde.
    lado = 256
    img = Image.new("RGBA", (lado, lado))
    px = img.load()
    for y in range(lado):
        for x in range(lado):
            r = math.hypot(x + 0.5 - lado / 2, y + 0.5 - lado / 2) / (lado / 2)
            px[x, y] = (255, 255, 255, int(255 * min(1.0, r) ** 1.6))
    _guardar(img, UI, "linterna")
    # Punta del arpón y el arco del golpe, mirando a la derecha.
    img = Image.new("RGBA", (16, 16))
    ImageDraw.Draw(img).polygon([(15, 8), (1, 1), (1, 15)], fill=blanco)
    _guardar(img, UI, "flecha")
    img = Image.new("RGBA", (192, 192))
    ImageDraw.Draw(img).arc((12, 12, 180, 180), -52, 52, fill=blanco, width=6)
    _guardar(img, UI, "arco")


def icono():
    base = Image.new("RGBA", (64, 64), (16, 22, 32, 255))
    abdon = _sprite("abdon_frente")
    base.alpha_composite(abdon, ((64 - abdon.width) // 2, 64 - abdon.height))
    for n in (36, 48, 72, 96, 144, 192):
        _guardar(base.resize((n, n), Image.NEAREST), ICONO, f"icono_{n}")


# --- Atlas y tamaños ---

def _atlas(ruta, imagenes, animaciones=()):
    lineas = []
    for img in imagenes:
        lineas.append(f'images {{\n  image: "{img}"\n}}\n')
    for nombre, cuadros, fps in animaciones:
        lineas.append("animations {\n" f'  id: "{nombre}"\n')
        for c in cuadros:
            lineas.append(f'  images {{\n    image: "{c}"\n  }}\n')
        lineas.append(f"  playback: PLAYBACK_LOOP_FORWARD\n  fps: {fps}\n}}\n")
    lineas.append("margin: 0\nextrude_borders: 2\ninner_padding: 0\n")
    ruta.write_text("".join(lineas))


def atlas_y_tamanos():
    MAIN.mkdir(parents=True, exist_ok=True)
    figuras = sorted(p.stem for p in SPRITES.glob("*.png"))
    _atlas(MAIN / "figuras.atlas", [f"/assets/sprites/{n}.png" for n in figuras])
    _atlas(MAIN / "mapa.atlas", [f"/assets/mapa/{n}.png" for n in ("suelo", "mar_0", "mar_1", "piso", "muelle")])
    ui = sorted(p.stem for p in UI.glob("*.png"))
    _atlas(MAIN / "ui.atlas", [f"/assets/ui/{n}.png" for n in ui])
    filas = []
    for n in figuras:
        w, h = Image.open(SPRITES / f"{n}.png").size
        filas.append(f"\t{n} = {{{w}, {h}}},\n")
    (ROOT / "juego").mkdir(exist_ok=True)
    (ROOT / "juego" / "tamanos.lua").write_text(
        "-- Tamaño en píxeles de cada sprite. Lo escribe tools/defold.py: no editar a mano.\n"
        "return {\n" + "".join(filas) + "}\n")


def preparar():
    MAPA.mkdir(parents=True, exist_ok=True)
    suelo().save(MAPA / "suelo.png")
    mar(0).save(MAPA / "mar_0.png")
    mar(1).save(MAPA / "mar_1.png")
    piso().save(MAPA / "piso.png")
    muelle().save(MAPA / "muelle.png")
    piezas_ui()
    icono()
    atlas_y_tamanos()
