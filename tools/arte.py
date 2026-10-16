"""Pixel art de Marea Bruja: personajes a 32 píxeles y una paleta chilota de 30 colores.

Todos los sprites usan solo los colores de PALETA. Al guardar, cada píxel se lleva al
color más cercano de la paleta, así nada se escapa aunque un dibujo mezcle tonos.
Lo usa tools/generate_assets.py.
"""
import math
import random
from pathlib import Path

from PIL import Image

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


# --- Personajes (32x32, con los pies en la última fila) ---

def figura(filas, alto=32, ancho=32):
    for f in filas:
        assert len(f) <= ancho, f"fila de {len(f)}: {f}"
    filas = [f.ljust(ancho, ".") for f in filas]
    while filas and set(filas[-1]) == {"."}:
        filas.pop()
    filas = ["." * ancho] * (alto - len(filas)) + filas
    lz = Lienzo(ancho, alto)
    lz.ascii(filas)
    return lz.img


ABDON_CUERPO = [
    "...............kk",
    "..............kffk",
    "..............kffk",
    "............kkkrrkkk",
    "..........kkrrorrrrrkk",
    ".........krroorrrrrrrRk",
    ".........krorrrrrrrrRRk",
    "........kRRRRRRRRRRRRRRk",
    "........kpRpRpRpRpRpRpRk",
    "........kssssssssssssSSk",
    "........kskkssssssskkSSk",
    "........ksskksssssskkSSk",
    "........kssssssSssssSSSk",
    "........kSllssssssssllSk",
    ".........klllsrrrrslllk",
    "..........kkllllllllkk",
    "........kkWWwwwwwwwwWWkk",
    ".......kWWwwvwwwwwwvwwwvk",
    "......kWwwrwwvwwwwvwwrwwvk",
    "......kwwwrwwvwwwwvwwrwwvk",
    "......kssvrwwvwwwwvwwrvssk",
    "......kSSkrrrrrrrrrrrrkSSk",
    "......kkkkRkRkRkRkRkRkRkkk",
    ".........kbbbbbbbbbbbbk",
]
ABDON = ABDON_CUERPO + [
    ".........kbbbbbBkkbbbbBk",
    ".........kbbbbBkkbbbbBk",
    ".........kBbbbBkkBbbbBk",
    ".........kccccckkccccck",
    "........kcccccckkcccccck",
    "........kkkkkkkkkkkkkkkk",
]
ABDON_PASO = ABDON_CUERPO + [
    ".........kbbbbbBkkbbbbBk",
    "........kbbbbBk..kbbbBk",
    "........kBbbbBk..kBbbBk",
    ".......kccccck...kcccck",
    ".......kcccccck..kccccck",
    ".......kkkkkkkk..kkkkkkk",
]

FINAO_CUERPO = [
    "............kkkkkkkk",
    "..........kkNnzzzzzzkk",
    ".........knNzzzzzzzzZZk",
    ".........knzzzzzzzzzZZk",
    ".........kzzkpkzzzkpkZk",
    ".........kzzzkzzzzzkZZk",
    ".........kZzzzzZzzzzZZk",
    ".........kZzkpkpkpkzZZk",
    "..........kZZkkkkkkZZk",
    "...........kkZZZZZZkk",
    "........kkgggllgggggggkk",
    ".......kgggglggggggllgllk",
    "......kzgglgNnggggglggllzk",
    "......kzglggnNggggglgllzZk",
    "......kzZlgggnggggglgllkZk",
    "......kzZkggglgnggggllllkzk",
    "......kZZklgglgnNgglllkZZk",
    ".......kkklgglgggggllllkk",
    "..........klglkglgkllk",
    "..........kllllllllllk",
    "..........klllllkllllk",
    "..........kZlllkkllllk",
]
FINAO = FINAO_CUERPO + [
    "..........kZZlk..kZllk",
    "..........kzZZk..kzZZk",
    ".........kzzZZk..kzzZZk",
    ".........kkkkkk..kkkkkk",
]
FINAO_PASO = FINAO_CUERPO + [
    ".........kZZlk...kZllk",
    ".........kzZZk....kzZk",
    "........kzzZZk....kzZZk",
    "........kkkkkk....kkkkk",
]

