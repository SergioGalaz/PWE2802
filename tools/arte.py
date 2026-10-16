"""Pixel art de Marea Bruja: los suelos, con una paleta chilota de 30 colores.

Los personajes, entes e íconos están en tools/figuras.py y los edificios en
tools/edificios.py. Los suelos usan solo los colores de PALETA. Al guardar, cada píxel se lleva al
color más cercano de la paleta, así nada se escapa aunque un dibujo mezcle tonos.
Lo usa tools/generate_assets.py.
"""
import math
import random
from pathlib import Path

from PIL import Image

import edificios
import figuras

ROOT = Path(__file__).resolve().parent.parent
SPRITES = ROOT / "assets" / "sprites"

## Paleta: fríos de mar y neblina, verdes de monte y musgo, maderas de alerce,
## lanas chilotas y unos pocos acentos de fuego. Cada letra es un color.
PALETA = {
    "k": "#0e0d12",  # tinta (contornos)
    "c": "#26222b",  # carbón
    "l": "#4a4552",  # pizarra
    "g": "#7d7a86",  # piedra
    "f": "#c7c3c0",  # neblina
    "p": "#f2ead8",  # hueso
    "v": "#3b2620",  # madera oscura
    "w": "#6a4530",  # madera
    "W": "#9c6b45",  # alerce
    "S": "#b07850",  # piel en sombra
    "s": "#e0b08a",  # piel
    "R": "#8a2f2b",  # rojo profundo
    "r": "#c8483a",  # rojo lana
    "o": "#f08a3a",  # fuego
    "y": "#f6d36b",  # vela
    "Y": "#c9a54a",  # ocre y quilineja
    "A": "#a8905e",  # arena en sombra
    "a": "#d8c08c",  # arena
    "B": "#1d2a3a",  # mar profundo
    "b": "#24476a",  # mar
    "u": "#3f7896",  # ola
    "i": "#8fc0c8",  # espuma
    "F": "#1c3322",  # monte cerrado
    "m": "#2f5534",  # monte
    "n": "#557a3c",  # pasto
    "N": "#8aa452",  # musgo claro
    "z": "#a9bfa0",  # piel de Finao
    "Z": "#6a8670",  # piel de Finao en sombra
    "q": "#3e2b48",  # brujería oscura
    "Q": "#6e4f7a",  # brujería
}
TRANSPARENTE = (0, 0, 0, 0)


def rgba(letra):
    h = PALETA[letra].lstrip("#")
    return (int(h[0:2], 16), int(h[2:4], 16), int(h[4:6], 16), 255)


_RGB = [rgba(k)[:3] for k in PALETA]


def a_paleta(img):
    """Lleva cada píxel visible al color más cercano de la paleta."""
    out = img.copy()
    px = out.load()
    cache = {}
    for y in range(out.height):
        for x in range(out.width):
            r, g, b, a = px[x, y]
            if a < 128:
                px[x, y] = TRANSPARENTE
                continue
            key = (r, g, b)
            if key not in cache:
                cache[key] = min(_RGB, key=lambda c: (c[0] - r) ** 2 + (c[1] - g) ** 2 + (c[2] - b) ** 2)
            px[x, y] = cache[key] + (255,)
    return out


class Lienzo:
    """Lienzo chico para dibujar con letras de la paleta."""

    def __init__(self, w, h, fondo=None):
        self.w, self.h = w, h
        self.img = Image.new("RGBA", (w, h), rgba(fondo) if fondo else TRANSPARENTE)
        self.px = self.img.load()

    def p(self, x, y, c):
        if 0 <= x < self.w and 0 <= y < self.h:
            self.px[x, y] = rgba(c) if c else TRANSPARENTE

    def wrap(self, x, y, c):
        self.px[x % self.w, y % self.h] = rgba(c)

    def get(self, x, y):
        return self.px[x, y] if 0 <= x < self.w and 0 <= y < self.h else TRANSPARENTE

    def rect(self, x0, y0, w, h, c):
        for y in range(y0, y0 + h):
            for x in range(x0, x0 + w):
                self.p(x, y, c)

    def hline(self, x0, x1, y, c):
        for x in range(x0, x1 + 1):
            self.p(x, y, c)

    def vline(self, x, y0, y1, c):
        for y in range(y0, y1 + 1):
            self.p(x, y, c)

    def ascii(self, filas, x0=0, y0=0):
        for y, fila in enumerate(filas):
            for x, ch in enumerate(fila):
                if ch != ".":
                    self.p(x0 + x, y0 + y, ch)

    def contorno(self, c="k"):
        """Contorno de un píxel alrededor de todo lo dibujado."""
        orig = self.img.copy()
        o = orig.load()
        for y in range(self.h):
            for x in range(self.w):
                if o[x, y][3] == 0:
                    for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                        nx, ny = x + dx, y + dy
                        if 0 <= nx < self.w and 0 <= ny < self.h and o[nx, ny][3] > 0:
                            self.px[x, y] = rgba(c)
                            break
        return self


def tramado(x, y, nivel):
    """Tramado ordenado 2x2 para pasar de un tono a otro sin mezclar colores."""
    umbral = ((0, 2), (3, 1))[y % 2][x % 2] / 4.0 + 0.125
    return nivel > umbral


# --- Suelos (32x32, se repiten sin costuras) ---