TRAUCO_CUERPO = [
    "...............kk",
    ".............kkYYkk",
    "...........kkYYyYYYkk",
    ".........kkYyYYYYyYYYkk",
    ".......kkYYYyYYYYYYyYYYkk",
    ".....kkA" + "Y" * 16 + "Akk",
    "......kkkkkkkkkkkkkkkkkkkk",
    "..........kSSSSSSSSSSk",
    "..........kSrrSSSSrrSk",
    "..........kSSSSwSSSSSk",
    "..........kSSkkkkkkSSk",
    "...........kSwwwwwwSk",
    "............kkwwwwkk",
    ".........kkYYYYYYYYYYkk",
    "........kSYyYYyYYyYYyYSk",
    "........kSYYYYYYYYYYYYSk",
    "........kSkAYyYYyYYyAkSk",
    "........kkkAYYYYYYYYAkkk",
    "..........kAAAAAAAAAAk",
    "..........kAkAkAkAkAkk",
]
TRAUCO = TRAUCO_CUERPO + [
    "...........kwwwk..kwwk",
    "...........kwwvk..kwvk",
    "...........kkkkk..kkkk",
]
TRAUCO_PASO = TRAUCO_CUERPO + [
    "..........kwwwk...kwwk",
    "..........kwwvk....kwvk",
    "..........kkkkk....kkkk",
]

FIURA_CUERPO = [
    "............kkkkkkkk",
    "..........kkcccccccckk",
    ".........kccclcccclccck",
    "........kcccNNNNNNNNccck",
    "........kccNrkNNNNkrNcck",
    "........kccNNNNnNNNNNcck",
    "........kccNNkkkkkkNNcck",
    "........kccNkpkkkpkNNcck",
    "........kcccNNNNNNNNccck",
    ".......kccckkRRRRRRkkccck",
    "......kccckrRRrrRRRRrkccck",
    "......kcckNrrRrrrrRrrNkcck",
    "......kcckNkrrrrrrrrkNkcck",
    "......kcckNkrRrrrrRrkNkcck",
    "......kckNNkrrrrrrrrkNNkck",
    "......kckpkkRrrrrrrRkkpkck",
    ".......kk.kRRrrrrrrRRk.kk",
    "..........kRrrrrrrrRk",
    ".........kRRrrrrrrrrRRk",
    "........kRRrRrrrrrrRrRRk",
    "........kRkRkRkRkRkRkRkk",
]
FIURA = FIURA_CUERPO + [
    "...........kNNk..kNNk",
    "..........kkkkk..kkkkk",
]
FIURA_PASO = FIURA_CUERPO + [
    "..........kNNk....kNNk",
    ".........kkkkk....kkkkk",
]


def recolor(filas, mapa):
    return ["".join(mapa.get(c, c) for c in f) for f in filas]


## El ahogado de Cai Cai es un Finao que el mar no soltó: azul, con ojos rojos.
AHOGADO_MAPA = {"z": "u", "Z": "b", "p": "r", "g": "l", "l": "c"}


def con_baston(img):
    """El pahueldún del Trauco, un bastón de madera torcida en la mano derecha."""
    lz = Lienzo(img.width, img.height)
    lz.img.paste(img)
    lz.px = lz.img.load()
    for y in range(8, 31):
        x = 26 if y > 14 else 25
        lz.p(x, y, "w" if y % 4 else "v")
    lz.rect(24, 6, 3, 3, "w")
    lz.p(24, 6, "W")
    lz.p(25, 20, "S")
    lz.p(24, 20, "S")
    return lz.contorno().img