def suelo(base, acentos, semilla, densidad):
    rng = random.Random(semilla)
    lz = Lienzo(32, 32, base)
    for y in range(32):
        for x in range(32):
            if rng.random() < densidad:
                lz.p(x, y, rng.choice(acentos))
    return lz, rng


def pasto():
    lz, rng = suelo("n", ["m", "n", "N"], 11, 0.12)
    # Matas de pasto de tres hojas.
    for _ in range(9):
        x, y = rng.randrange(32), rng.randrange(32)
        lz.wrap(x, y, "m")
        lz.wrap(x, y - 1, "N")
        lz.wrap(x - 1, y - 1, "n")
        lz.wrap(x + 1, y - 2, "N")
        lz.wrap(x - 1, y - 2, "N")
    for _ in range(2):
        x, y = rng.randrange(32), rng.randrange(32)
        lz.wrap(x, y, "y")
    lz.wrap(rng.randrange(32), rng.randrange(32), "p")
    return lz.img


def monte():
    lz, rng = suelo("F", ["F", "m", "c"], 21, 0.25)
    # Helechos del sotobosque.
    for _ in range(5):
        x, y = rng.randrange(32), rng.randrange(32)
        for i in range(4):
            lz.wrap(x + i, y - i // 2, "m")
            lz.wrap(x - i, y - i // 2, "m")
        lz.wrap(x, y - 2, "n")
    return lz.img


def arena():
    lz, rng = suelo("a", ["A", "a", "p"], 31, 0.14)
    for _ in range(4):
        x, y = rng.randrange(32), rng.randrange(32)
        lz.wrap(x, y, "g")
        lz.wrap(x + 1, y, "f")
        lz.wrap(x, y + 1, "l")
    # Una concha y unas algas varadas.
    x, y = rng.randrange(32), rng.randrange(32)
    for dx, c in ((0, "p"), (1, "f"), (2, "p")):
        lz.wrap(x + dx, y, c)
    x, y = rng.randrange(32), rng.randrange(32)
    for i in range(5):
        lz.wrap(x + i, y + (i % 2), "m")
    return lz.img


def camino():
    lz, rng = suelo("W", ["w", "W", "A"], 41, 0.22)
    for _ in range(6):
        x, y = rng.randrange(32), rng.randrange(32)
        lz.wrap(x, y, "g")
        lz.wrap(x + 1, y, "g")
        lz.wrap(x, y - 1, "f")
        lz.wrap(x + 1, y + 1, "l")
    return lz.img


def mar(cuadro):
    """Mar con crestas horizontales que se corren un poco entre los dos cuadros."""
    lz = Lienzo(32, 32, "b")
    rng = random.Random(61)
    for y in range(32):
        for x in range(32):
            if math.sin(2 * math.pi * (y / 16 + x / 32)) > 0.75 and tramado(x, y, 0.3):
                lz.p(x, y, "B")
    for _ in range(10):
        x, y, largo = rng.randrange(32), rng.randrange(32), rng.randrange(3, 7)
        x += cuadro * 2
        for i in range(largo):
            lz.wrap(x + i, y, "u")
        lz.wrap(x + largo // 2, y - 1, "i")
        lz.wrap(x + largo // 2 + 1 - cuadro, y - 1, "u")
    return lz.img


def tablas(vertical=False):
    lz = Lienzo(32, 32, "w")
    rng = random.Random(51)
    for fila in range(4):
        y0 = fila * 8
        for x in range(32):
            lz.p(x, y0, "W")
            lz.p(x, y0 + 7, "v")
        # Vetas y la unión de dos tablas, desfasada por fila.
        for _ in range(3):
            x = rng.randrange(32)
            yy = y0 + rng.randrange(2, 6)
            for i in range(rng.randrange(3, 7)):
                lz.wrap(x + i, yy, "v")
        corte = (fila * 11 + 5) % 32
        lz.vline(corte, y0, y0 + 6, "v")
        lz.p(corte + 2, y0 + 3, "g")
        lz.p((corte + 18) % 32, y0 + 3, "g")
    if vertical:
        lz.img = lz.img.transpose(Image.Transpose.TRANSPOSE)
    return lz.img


def guardar(img, nombre):
    SPRITES.mkdir(parents=True, exist_ok=True)
    a_paleta(img).save(SPRITES / f"{nombre}.png")


def muestra_paleta(ruta):
    """Una tira con los 30 colores, para mirar la paleta de un vistazo."""
    lado = 40
    img = Image.new("RGBA", (lado * 10, lado * 3), TRANSPARENTE)
    for i, k in enumerate(PALETA):
        bloque = Image.new("RGBA", (lado, lado), rgba(k))
        img.paste(bloque, ((i % 10) * lado, (i // 10) * lado))
    img.save(ruta)


def make_sprites():
    # Personajes, entes, ítems y adornos: tienen su propio dibujante con luz suave.
    for nombre, img in figuras.todo().items():
        SPRITES.mkdir(parents=True, exist_ok=True)
        img.save(SPRITES / f"{nombre}.png")
    guardar(pasto(), "pasto")
    guardar(monte(), "monte")
    guardar(arena(), "arena")
    guardar(camino(), "camino")
    guardar(mar(0), "mar_0")
    guardar(mar(1), "mar_1")
    guardar(tablas(), "tablas")
    guardar(tablas(vertical=True), "tablas_v")
    for nombre, img in edificios.todo().items():
        img.save(SPRITES / f"{nombre}.png")