CUERPO = [
    "......kkkk",
    ".....kzzzZk.kkkkkkkkkkkkkkkk",
    "....kzpzpzZkgggglggggglgglggk",
    "....kzzzzzZkgglgggnNggglgggllkk",
    ".....kZZZZkkllllllllllllkzZkzZk",
    "......kkkk..kkkkkkkkkkkkkkkkkkk",
]


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


# --- Árboles y edificios ---

def arbol(semilla):
    rng = random.Random(semilla)
    lz = Lienzo(64, 64)
    lz.rect(29, 48, 6, 16, "w")
    lz.vline(29, 48, 63, "W")
    lz.vline(34, 48, 63, "v")
    lz.p(28, 63, "w")
    lz.p(35, 63, "v")
    manchas = [(32, 26, 20), (18, 34, 13), (46, 34, 13), (32, 13, 13)]
    manchas += [(rng.randrange(20, 44), rng.randrange(14, 38), rng.randrange(6, 10)) for _ in range(3)]
    luz = (-0.6, -0.8)
    for y in range(64):
        for x in range(64):
            mejor = None
            for cx, cy, r in manchas:
                d = math.hypot(x - cx, y - cy)
                if d <= r and (mejor is None or d / r < mejor[0]):
                    mejor = (d / r, (x - cx) / r, (y - cy) / r)
            if mejor is None:
                continue
            _, nx, ny = mejor
            brillo = 0.5 - (nx * luz[0] + ny * luz[1]) * 0.5 + rng.uniform(-0.08, 0.08)
            brillo -= max(0, (y - 40) / 40)
            if brillo > 0.85:
                c = "N"
            elif brillo > 0.6:
                c = "N" if tramado(x, y, (brillo - 0.6) * 4) else "n"
            elif brillo > 0.4:
                c = "n"
            elif brillo > 0.25:
                c = "n" if tramado(x, y, (brillo - 0.25) * 6) else "m"
            elif brillo > 0.05:
                c = "m"
            else:
                c = "F"
            lz.p(x, y, c)
    return lz.contorno().img


def tejuelas(lz, x0, y0, w, h, base, sombra, luz=None):
    """Tejuelas de alerce con punta redondeada, la piel de las casas chilotas."""
    for y in range(y0, y0 + h):
        hilera = (y - y0) // 4
        ly = (y - y0) % 4
        for x in range(x0, x0 + w):
            lx = (x - x0 + (2 if hilera % 2 else 0)) % 5
            c = base
            if ly == 3 and lx in (0, 4):
                c = sombra
            elif ly == 3 or lx == 0 and ly > 0:
                c = sombra
            elif luz and ly == 0 and lx == 2:
                c = luz
            lz.p(x, y, c)


def ventana(lz, x0, y0, w=10, h=11, vidrio="y"):
    lz.rect(x0 - 1, y0 - 1, w + 2, h + 2, "p")
    lz.rect(x0, y0, w, h, vidrio)
    lz.vline(x0 + w // 2, y0, y0 + h - 1, "p")
    lz.hline(x0, x0 + w - 1, y0 + h // 2, "p")
    if vidrio == "y":
        lz.p(x0 + 1, y0 + 1, "p")
        lz.rect(x0 + w // 2 + 1, y0 + h // 2 + 1, w // 2 - 1, h - h // 2 - 1, "o")
    lz.hline(x0 - 2, x0 + w + 1, y0 + h + 1, "f")


def techo_dos_aguas(lz, cx, y0, alto, medio_min, medio_max, base, sombra, luz):
    for y in range(y0, y0 + alto):
        medio = medio_min + (y - y0) * (medio_max - medio_min) // max(1, alto - 1)
        for x in range(cx - medio, cx + medio):
            izq = x < cx
            fila = (y - y0) % 3
            c = (luz if izq else base) if fila else sombra
            if (x - cx) % 6 == 0 and fila == 1:
                c = sombra
            lz.p(x, y, c)
        lz.p(cx - medio, y, "v")
        lz.p(cx + medio - 1, y, "v")


def casa(muro, muro_sombra, techo=("R", "v", "r"), luz_muro=None):
    lz = Lienzo(64, 60)
    techo_dos_aguas(lz, 32, 0, 22, 4, 31, *techo)
    lz.hline(1, 62, 22, "v")
    lz.hline(1, 62, 23, "k")
    tejuelas(lz, 4, 24, 56, 36, muro, muro_sombra, luz_muro)
    lz.hline(4, 59, 24, muro_sombra)
    ventana(lz, 9, 30)
    ventana(lz, 45, 30)
    # Puerta de tablas con su marco y la manilla.
    lz.rect(25, 39, 14, 21, "p")
    lz.rect(26, 40, 12, 20, "w")
    for x in (29, 32, 35):
        lz.vline(x, 40, 59, "v")
    lz.p(36, 50, "Y")
    lz.hline(24, 39, 38, "v")
    # Chimenea con un poco de humo.
    lz.rect(44, 4, 5, 9, "g")
    lz.hline(43, 49, 4, "l")
    lz.p(46, 2, "f")
    lz.p(47, 1, "f")
    return lz.contorno().img


def iglesia():
    lz = Lienzo(96, 120)
    amarillo, sombra, luz = "Y", "A", "a"
    # Cruz y aguja de la torre.
    lz.vline(48, 0, 9, "c")
    lz.hline(45, 51, 3, "c")
    for y in range(10, 34):
        medio = 1 + (y - 10) * 10 // 23
        for x in range(48 - medio, 48 + medio + 1):
            lz.p(x, y, "f" if x < 48 else "g")
            if (y - 10) % 3 == 2:
                lz.p(x, y, "l")
    # Cuerpo de la torre en dos pisos, con celosías.
    tejuelas(lz, 36, 34, 25, 22, amarillo, sombra, luz)
    lz.hline(35, 61, 34, "v")
    lz.hline(35, 61, 45, "v")
    for x0 in (40, 51):
        lz.rect(x0, 37, 6, 7, "c")
        for y in (38, 40, 42):
            lz.hline(x0, x0 + 5, y, "W")
    lz.rect(45, 48, 7, 7, "c")
    lz.rect(46, 49, 5, 5, "u")
    # Techo de la nave.
    for y in range(56, 72):
        medio = 26 + (y - 56) * 22 // 15
        for x in range(48 - medio, 48 + medio):
            fila = (y - 56) % 3
            c = ("g" if x < 48 else "l") if fila else "c"
            lz.p(x, y, c)
    # Fachada de tejuelas con el pórtico de tres arcos.
    tejuelas(lz, 2, 72, 92, 48, amarillo, sombra, luz)
    lz.hline(1, 94, 72, "v")
    for x0 in (14, 70):
        lz.rect(x0, 78, 12, 13, "p")
        lz.rect(x0 + 1, 79, 10, 11, "u")
        lz.rect(x0 + 1, 79, 5, 5, "i")
        lz.vline(x0 + 6, 79, 89, "p")
    lz.hline(2, 93, 96, "p")
    lz.hline(2, 93, 97, "W")
    for i, x0 in enumerate((14, 38, 62)):
        ancho = 20
        for y in range(100, 120):
            for x in range(x0, x0 + ancho):
                dx = (x - x0 - ancho / 2 + 0.5) / (ancho / 2)
                techo_arco = 100 + int(6 * (1 - math.sqrt(max(0.0, 1 - dx * dx))))
                if y >= techo_arco:
                    lz.p(x, y, "c")
        if i == 1:
            lz.rect(x0 + 5, 106, 10, 14, "w")
            lz.vline(x0 + 10, 106, 119, "v")
    for x in (12, 34, 36, 58, 60, 82):
        lz.vline(x, 98, 119, "p")
        lz.vline(x + 1, 98, 119, "f")
    return lz.contorno().img


def ahumadero():
    lz = Lienzo(56, 56)
    # Chimenea de piedra.
    for y in range(0, 18):
        for x in range(38, 46):
            lz.p(x, y, "g" if (x + (y // 3) * 2) % 4 else "l")
    lz.hline(37, 46, 0, "f")
    # Techo de una agua.
    for y in range(12, 24):
        izq = 4 - (y - 12) // 4
        for x in range(izq, 54):
            lz.p(x, y, "v" if (y - 12) % 3 == 2 else ("w" if x < 30 else "v"))
    lz.hline(0, 55, 24, "k")
    # Muros de tablas verticales y la boca del fogón.
    for y in range(25, 56):
        for x in range(4, 52):
            lz.p(x, y, "v" if x % 6 == 0 else ("W" if x % 6 == 1 else "w"))
    lz.rect(16, 30, 24, 26, "c")
    for x0 in (19, 25, 31):
        lz.vline(x0 + 2, 30, 32, "g")
        for y, c in ((33, "f"), (34, "g"), (35, "g"), (36, "f"), (37, "l")):
            lz.hline(x0 + 1, x0 + 3, y, c)
    for y in range(46, 56):
        for x in range(18, 38):
            if (x * 3 + y * 5) % 7 < 2:
                lz.p(x, y, "y")
            elif (x + y) % 3:
                lz.p(x, y, "o")
            else:
                lz.p(x, y, "R")
    lz.hline(16, 39, 55, "v")
    return lz.contorno().img


def mesa_brujeria():
    lz = Lienzo(56, 40)
    lz.rect(2, 12, 52, 12, "Q")
    lz.hline(2, 53, 12, "Q")
    lz.hline(2, 53, 23, "q")
    for x in range(2, 54, 3):
        lz.p(x, 24, "q")
        lz.p(x, 25, "q")
    for y in range(14, 22):
        for x in range(2, 54):
            if (x + y) % 9 == 0:
                lz.p(x, y, "q")
    for x0 in (6, 46):
        lz.rect(x0, 24, 4, 16, "v")
        lz.vline(x0, 24, 39, "w")
    # El Revisorio abierto, un cráneo y dos velas.
    lz.rect(19, 6, 18, 8, "p")
    lz.vline(28, 6, 13, "f")
    for y in (8, 10, 12):
        lz.hline(21, 26, y, "g")
        lz.hline(30, 35, y, "g")
    lz.rect(19, 13, 18, 1, "R")
    lz.rect(40, 7, 7, 6, "p")
    lz.p(42, 9, "c")
    lz.p(44, 9, "c")
    lz.hline(41, 45, 12, "f")
    for cx in (8, 48):
        lz.rect(cx - 1, 3, 3, 9, "p")
        lz.vline(cx + 1, 3, 11, "f")
        lz.p(cx, 2, "c")
        lz.p(cx, 1, "o")
        lz.p(cx, 0, "y")
    return lz.contorno().img


def cama():
    lz = Lienzo(56, 36)
    lz.rect(0, 0, 56, 36, "w")
    lz.rect(0, 0, 56, 5, "W")
    lz.hline(0, 55, 5, "v")
    lz.rect(4, 7, 13, 26, "p")
    lz.rect(4, 28, 13, 5, "f")
    colores = ["r", "Y", "u", "R", "a", "n"]
    for y in range(7, 34):
        for x in range(18, 52):
            c = colores[((x - 18) // 6 + (y - 7) // 6 * 2) % len(colores)]
            if (x - 18) % 6 == 0 or (y - 7) % 6 == 0:
                c = "p" if (x + y) % 2 else c
            lz.p(x, y, c)
    lz.vline(0, 0, 35, "v")
    lz.vline(55, 0, 35, "v")
    return lz.contorno().img


def almacen():
    lz = Lienzo(64, 60)
    lz.img.paste(casa("r", "R", techo=("l", "c", "g"), luz_muro="o"))
    lz.px = lz.img.load()
    # Letrero sobre la puerta y un barril a un lado.
    lz.rect(17, 26, 30, 9, "v")
    lz.rect(18, 27, 28, 7, "p")
    for i, x in enumerate(range(20, 44, 3)):
        lz.vline(x, 29, 31, "c")
        if i % 2:
            lz.p(x + 1, 29, "c")
            lz.p(x + 1, 31, "c")
    lz.rect(53, 48, 9, 12, "w")
    lz.hline(53, 61, 50, "g")
    lz.hline(53, 61, 57, "g")
    lz.vline(53, 48, 59, "v")
    return lz.contorno().img


def lena():
    lz = Lienzo(56, 28)
    for y0, n, off in [(16, 4, 2), (8, 3, 9), (0, 2, 16)]:
        for i in range(n):
            cx = off + i * 14 + 6
            for y in range(y0, y0 + 12):
                for x in range(cx - 6, cx + 6):
                    d = math.hypot(x - cx + 0.5, y - y0 - 5.5)
                    if d <= 6:
                        c = "w" if d > 4.8 else ("W" if int(d * 1.6) % 2 else "a")
                        if d > 4.8 and x > cx:
                            c = "v"
                        lz.p(x, y, c)
    return lz.contorno().img


def barricada():
    lz = Lienzo(92, 24)
    for y0 in (7, 14):
        lz.rect(0, y0, 92, 5, "w")
        lz.hline(0, 91, y0, "W")
        lz.hline(0, 91, y0 + 4, "v")
    for sx in range(3, 92, 14):
        for y in range(0, 24):
            medio = 2 if y > 3 else max(0, y // 2)
            for x in range(sx - medio, sx + medio + 1):
                lz.p(x, y, "W" if x < sx else "w")
        lz.p(sx, 0, "f")
        lz.hline(sx - 3, sx + 3, 9, "c")
        lz.hline(sx - 3, sx + 3, 16, "c")
    return lz.contorno().img


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
    personajes = [
        ("abdon", ABDON, ABDON_PASO), ("finao", FINAO, FINAO_PASO),
        ("fiura", FIURA, FIURA_PASO),
        ("ahogado", recolor(FINAO, AHOGADO_MAPA), recolor(FINAO_PASO, AHOGADO_MAPA)),
    ]
    for nombre, quieto, paso in personajes:
        guardar(figura(quieto), nombre)
        guardar(figura(paso), nombre + "_paso")
    guardar(con_baston(figura(TRAUCO)), "trauco")
    guardar(con_baston(figura(TRAUCO_PASO)), "trauco_paso")
    guardar(figura(CUERPO, alto=6), "cuerpo")
    guardar(pasto(), "pasto")
    guardar(monte(), "monte")
    guardar(arena(), "arena")
    guardar(camino(), "camino")
    guardar(mar(0), "mar_0")
    guardar(mar(1), "mar_1")
    guardar(tablas(), "tablas")
    guardar(tablas(vertical=True), "tablas_v")
    guardar(arbol(1), "arbol_0")
    guardar(arbol(2), "arbol_1")
    guardar(casa("f", "g", luz_muro="p"), "casa_0")
    guardar(casa("u", "b", techo=("l", "c", "g"), luz_muro="i"), "casa_1")
    guardar(casa("Y", "A", luz_muro="a"), "casa_2")
    guardar(iglesia(), "iglesia")
    guardar(ahumadero(), "ahumadero")
    guardar(mesa_brujeria(), "mesa_brujeria")
    guardar(cama(), "cama")
    guardar(almacen(), "almacen")
    guardar(lena(), "lena")
    guardar(barricada(), "barricada")
