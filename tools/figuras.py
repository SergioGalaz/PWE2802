"""Personajes, entes e íconos de Marea Bruja con luz y sombra suave.

Cada figura se arma con formas simples (elipses, polígonos, cápsulas) dibujadas a
cuatro veces su tamaño. Cada forma recibe luz desde arriba a la izquierda y una
sombra abajo a la derecha, y proyecta una sombra corta sobre lo que tiene detrás.
Al final se reduce al tamaño real, cada píxel se lleva al color más cercano de las
rampas y se agrega un contorno oscuro del color de cada borde.

Los personajes miden 64 píxeles de alto y tienen tres vistas (frente, espalda y
lado) con tres cuadros cada una: quieto, paso y ataque. El lado mira a la derecha; el juego
lo voltea para la izquierda.
"""
import math
import random

import numpy as np
from PIL import Image, ImageDraw

SS = 4  # sobremuestreo

## Rampas de cuatro tonos, de sombra a luz.
RAMPAS = {
    "piel": ["#5a3328", "#9a5f45", "#c98a68", "#e8b48e"],
    "piel_palida": ["#46463f", "#7a786a", "#aeaa96", "#d6d1bb"],
    "finao": ["#2e3d36", "#4f6a5c", "#7d9a86", "#a9c0aa"],
    "ahogado": ["#1a2a36", "#2d4d60", "#4c7a8e", "#7fa9b6"],
    "trauco": ["#1f2a17", "#3d5226", "#62803c", "#8fac58"],
    "fiura": ["#2a3418", "#4d5f28", "#79903c", "#a5bb5a"],
    "invunche": ["#3a1a1a", "#6e3530", "#a35a4c", "#cf8a72"],
    "lana_cafe": ["#2b1e16", "#4b3424", "#755236", "#a0784e"],
    "lana_gris": ["#232329", "#3c3d45", "#5c5e68", "#878a94"],
    "marino": ["#12172a", "#1f2840", "#303e5c", "#4a5c80"],
    "bota": ["#100d0e", "#211b1c", "#362e2e", "#504444"],
    "impermeable": ["#5a3e0c", "#a37612", "#d6a51e", "#f0d058"],
    "traje": ["#141217", "#26232a", "#3b3740", "#57525d"],
    "blanco": ["#7f796d", "#b0a898", "#d8d0c0", "#f4efe2"],
    "cuero": ["#26170e", "#46291a", "#6b4227", "#93623a"],
    "metal": ["#272a30", "#50565e", "#878e97", "#c8cdd2"],
    "madera": ["#2a1b11", "#48311f", "#6d4a2f", "#966b43"],
    "fuego": ["#8a3a10", "#d0701c", "#f2b03a", "#fbe48c"],
    "monja": ["#0d1328", "#1b274c", "#2c4176", "#4c6ca6"],
    "pelo_negro": ["#0c0b0f", "#1b191f", "#2c2930", "#423d48"],
    "pelo_gris": ["#4a4a50", "#76767d", "#a3a3a9", "#d2d2d5"],
    "pelo_cafe": ["#1c120c", "#33221a", "#4e3426", "#6c4a36"],
    "rojo": ["#3a1210", "#6e221c", "#a8382c", "#d65a44"],
    "musgo": ["#18241a", "#2c4128", "#4a6a38", "#76964c"],
    "pluma_azul": ["#0e1e36", "#1d3e66", "#2f6aa0", "#5aa0d0"],
    "pluma_naranja": ["#5a2410", "#a4461c", "#d8782c", "#f2aa4c"],
    "ojo": ["#6a4a08", "#b88a14", "#ecc434", "#fff090"],
    "piedra": ["#2a2a2e", "#4a4a50", "#727278", "#a0a0a6"],
    "paja": ["#4a3a14", "#7a6224", "#ad9140", "#d8bc66"],
    "papa": ["#4a3218", "#7a5a30", "#a8844c", "#d0ae72"],
    "vidrio": ["#4a2a0c", "#8a5214", "#c27c26", "#e8ac4c"],
    "plata": ["#2c3a48", "#4f6a80", "#86a2b4", "#c6d8e0"],
    "oro": ["#5a3e08", "#9c7414", "#d4a62a", "#f6d860"],
    "sal": ["#8a8678", "#bdb8a8", "#e0dccf", "#fbf8ee"],
    "brea": ["#08080a", "#141418", "#24242a", "#3c3c46"],
    "barro": ["#3a2a1a", "#5e4630", "#86684a", "#a88a66"],
    "magia": ["#0e2a3a", "#1c5a7a", "#3aa0c8", "#9ce8f4"],
    "bote_rojo": ["#3a1210", "#7a2620", "#b23e30", "#d8664c"],
    "cielo": ["#1d2a3a", "#24476a", "#3f7896", "#8fc0c8"],
    "muro_blanco": ["#77736c", "#a49f95", "#cdc7bb", "#ebe6da"],
    "muro_azul": ["#1d3245", "#2d4f67", "#44718f", "#6c99b3"],
    "muro_ocre": ["#5c4318", "#8d6a2a", "#bf9844", "#dfbf70"],
    "muro_rojo": ["#481a16", "#7a2c24", "#a6443a", "#ca6a58"],
    "zinc": ["#2b2f35", "#484e57", "#6c747e", "#98a0aa"],
    "alerce": ["#382a1e", "#5c4532", "#84674b", "#a6896a"],
    "humo": ["#58585e", "#7e7e86", "#a6a6ae", "#cecfd4"],
    "morado": ["#24162e", "#3e2850", "#5e4078", "#8462a2"],
    "hoja": ["#14261a", "#24432a", "#3a6636", "#5f8c48"],
}
_PALETA = np.array(sorted({
    tuple(int(h[i:i + 2], 16) for i in (1, 3, 5)) for r in RAMPAS.values() for h in r
} | {(14, 13, 18)}), dtype=float)


def _hex(h):
    return np.array([int(h[i:i + 2], 16) for i in (1, 3, 5)], dtype=float)


_RAMPAS_RGB = {k: np.array([_hex(h) for h in v]) for k, v in RAMPAS.items()}


def _corrida(m, dx, dy):
    """La máscara corrida dx, dy píxeles (de sobremuestreo); lo que entra queda en falso."""
    out = np.zeros_like(m)
    h, w = m.shape
    ys = slice(max(0, dy), h + min(0, dy))
    yd = slice(max(0, -dy), h + min(0, -dy))
    xs = slice(max(0, dx), w + min(0, dx))
    xd = slice(max(0, -dx), w + min(0, -dx))
    out[ys, xs] = m[yd, xd]
    return out


class Figura:
    def __init__(self, w, h, semilla=1):
        self.w, self.h = w, h
        self.W, self.H = w * SS, h * SS
        self.rgb = np.zeros((self.H, self.W, 3))
        self.alfa = np.zeros((self.H, self.W), bool)
        self.puntos = []
        self.rng = random.Random(semilla)
        self.brillos = []

    # --- formas ---

    def forma(self, rampa, dibujo, tono=0, textura=0.0, sombra=True, plano=False):
        img = Image.new("L", (self.W, self.H), 0)
        dibujo(ImageDraw.Draw(img))
        m = np.array(img) > 127
        if not m.any():
            return
        tonos = np.full(m.shape, 2)
        if not plano:
            # Cuánto hay de la forma hacia la luz (arriba a la izquierda) y hacia la sombra:
            # cerca del borde iluminado es claro, cerca del otro borde es oscuro.
            hacia_luz = np.zeros(m.shape)
            hacia_sombra = np.zeros(m.shape)
            run_l, run_s = m.copy(), m.copy()
            for k in range(1, 16):
                dx, dy = int(k * 0.55 * SS), int(k * 0.85 * SS)
                run_l &= _corrida(m, dx, dy)
                run_s &= _corrida(m, -dx, -dy)
                hacia_luz += run_l
                hacia_sombra += run_s
            razon = hacia_luz / np.maximum(hacia_luz + hacia_sombra, 1)
            tonos = np.where(razon < 0.22, 3, np.where(razon < 0.6, 2, np.where(razon < 0.86, 1, 0)))
            tonos[(hacia_sombra < 1) & m] = 0
        if textura:
            ruido = np.array([[self.rng.random() < textura for _ in range(self.w)] for _ in range(self.h)])
            ruido = np.kron(ruido, np.ones((SS, SS), bool))
            sube = np.kron(np.array([[self.rng.random() < 0.5 for _ in range(self.w)] for _ in range(self.h)]),
                           np.ones((SS, SS), bool))
            tonos = np.where(ruido, np.where(sube & (tonos < 2), tonos + 1, tonos - 1), tonos)
        tonos = np.clip(tonos + tono, 0, 3)
        if sombra:
            # Sombra corta sobre lo que ya estaba dibujado detrás.
            caida = self.alfa & ~m & _corrida(m, int(0.5 * SS), int(1.2 * SS))
            self.rgb[caida] *= 0.68
            # Un borde oscuro donde la forma tapa a otra, como un contorno interior.
            anillo = np.zeros_like(m)
            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                anillo |= _corrida(m, dx * int(0.8 * SS), dy * int(0.8 * SS))
            anillo &= self.alfa & ~m
            self.rgb[anillo] *= 0.45
        self.rgb[m] = _RAMPAS_RGB[rampa][tonos[m]]
        self.alfa |= m

    def _e(self, cx, cy, rx, ry):
        return [(cx - rx) * SS, (cy - ry) * SS, (cx + rx) * SS, (cy + ry) * SS]

    def elipse(self, rampa, cx, cy, rx, ry, **kw):
        self.forma(rampa, lambda d: d.ellipse(self._e(cx, cy, rx, ry), fill=255), **kw)

    def poligono(self, rampa, puntos, **kw):
        self.forma(rampa, lambda d: d.polygon([(x * SS, y * SS) for x, y in puntos], fill=255), **kw)

    def capsula(self, rampa, x1, y1, x2, y2, r, **kw):
        def dib(d):
            d.line([(x1 * SS, y1 * SS), (x2 * SS, y2 * SS)], fill=255, width=int(2 * r * SS))
            d.ellipse(self._e(x1, y1, r, r), fill=255)
            d.ellipse(self._e(x2, y2, r, r), fill=255)
        self.forma(rampa, dib, **kw)

    def linea(self, rampa, puntos, ancho, **kw):
        self.forma(rampa, lambda d: d.line([(x * SS, y * SS) for x, y in puntos], fill=255,
                                           width=max(1, int(ancho * SS)), joint="curve"), plano=True, **kw)

    def punto(self, x, y, rampa, tono=0):
        """Un píxel exacto, para ojos, botones y otros detalles chicos."""
        self.puntos.append((int(x), int(y), _RAMPAS_RGB[rampa][tono] if rampa != "tinta" else _hex("#0e0d12")))

    def pix(self, x, y, rampa, tono=0, solo_encima=False):
        """Un píxel pintado en su capa: lo que se dibuje después lo tapa.

        Con `solo_encima`, solo pinta donde ya hay algo dibujado (para texturas).
        """
        x, y = int(x), int(y)
        if 0 <= x < self.w and 0 <= y < self.h:
            if solo_encima and not self.alfa[y * SS + SS // 2, x * SS + SS // 2]:
                return
            self.rgb[y * SS:(y + 1) * SS, x * SS:(x + 1) * SS] = _RAMPAS_RGB[rampa][tono]
            self.alfa[y * SS:(y + 1) * SS, x * SS:(x + 1) * SS] = True

    def brillo(self, rampa, intensidad=1):
        """Un halo de color alrededor de la figura (la rezadora, el Revisorio)."""
        self.brillos.append((rampa, intensidad))

    # --- resultado ---

    def imagen(self, contorno=True):
        bloques = self.alfa.reshape(self.h, SS, self.w, SS)
        cobertura = bloques.mean(axis=(1, 3))
        suma = (self.rgb * self.alfa[..., None]).reshape(self.h, SS, self.w, SS, 3).sum(axis=(1, 3))
        cuenta = bloques.sum(axis=(1, 3))[..., None]
        color = np.where(cuenta > 0, suma / np.maximum(cuenta, 1), 0)
        opaco = cobertura >= 0.45
        out = np.zeros((self.h, self.w, 4), dtype=np.uint8)
        for y, x, c in [(y, x, color[y, x]) for y in range(self.h) for x in range(self.w) if opaco[y, x]]:
            out[y, x, :3] = _cercano(c)
            out[y, x, 3] = 255
        for x, y, c in self.puntos:
            if 0 <= x < self.w and 0 <= y < self.h:
                out[y, x, :3] = c
                out[y, x, 3] = 255
        if contorno:
            out = _contorno(out)
        for rampa, intensidad in self.brillos:
            out = _halo(out, rampa, intensidad)
        return Image.fromarray(out, "RGBA")


def _cercano(c):
    return _PALETA[np.argmin(((_PALETA - c) ** 2).sum(axis=1))].astype(np.uint8)


def _contorno(px):
    """Contorno de un píxel del color del borde, muy oscurecido."""
    h, w = px.shape[:2]
    out = px.copy()
    for y in range(h):
        for x in range(w):
            if px[y, x, 3]:
                continue
            vecinos = [px[y + dy, x + dx, :3] for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1))
                       if 0 <= x + dx < w and 0 <= y + dy < h and px[y + dy, x + dx, 3]]
            if vecinos:
                c = np.mean(vecinos, axis=0) * 0.28 + np.array([6, 5, 8])
                out[y, x, :3] = _cercano(c)
                out[y, x, 3] = 255
    return out


def _halo(px, rampa, intensidad):
    h, w = px.shape[:2]
    out = px.copy()
    rgb = _RAMPAS_RGB[rampa]
    for anillo, (tono, a) in enumerate([(3, 150), (2, 70)][:1 + intensidad]):
        base = out.copy()
        for y in range(h):
            for x in range(w):
                if base[y, x, 3]:
                    continue
                if any(0 <= x + dx < w and 0 <= y + dy < h and base[y + dy, x + dx, 3] >= 60
                       for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1))):
                    out[y, x, :3] = rgb[tono]
                    out[y, x, 3] = a
    return out


# --- Humanoides ---

ANCHO, ALTO = 48, 64


class Humano:
    """Receta de un personaje humano: colores y accesorios por vista."""

    def __init__(self, piel, torso, piernas, botas, brazos=None, abrigo=None, abrigo_largo=45,
                 hombros=8.5, cabeza=(5.5, 6.0), falda=False, extras=None, semilla=1):
        self.piel, self.torso, self.piernas, self.botas = piel, torso, piernas, botas
        self.brazos = brazos or torso
        self.abrigo, self.abrigo_largo = abrigo, abrigo_largo
        self.hombros, self.cabeza, self.falda = hombros, cabeza, falda
        self.extras = extras or {}
        self.semilla = semilla

    def extra(self, momento, f, vista, cuadro):
        fn = self.extras.get(momento)
        if fn:
            fn(f, vista, cuadro)


def humano(h, vista, cuadro):
    f = Figura(ANCHO, ALTO, h.semilla)
    _HOMBROS[0] = h.hombros
    if vista == "lado":
        _humano_lado(h, f, cuadro)
    else:
        _humano_frente(h, f, vista, cuadro)
    return f.imagen()


def _humano_frente(h, f, vista, cuadro):
    cx = 24
    paso = cuadro == 1
    hy = 13
    sh = h.hombros
    h.extra("atras", f, vista, cuadro)
    if not h.falda:
        # Piernas y botas: en el paso, la izquierda se levanta.
        izq_fin = 55.0 if paso else 57.0
        f.capsula(h.piernas, cx - 3.6, 40, cx - 3.6, izq_fin, 2.9, textura=0.04)
        f.capsula(h.piernas, cx + 3.6, 40, cx + 3.6, 57, 2.9, textura=0.04, tono=-1 if vista == "frente" else 0)
        f.elipse(h.botas, cx - 3.6, izq_fin + 2.6, 3.6, 2.6)
        f.elipse(h.botas, cx + 3.6, 59.6, 3.6, 2.6)
    # Torso.
    f.poligono(h.torso, [(cx - sh + 1, 20.5), (cx + sh - 1, 20.5), (cx + sh, 22.5), (cx + sh - 1.5, 39),
                         (cx - sh + 1.5, 39), (cx - sh, 22.5)], textura=0.05)
    if h.abrigo:
        largo = h.abrigo_largo
        f.poligono(h.abrigo, [(cx - sh + 0.5, 34), (cx + sh - 0.5, 34), (cx + sh + 0.5, largo), (cx - sh - 0.5, largo)],
                   textura=0.06)
    h.extra("torso", f, vista, cuadro)
    # Brazos: en el paso se mecen un poco; al atacar, la mano derecha sube.
    for lado, hombro_x in (("izq", cx - sh - 0.6), ("der", cx + sh + 0.6)):
        mano = _mano(vista, cuadro, lado if vista == "frente" else ("der" if lado == "izq" else "izq"))
        f.capsula(h.brazos, hombro_x, 23.5, mano[0], mano[1] - 1.6 if mano[1] > 23.5 else mano[1] + 1.6, 2.5,
                  textura=0.05)
        f.elipse(h.piel, mano[0], mano[1], 2.2, 2.2)
    h.extra("manos", f, vista, cuadro)
    # Cuello y cabeza.
    f.poligono(h.piel, [(cx - 2, 17), (cx + 2, 17), (cx + 2.2, 21.5), (cx - 2.2, 21.5)], tono=-1)
    rx, ry = h.cabeza
    f.elipse(h.piel, cx - rx + 0.2, hy + 0.8, 1.3, 1.8, tono=-1)
    f.elipse(h.piel, cx + rx - 0.2, hy + 0.8, 1.3, 1.8, tono=-1)
    f.elipse(h.piel, cx, hy, rx, ry)
    if vista == "frente":
        f.punto(cx, hy + 1, h.piel, 3)
        f.punto(cx, hy + 2, h.piel, 1)
        f.punto(cx - 1, hy + 2, h.piel, 1)
        h.extra("cara", f, vista, cuadro)
    h.extra("cabeza", f, vista, cuadro)


def _humano_lado(h, f, cuadro):
    paso = cuadro >= 1
    hy = 13
    h.extra("atras", f, "lado", cuadro)
    # Brazo del fondo, más oscuro.
    lejos = _mano("lado", cuadro, "lejos")
    f.capsula(h.brazos, 24, 23.5, lejos[0], lejos[1] - 1.4, 2.3, tono=-1)
    f.elipse(h.piel, lejos[0], lejos[1], 2.0, 2.0, tono=-1)
    if not h.falda:
        atras = (20.5, 56.5) if paso else (23.0, 57.0)
        adelante = (28.5, 56.5) if paso else (25.5, 57.0)
        f.capsula(h.piernas, 24, 40, atras[0], atras[1], 3.0, tono=-1, textura=0.04)
        f.elipse(h.botas, atras[0] + 1.4, atras[1] + 2.6, 3.8, 2.5, tono=-1)
        f.capsula(h.piernas, 24.5, 40, adelante[0], adelante[1], 3.0, textura=0.04)
        f.elipse(h.botas, adelante[0] + 1.4, adelante[1] + 2.6, 3.8, 2.5)
    f.poligono(h.torso, [(19.5, 21.5), (28.0, 21.0), (29.0, 30), (28.0, 39), (20.0, 39), (19.0, 30)], textura=0.05)
    if h.abrigo:
        f.poligono(h.abrigo, [(19.5, 34), (28.5, 34), (29.5, h.abrigo_largo), (18.5, h.abrigo_largo)], textura=0.06)
    h.extra("torso", f, "lado", cuadro)
    cerca = _mano("lado", cuadro, "cerca")
    f.capsula(h.brazos, 24.5, 23.5, cerca[0], cerca[1] - 1.5 if cuadro < 2 else cerca[1], 2.4, textura=0.05)
    f.elipse(h.piel, cerca[0], cerca[1], 2.1, 2.1)
    h.extra("manos", f, "lado", cuadro)
    f.poligono(h.piel, [(22, 17), (26, 17), (26.5, 21.5), (21.5, 21.5)], tono=-1)
    rx, ry = h.cabeza
    f.elipse(h.piel, 24.5, hy, rx - 0.5, ry)
    f.elipse(h.piel, 29.3, hy + 1.0, 1.4, 1.3, sombra=False)  # nariz
    h.extra("cara", f, "lado", cuadro)
    h.extra("cabeza", f, "lado", cuadro)


def _ojos(f, vista, ojo="tinta", y=13, separacion=2.5, cx=24, brillo=None):
    if vista == "frente":
        for x in (cx - separacion, cx + separacion - 1):
            f.punto(x, y, ojo, 0)
            if brillo:
                f.punto(x, y - 1, brillo, 3)
    elif vista == "lado":
        f.punto(27, y, ojo, 0)


_HOMBROS = [8.5]


def _mano(vista, cuadro, lado):
    """Dónde queda una mano: 'izq' o 'der' (del personaje) en frente y espalda, 'cerca' o
    'lejos' de lado. Cuadro 0 es quieto, 1 es el paso y 2 es el ataque."""
    paso = cuadro == 1
    ataque = cuadro == 2
    if vista == "lado":
        if lado == "cerca":
            return (34.0, 27.0) if ataque else ((21.0, 37.5) if paso else (25.5, 38.5))
        return (21.5, 36.5) if ataque else ((27.5, 36.9) if paso else (24.0, 38.4))
    sh = _HOMBROS[0]
    mece = 1.2 if paso else 0.0
    # En la espalda, la derecha del personaje queda a la izquierda de quien mira.
    a_la_derecha = (lado == "der") == (vista == "frente")
    if ataque and lado == "der":
        return (24 + sh + 2.5, 13.0) if a_la_derecha else (24 - sh - 2.5, 13.0)
    return (24 + sh + 1.4, 38.8 + mece) if a_la_derecha else (24 - sh - 1.4, 38.8 - mece)


# --- Abdón Cárcamo ---

def _abdon_cara(f, vista, cuadro):
    if vista == "frente":
        f.poligono("pelo_gris", [(19, 14), (20.5, 16), (24, 16.5), (27.5, 16), (29, 14), (28.5, 18.5),
                                 (24, 20.5), (19.5, 18.5)], textura=0.125)
        f.punto(23, 17, "piel", 0)
        f.punto(24, 17, "piel", 1)
        f.punto(25, 17, "piel", 0)
        _ojos(f, vista)
        f.punto(21, 11, "pelo_gris", 1)
        f.punto(22, 11, "pelo_gris", 1)
        f.punto(26, 11, "pelo_gris", 1)
        f.punto(27, 11, "pelo_gris", 1)
    else:
        f.poligono("pelo_gris", [(22, 14), (29.5, 15), (29, 18.5), (25, 19.5), (22, 17)], tono=-1, textura=0.15)
        _ojos(f, vista)


def _abdon_cabeza(f, vista, cuadro):
    # Gorra marinera azul con visera.
    if vista == "lado":
        f.elipse("marino", 24, 8.6, 6.0, 3.0, textura=0.05)
        f.poligono("marino", [(26, 9.5), (31.5, 10), (31, 11.2), (26, 11)], tono=-1)
        f.poligono("pelo_gris", [(19.2, 10.5), (22, 10.5), (22, 15), (19.5, 14)], tono=-1, textura=0.15)
    else:
        f.elipse("marino", 24, 8.4, 6.4, 3.0, textura=0.05)
        if vista == "frente":
            f.poligono("marino", [(18.4, 10), (29.6, 10), (28.8, 11.6), (19.2, 11.6)], tono=-1)
        else:
            f.poligono("pelo_gris", [(19, 10), (29, 10), (28.5, 15), (19.5, 15)], tono=-1, textura=0.175)


def _farol(f, x, y):
    f.linea("metal", [(x, y), (x, y + 2.5)], 0.6, tono=-1)
    f.poligono("metal", [(x - 2.4, y + 2.6), (x + 2.4, y + 2.6), (x + 2.0, y + 3.6), (x - 2.0, y + 3.6)], tono=-1)
    f.poligono("fuego", [(x - 2.0, y + 3.6), (x + 2.0, y + 3.6), (x + 2.0, y + 8.5), (x - 2.0, y + 8.5)], plano=True, tono=1)
    f.linea("metal", [(x - 2.2, y + 3.6), (x - 2.2, y + 8.5)], 0.6, tono=-1)
    f.linea("metal", [(x + 2.2, y + 3.6), (x + 2.2, y + 8.5)], 0.6, tono=-1)
    f.poligono("metal", [(x - 2.6, y + 8.4), (x + 2.6, y + 8.4), (x + 2.6, y + 9.6), (x - 2.6, y + 9.6)], tono=-1)
    f.punto(x, y + 6, "fuego", 3)


def _arpon(f, x1, y1, x2, y2):
    f.linea("madera", [(x1, y1), (x2, y2)], 1.2)
    dx, dy = x2 - x1, y2 - y1
    largo = math.hypot(dx, dy)
    ux, uy = dx / largo, dy / largo
    px, py = -uy, ux
    punta = (x2 + ux * 4.5, y2 + uy * 4.5)
    f.poligono("metal", [(x2 + px * 1.6, y2 + py * 1.6), punta, (x2 - px * 1.6, y2 - py * 1.6)], tono=1)
    f.linea("metal", [(x2 + ux * 1.5 + px * 1.8, y2 + uy * 1.5 + py * 1.8), (x2 - ux * 0.5 + px * 2.6, y2 - uy * 0.5 + py * 2.6)], 0.6)


def _abdon_manos(f, vista, cuadro):
    ataque = cuadro == 2
    if vista in ("frente", "espalda"):
        x, y = _mano(vista, cuadro, "izq")
        _farol(f, x, y)
        x, y = _mano(vista, cuadro, "der")
        if ataque:
            _arpon(f, x, y + 12, x, y - 6)  # el arpón en alto, listo para clavar
        elif vista == "frente":
            _arpon(f, x - 6, y - 8, x + 6, y + 8)
        else:
            _arpon(f, x + 6, y - 8, x - 6, y + 8)
    elif ataque:
        x, y = _mano(vista, cuadro, "lejos")
        _farol(f, x, y)
        x, y = _mano(vista, cuadro, "cerca")
        _arpon(f, x - 17, y + 1.5, x + 4, y - 0.5)
    else:
        x, y = _mano(vista, cuadro, "cerca")
        _farol(f, x, y)


def _abdon_atras(f, vista, cuadro):
    if vista == "lado" and cuadro < 2:
        _arpon(f, 15, 22, 33, 44)


ABDON = Humano(
    piel="piel", torso="lana_cafe", piernas="marino", botas="bota", abrigo="lana_cafe", abrigo_largo=46,
    extras={"cara": _abdon_cara, "cabeza": _abdon_cabeza, "manos": _abdon_manos, "atras": _abdon_atras},
)


# --- Finaos ---

def _ojos_finao(f, vista, cuadro):
    if vista == "frente":
        for x in (21, 26):
            f.punto(x, 12, "finao", 0)
            f.punto(x, 13, "blanco", 3)
        f.punto(23, 16, "finao", 0)
        f.punto(24, 16, "finao", 0)
        f.punto(25, 16, "finao", 0)
    else:
        f.punto(27, 12, "finao", 0)
        f.punto(27, 13, "blanco", 3)
        f.punto(28, 16, "finao", 0)


def _pelo(rampa, calvo=False):
    def dib(f, vista, cuadro):
        if vista == "lado":
            if calvo:
                f.poligono(rampa, [(19, 10), (22, 9.5), (22.5, 15), (19.4, 14)], tono=-1, textura=0.15)
            else:
                f.elipse(rampa, 23.5, 9, 5.6, 3.6, textura=0.15)
                f.poligono(rampa, [(18.8, 9), (23, 9), (22.5, 16), (19.2, 15)], textura=0.15)
        elif calvo:
            f.poligono(rampa, [(18.4, 10), (20, 9.6), (20.2, 15), (18.6, 14)], tono=-1, textura=0.15)
            f.poligono(rampa, [(29.6, 10), (28, 9.6), (27.8, 15), (29.4, 14)], tono=-1, textura=0.15)
            if vista == "espalda":
                f.poligono(rampa, [(19, 12), (29, 12), (28.5, 16), (19.5, 16)], tono=-1, textura=0.15)
        else:
            f.elipse(rampa, 24, 8.8, 5.9, 3.6, textura=0.15)
            if vista == "espalda":
                f.poligono(rampa, [(18.2, 9), (29.8, 9), (29, 16), (19, 16)], textura=0.15)
    return dib


def _junta(*fns):
    def dib(f, vista, cuadro):
        for fn in fns:
            fn(f, vista, cuadro)
    return dib


def _pescador_manos(f, vista, cuadro):
    """Arrastra un pedazo de red de pesca."""
    if vista == "frente":
        x, y = _mano(vista, cuadro, "izq")
    elif vista == "espalda":
        x, y = _mano(vista, cuadro, "der")
    else:
        x, y = _mano(vista, cuadro, "lejos")
    for i in range(4):
        f.linea("lana_gris", [(x - 1 + i, y + 1), (x - 4 + i * 1.5, y + 13 + i % 2)], 0.5, tono=1)
    for j in range(3):
        yy = y + 4 + j * 3.5
        f.linea("lana_gris", [(x - 2.5, yy), (x + 3, yy + 0.8)], 0.5, tono=1)


def _capucha(f, vista, cuadro):
    if vista == "lado":
        f.poligono("impermeable", [(18.5, 18), (23, 17), (24, 22), (19, 23)], tono=-1)
    else:
        f.poligono("impermeable", [(18, 19), (30, 19), (31, 23), (17, 23)], tono=-1 if vista == "frente" else 0)


def _pescador_torso(f, vista, cuadro):
    if vista == "frente":
        for y in (26, 30, 34, 38):
            f.punto(24, y, "impermeable", 0)
        f.linea("impermeable", [(24, 22), (24, 45)], 0.4, tono=-2)
        f.elipse("musgo", 20, 41, 1.8, 1.0, textura=0.15)
        f.elipse("musgo", 29, 32, 1.4, 0.9, textura=0.15)


def _apron(f, vista, cuadro):
    if vista == "frente":
        f.poligono("cuero", [(18.5, 26), (29.5, 26), (30.5, 47), (17.5, 47)], textura=0.075)
        f.linea("cuero", [(18.8, 26), (17.5, 21.5)], 0.9, tono=-1)
        f.linea("cuero", [(29.2, 26), (30.5, 21.5)], 0.9, tono=-1)
        f.poligono("cuero", [(21.5, 34), (26.5, 34), (26.5, 37.5), (21.5, 37.5)], tono=-1)
    elif vista == "espalda":
        f.linea("cuero", [(17.5, 21.5), (30, 36)], 0.9, tono=-1)
        f.linea("cuero", [(30.5, 21.5), (18, 36)], 0.9, tono=-1)
        f.linea("cuero", [(16.5, 37), (31.5, 37)], 0.9, tono=-1)
    else:
        f.poligono("cuero", [(26, 26), (29.8, 26), (30.5, 47), (25.5, 47)], textura=0.075)
        f.linea("cuero", [(27, 26), (24, 21.5)], 0.9, tono=-1)
    # Pecho y brazos marcados.
    if vista == "frente":
        f.linea("finao", [(20, 23.5), (23.5, 24.5)], 0.5, tono=-1)
        f.linea("finao", [(28, 23.5), (24.5, 24.5)], 0.5, tono=-1)


def _martillo(f, vista, cuadro):
    if vista == "frente":
        x, y = _mano(vista, cuadro, "der")
    elif vista == "espalda":
        x, y = _mano(vista, cuadro, "izq")
    else:
        x, y = _mano(vista, cuadro, "cerca")
    if cuadro == 2:
        # El martillo arriba, a punto de caer.
        f.linea("madera", [(x, y + 1), (x + 1, y - 8)], 1.2)
        f.poligono("metal", [(x - 2, y - 11), (x + 4, y - 11), (x + 4, y - 8), (x - 2, y - 8)])
        return
    f.linea("madera", [(x, y - 1), (x, y + 8)], 1.2)
    f.poligono("metal", [(x - 2.8, y + 7), (x + 2.8, y + 7), (x + 2.8, y + 10), (x - 2.8, y + 10)])


def _bigote(f, vista, cuadro):
    if vista == "frente":
        f.poligono("pelo_negro", [(21, 15.6), (27, 15.6), (27.5, 17), (20.5, 17)])
    else:
        f.poligono("pelo_negro", [(26.5, 15.5), (29.8, 15.6), (29.5, 16.8), (26.5, 16.8)])


def _fermin_torso(f, vista, cuadro):
    if vista == "frente":
        f.poligono("blanco", [(21.5, 21), (26.5, 21), (24, 30)], plano=True)
        f.poligono("rojo", [(23.3, 21.5), (24.7, 21.5), (25.2, 29), (24, 30.5), (22.8, 29)])
        f.linea("traje", [(21.5, 21), (24, 30.5), (26.5, 21)], 0.7, tono=-1)
        for y in (33, 37):
            f.punto(24, y, "traje", 0)
    elif vista == "lado":
        f.poligono("blanco", [(27, 21), (28.4, 21.2), (28.4, 25), (27, 25)], plano=True)


def _fermin_manos(f, vista, cuadro):
    """Una libreta de cuentas que no suelta ni muerto."""
    if vista == "frente":
        f.poligono("blanco", [(27.2, 28.5), (33.5, 27), (34.5, 35), (28.2, 36.5)])
        for y in (30.0, 31.6, 33.2):
            f.linea("lana_gris", [(28.6, y + 0.4), (33, y - 0.6)], 0.35, tono=1)
        f.elipse("piel_palida", 28.5, 33, 1.8, 1.8)
    elif vista == "lado":
        f.poligono("blanco", [(26, 28.5), (31, 27.6), (31.5, 34), (26.5, 34.8)])
        f.elipse("piel_palida", 26.5, 32, 1.8, 1.8)


def _lentes(f, vista, cuadro):
    if vista == "frente":
        for x in (21, 26):
            f.punto(x - 1, 12, "metal", 2)
            f.punto(x + 1, 12, "metal", 2)
            f.punto(x, 12, "metal", 3)
            f.punto(x, 13, "tinta")
        f.punto(23, 12, "metal", 2)
        f.punto(24, 12, "metal", 2)
        f.punto(23, 16, "piel_palida", 0)
        f.punto(24, 16, "piel_palida", 0)
        f.punto(25, 16, "piel_palida", 0)
        for x in (20, 21, 26, 27):
            f.punto(x, 11, "pelo_gris", 0)
        f.punto(22, 17, "piel_palida", 1)
        f.punto(26, 17, "piel_palida", 1)
    else:
        f.punto(26, 12, "metal", 2)
        f.punto(28, 12, "metal", 2)
        f.punto(27, 13, "tinta")
        f.punto(28, 16, "piel_palida", 0)


def _monja_cabeza(f, vista, cuadro):
    if vista == "lado":
        f.poligono("monja", [(18, 6), (26.5, 5.5), (28, 9), (27, 9), (24, 22), (17, 28), (16.5, 14)], textura=0.05)
        f.poligono("blanco", [(26, 8.5), (28.6, 9), (28.4, 18.5), (26.5, 19)], plano=True)
    elif vista == "frente":
        f.poligono("monja", [(17.5, 8), (24, 4.5), (30.5, 8), (32, 26), (16, 26)], textura=0.05)
        f.elipse("blanco", 24, 13.5, 5.6, 6.2, plano=True)
        f.elipse("piel_palida", 24, 14, 4.4, 5.0)
        f.punto(22, 13, "monja", 0)
        f.punto(26, 13, "monja", 0)
        f.punto(24, 16, "piel_palida", 0)
    else:
        f.poligono("monja", [(17.5, 8), (24, 4.5), (30.5, 8), (32, 28), (16, 28)], textura=0.05)


def _rosario(f, vista, cuadro):
    if vista == "frente":
        f.elipse("piel_palida", 24, 33, 2.4, 2.0)
        for i, (x, y) in enumerate([(23, 35), (23, 36), (24, 37), (24, 38), (23, 39), (24, 40)]):
            f.punto(x, y, "blanco", 3 if i % 2 else 2)
        f.punto(24, 41, "oro", 3)
        f.punto(23, 42, "oro", 2)
        f.punto(25, 42, "oro", 2)
        f.punto(24, 43, "oro", 2)


def _habito(f, vista, cuadro):
    """La rezadora no camina: flota dentro del hábito, que roza el suelo."""
    vuelo = 0.8 if cuadro else 0.0
    if vista == "lado":
        f.poligono("monja", [(19, 21), (28, 21), (30.5, 61), (17 - vuelo, 61)], textura=0.05)
    else:
        f.poligono("monja", [(15.5, 21), (32.5, 21), (35 + vuelo, 61.5), (13 - vuelo, 61.5)], textura=0.05)
        f.linea("monja", [(24, 30), (24, 61)], 0.5, tono=-1)
        if vista == "frente":
            f.linea("monja", [(19, 35), (17, 61)], 0.5, tono=-1)
            f.linea("monja", [(29, 35), (31, 61)], 0.5, tono=-1)


def _poncho(f, vista, cuadro):
    if vista == "lado":
        f.poligono("rojo", [(18.5, 21), (29, 20.5), (31, 38), (17, 38)], textura=0.075)
        f.linea("paja", [(17.5, 33), (30.5, 33)], 0.7)
    else:
        f.poligono("rojo", [(14.5, 22), (24, 19), (33.5, 22), (35, 38), (13, 38)], textura=0.075)
        for y in (27, 33):
            f.linea("paja", [(14.5, y), (34, y)], 0.7)
        if vista == "frente":
            f.poligono("rojo", [(21, 19.5), (27, 19.5), (24, 23)], tono=-1)


def _chupalla(f, vista, cuadro):
    f.elipse("paja", 24, 8.6, 9.5 if vista != "lado" else 8.5, 2.2, textura=0.125)
    f.elipse("paja", 24, 6.4, 5.2, 3.4, textura=0.125)
    f.linea("cuero", [(19, 7.8), (29, 7.8)], 0.7, tono=-1)


def _ojos_ahogado(f, vista, cuadro):
    if vista == "frente":
        for x in (21, 26):
            f.punto(x, 13, "rojo", 3)
        f.punto(23, 16, "ahogado", 0)
        f.punto(24, 16, "ahogado", 0)
        f.punto(25, 16, "ahogado", 0)
    else:
        f.punto(27, 13, "rojo", 3)


def _algas(f, vista, cuadro):
    if vista != "lado":
        f.linea("musgo", [(17, 22), (18.5, 30), (17.5, 37)], 1.0, tono=1)
        f.linea("musgo", [(29, 23), (30, 29)], 1.0)
        f.linea("musgo", [(22, 36), (21.5, 44)], 0.8, tono=1)
    else:
        f.linea("musgo", [(22, 22), (21, 31), (22.5, 38)], 1.0, tono=1)


def _harapos(f, vista, cuadro):
    for i, x in enumerate(range(17, 32, 3)):
        f.poligono("lana_gris", [(x, 45), (x + 2.6, 45), (x + 1.3, 47.5 + (i % 2) * 1.5)], tono=-1)


FINAO_CARPINTERO = Humano(
    piel="finao", torso="finao", brazos="finao", piernas="lana_gris", botas="bota", hombros=9.3,
    extras={"cara": _junta(_ojos_finao, _bigote), "cabeza": _pelo("pelo_negro"), "torso": _apron, "manos": _martillo},
    semilla=3,
)
FINAO_PESCADOR = Humano(
    piel="ahogado", torso="impermeable", piernas="lana_gris", botas="bota", abrigo="impermeable", abrigo_largo=47,
    extras={"cara": _ojos_finao, "cabeza": _junta(_pelo("pelo_gris", calvo=True), _capucha), "torso": _pescador_torso,
            "manos": _pescador_manos},
    semilla=4,
)
FINAO_FERMIN = Humano(
    piel="piel_palida", torso="traje", piernas="traje", botas="bota", abrigo="traje", abrigo_largo=43, hombros=8.0,
    extras={"cara": _lentes, "cabeza": _pelo("pelo_gris", calvo=True), "torso": _fermin_torso, "manos": _fermin_manos},
    semilla=5,
)
FINAO_REZADORA = Humano(
    piel="piel_palida", torso="monja", piernas="monja", botas="monja", hombros=8.0, falda=True,
    extras={"atras": _habito, "cabeza": _monja_cabeza, "torso": _rosario},
    semilla=6,
)
FINAO_CONTRABANDISTA = Humano(
    piel="finao", torso="lana_gris", piernas="marino", botas="bota",
    extras={"cara": _junta(_ojos_finao, _bigote), "cabeza": _chupalla, "torso": _poncho},
    semilla=7,
)
AHOGADO = Humano(
    piel="ahogado", torso="lana_gris", piernas="lana_gris", botas="ahogado", abrigo="lana_gris", abrigo_largo=45,
    extras={"cara": _ojos_ahogado, "cabeza": _pelo("pelo_negro"), "torso": _junta(_algas, _harapos)},
    semilla=8,
)


# --- Entes ---

def trauco(vista, cuadro):
    """Bajo, encorvado, cubierto de musgo, con su hacha de piedra."""
    f = Figura(ANCHO, ALTO, 9)
    paso = cuadro == 1
    ataque = cuadro == 2
    if vista == "lado":
        f.capsula("trauco", 26, 40, 34 if paso else 29, 46, 2.8, tono=-1)  # brazo del fondo
        f.capsula("trauco", 23, 46, 19 if paso else 21, 58, 3.6, tono=-1, textura=0.075)
        f.elipse("trauco", (19 if paso else 21) + 1.5, 60, 4.2, 2.4, tono=-1)
        f.capsula("trauco", 26, 46, 30 if paso else 27, 58, 3.6, textura=0.075)
        f.elipse("trauco", (30 if paso else 27) + 1.8, 60, 4.2, 2.4)
        f.elipse("trauco", 24, 39, 9.5, 10, textura=0.1)
        f.elipse("musgo", 21, 33, 7, 5, textura=0.175)
        f.poligono("paja", [(16, 44), (31, 44), (32, 50), (15, 50)], textura=0.15)
        f.elipse("trauco", 32, 31, 5.5, 5.5)
        f.poligono("trauco", [(35, 30), (38.5, 32), (35.5, 33.5)])
        f.poligono("musgo", [(28, 33), (36, 34), (33, 39), (29, 38)], textura=0.2)
        f.punto(34, 30, "ojo", 3)
        f.poligono("trauco", [(27, 26), (24, 24.5), (27.5, 29)], tono=-1)  # oreja
        mano = (33, 34) if ataque else ((22, 50) if paso else (27, 50))
        f.capsula("trauco", 28, 34, mano[0], mano[1], 3.0, textura=0.075)
        f.linea("madera", [(mano[0], mano[1] + 2), (mano[0] + 9, mano[1] - 12)], 1.6)
        f.poligono("piedra", [(mano[0] + 7, mano[1] - 17), (mano[0] + 13, mano[1] - 13),
                              (mano[0] + 10, mano[1] - 7), (mano[0] + 5.5, mano[1] - 11)], textura=0.15)
        f.elipse("trauco", mano[0], mano[1] + 1, 2.8, 2.6)
        return f.imagen()
    sube = 1.5 if paso else 0.0
    f.capsula("trauco", 19, 46, 15, 58 - sube, 3.8, textura=0.075)
    f.capsula("trauco", 29, 46, 33, 58, 3.8, textura=0.075, tono=-1)
    f.elipse("trauco", 14.5, 60 - sube, 4.4, 2.4)
    f.elipse("trauco", 33.5, 60, 4.4, 2.4)
    f.elipse("trauco", 24, 39, 12.5, 10.5, textura=0.1)
    f.poligono("paja", [(14, 44), (34, 44), (35, 51), (13, 51)], textura=0.15)
    f.elipse("musgo", 15.5, 31, 5.5, 4, textura=0.175)
    f.elipse("musgo", 32.5, 31, 5.5, 4, textura=0.175, tono=-1)
    if vista == "frente":
        f.elipse("trauco", 24, 29, 6.5, 6.0)
        f.poligono("trauco", [(17.8, 27), (14, 24.5), (18.5, 30)], tono=-1)
        f.poligono("trauco", [(30.2, 27), (34, 24.5), (29.5, 30)], tono=-1)
        f.poligono("musgo", [(19.5, 31.5), (28.5, 31.5), (27, 37), (24, 38.5), (21, 37)], textura=0.2)
        f.linea("trauco", [(20, 26.6), (23, 27.4)], 0.8, tono=-2)
        f.linea("trauco", [(28, 26.6), (25, 27.4)], 0.8, tono=-2)
        f.punto(21, 28, "ojo", 3)
        f.punto(26, 28, "ojo", 3)
        f.punto(23, 31, "pelo_negro", 0)
        f.punto(24, 31, "blanco", 3)
        f.punto(25, 31, "pelo_negro", 0)
    else:
        f.elipse("trauco", 24, 29, 6.5, 6.0, tono=-1)
        f.elipse("musgo", 24, 30, 6.0, 4.0, textura=0.2)
    f.capsula("trauco", 15, 32, 11 + (0 if paso else 1), 50 - sube, 3.0, textura=0.075)
    hx, hy = (38, 30) if ataque else (37, 50 + sube)
    f.capsula("trauco", 33, 32, hx, hy - 1, 3.0, textura=0.075)
    f.linea("madera", [(hx - 1, hy + 3), (hx + 3, hy - 14)], 1.6)
    f.poligono("piedra", [(hx - 1, hy - 18), (hx + 7, hy - 16), (hx + 6, hy - 10), (hx + 0.5, hy - 12)], textura=0.15)
    f.elipse("trauco", hx, hy, 2.9, 2.7)
    f.elipse("trauco", 11, 51 - sube, 2.9, 2.7)
    return f.imagen()


def fiura(vista, cuadro):
    """Mujer pequeña de cara horrible, pelo negro hasta la cintura y vestido rojo."""
    f = Figura(ANCHO, ALTO, 10)
    paso = cuadro == 1
    ataque = cuadro == 2
    cx = 24 if vista != "lado" else 24.5
    hy = 24
    f.poligono("pelo_negro", [(cx - 7, hy - 4), (cx + 7, hy - 4), (cx + 8.5, hy + 22), (cx - 8.5, hy + 22)], textura=0.075)
    if vista == "lado":
        f.poligono("pelo_negro", [(cx - 8, hy - 3), (cx + 2, hy - 4), (cx, hy + 24), (cx - 10, hy + 23)], textura=0.075)
    f.capsula("fiura", cx - 2.5, 50, cx - 2.5 - (2 if paso else 0), 58, 2.0, tono=-1)
    f.capsula("fiura", cx + 2.5, 50, cx + 2.5 + (2 if paso else 0), 58, 2.0)
    f.elipse("fiura", cx - 2.5 - (2 if paso else 0), 60, 2.8, 1.8, tono=-1)
    f.elipse("fiura", cx + 2.5 + (2 if paso else 0), 60, 2.8, 1.8)
    f.poligono("rojo", [(cx - 6, hy + 7), (cx + 6, hy + 7), (cx + 9, 53), (cx - 9, 53)], textura=0.075)
    for x in range(int(cx - 8), int(cx + 9), 3):
        f.poligono("rojo", [(x, 52.5), (x + 2.5, 52.5), (x + 1.2, 55)], tono=-1)
    # Al atacar levanta las garras.
    mano_y = 27 if ataque else 40 + (1.5 if paso else 0)
    otra_y = 27 if ataque else 40 + (0 if paso else 1.5)
    abre = 12 if ataque else 9.5
    f.capsula("fiura", cx - 6, hy + 9, cx - abre, mano_y, 1.8)
    f.capsula("fiura", cx + 6, hy + 9, cx + abre, otra_y, 1.8)
    for sx, my in ((-abre, mano_y), (abre, otra_y)):
        for d in (-1.2, 0, 1.2):
            f.linea("blanco", [(cx + sx + d, my + 1.2), (cx + sx + d * 1.5, my + 3.6)], 0.4, tono=1)
    f.elipse("fiura", cx, hy, 5.5, 6.0)
    f.poligono("pelo_negro", [(cx - 6, hy - 1), (cx - 3, hy - 7), (cx + 4, hy - 7.5), (cx + 6.5, hy - 1),
                              (cx + 4, hy - 4), (cx - 3, hy - 4)], textura=0.075)
    if vista == "frente":
        f.punto(cx - 3, hy, "ojo", 3)
        f.punto(cx + 2, hy, "ojo", 3)
        f.punto(cx - 3, hy + 1, "rojo", 1)
        f.punto(cx + 2, hy + 1, "rojo", 1)
        f.linea("pelo_negro", [(cx - 2.5, hy + 3.5), (cx + 2.5, hy + 3.5)], 0.9)
        f.punto(cx - 2, hy + 4, "blanco", 3)
        f.punto(cx + 1, hy + 4, "blanco", 3)
        f.punto(cx - 1, hy + 2, "fiura", 0)
    elif vista == "lado":
        f.elipse("fiura", cx + 5, hy + 1.5, 2.0, 1.4, sombra=False)
        f.punto(cx + 3, hy, "ojo", 3)
        f.linea("pelo_negro", [(cx + 2, hy + 3.5), (cx + 5, hy + 3.5)], 0.8)
        f.punto(cx + 4, hy + 4, "blanco", 3)
        f.poligono("pelo_negro", [(cx - 6, hy - 6), (cx + 1, hy - 7.5), (cx, hy + 8), (cx - 6.5, hy + 10)], textura=0.075)
    return f.imagen()


def invunche(vista, cuadro):
    """Guardián de la cueva: anda en tres patas, con una pierna torcida sobre la espalda."""
    f = Figura(56, 48, 11)
    paso = cuadro == 1
    ataque = cuadro == 2
    adelante = 3 if ataque else 0
    f.elipse("invunche", 26, 28, 14, 8, textura=0.1)
    f.capsula("invunche", 18, 25, 26, 13, 3.0, textura=0.075, tono=-1)  # la pierna torcida
    f.elipse("invunche", 27, 11, 3.4, 2.6, tono=-1)
    f.capsula("invunche", 36, 30, 40, 42, 3.6, textura=0.075)
    f.elipse("invunche", 41, 44, 4.0, 2.2)
    f.capsula("invunche", 16, 31, 13 - (1.5 if paso else 0), 43, 3.2, textura=0.075, tono=-1)
    f.elipse("invunche", 12 - (1.5 if paso else 0), 44.5, 3.8, 2.0, tono=-1)
    f.capsula("invunche", 24, 32, 26 + (1.5 if paso else 0), 43, 3.0, textura=0.075)
    f.elipse("invunche", 27 + (1.5 if paso else 0), 44.5, 3.8, 2.0)
    for x in (19, 23, 27, 31):
        f.linea("invunche", [(x, 23), (x + 1.5, 30)], 0.5, tono=-2)
    hx = 44 + adelante
    f.elipse("invunche", hx, 27, 6.5, 6.0)
    f.poligono("pelo_negro", [(hx - 5.5, 24), (hx - 2, 20.5), (hx + 4, 21), (hx + 6, 25), (hx + 2, 23)], textura=0.2)
    f.punto(hx - 1, 26, "ojo", 3)
    f.punto(hx + 3, 26, "ojo", 3)
    f.punto(hx - 1, 27, "rojo", 0)
    f.punto(hx + 3, 27, "rojo", 0)
    if ataque:
        f.elipse("traje", hx + 1, 31, 3.0, 2.0, plano=True, tono=0)
        for x in (hx - 1, hx + 1, hx + 3):
            f.punto(x, 30, "blanco", 3)
    else:
        f.linea("pelo_negro", [(hx - 2, 30.5), (hx + 4, 30.5)], 0.9)
        for x in (hx - 1, hx + 1, hx + 3):
            f.punto(x, 31, "blanco", 2)
    return f.imagen()


def chonchon(vista, cuadro):
    """La cabeza del brujo que vuela de noche con las orejas hechas alas."""
    f = Figura(48, 48, 12)
    aleteo = -3.0 if cuadro == 1 else (2.0 if cuadro == 2 else 0.0)
    ataque = cuadro == 2
    for lado in (-1, 1):
        base_x = 24 + lado * 6
        for i, rampa in enumerate(["pluma_naranja", "pluma_azul", "pluma_naranja", "pluma_azul", "pluma_naranja"]):
            ang = math.radians(-60 + i * 22) if lado > 0 else math.radians(180 + 60 - i * 22)
            largo = 15 - abs(i - 2) * 1.5
            tx = base_x + math.cos(ang) * largo
            ty = 20 + math.sin(ang) * largo * 0.8 + aleteo * (1 - abs(i - 2) / 3)
            f.capsula(rampa, base_x, 21, tx, ty, 1.8 - abs(i - 2) * 0.15, textura=0.1)
    f.elipse("piel_palida", 24, 22, 7.5, 8.5)
    f.poligono("pelo_gris", [(16.5, 20), (19, 14), (24, 13), (29, 14), (31.5, 20), (29, 17), (19, 17)], textura=0.2)
    f.poligono("pluma_azul", [(19, 14), (22, 4), (24, 13)], textura=0.1)
    f.poligono("pluma_naranja", [(24, 13), (27, 5), (29, 14)], textura=0.1)
    for x in (20.5, 27.5):
        f.elipse("rojo" if ataque else "ojo", x, 21.5, 2.4, 2.4, plano=True, tono=3)
        f.punto(x - 0.5, 21, "tinta")
    f.elipse("piel_palida", 24, 25, 1.6, 2.0, tono=-1)
    if ataque:
        # Abre la boca para el grito: ¡tue, tue!
        f.elipse("traje", 24, 29, 3.2, 2.4, plano=True, tono=0)
        f.punto(23, 28, "blanco", 3)
        f.punto(25, 28, "blanco", 3)
    else:
        f.linea("rojo", [(21, 28.5), (24, 29.5), (27, 28.5)], 0.8, tono=-1)
    f.poligono("pelo_gris", [(19, 30), (29, 30), (26, 34), (24, 36), (22, 34)], textura=0.2, tono=-1)
    return f.imagen()


# --- Ítems (32x32) ---

def _item():
    return Figura(32, 32, 20)


def item_pescado():
    f = _item()
    f.poligono("plata", [(4, 17), (10, 11), (20, 10), (26, 15), (20, 21), (10, 21)], textura=0.075)
    f.poligono("plata", [(25, 15), (30, 10), (29, 16), (30, 22)], tono=-1)
    f.poligono("marino", [(9, 12), (20, 10.5), (25, 14.5), (12, 14)], tono=1)
    f.punto(8, 15, "tinta")
    f.punto(8, 14, "blanco", 3)
    f.linea("plata", [(11, 13), (11, 20)], 0.4, tono=-2)
    return f.imagen()


def item_ahumado():
    f = _item()
    f.linea("paja", [(15, 2), (16, 7)], 0.6)
    f.poligono("cuero", [(13, 7), (19, 7), (21, 16), (18.5, 27), (16, 30), (13.5, 27), (11, 16)], textura=0.125)
    f.poligono("oro", [(14, 9), (17, 9), (18, 15), (14, 22)], tono=-1, textura=0.15)
    f.poligono("cuero", [(13, 27), (19, 27), (21, 31), (16, 29), (11, 31)], tono=-1)
    f.linea("cuero", [(12, 13), (20, 13)], 0.4, tono=-2)
    f.linea("cuero", [(12, 18), (20, 18)], 0.4, tono=-2)
    return f.imagen()


def item_sal():
    f = _item()
    f.poligono("sal", [(7, 12), (25, 12), (27, 28), (5, 28)], textura=0.1)
    f.elipse("sal", 16, 28, 11, 2.5, tono=-1)
    f.poligono("sal", [(11, 5), (21, 5), (19, 12), (13, 12)], textura=0.1)
    f.linea("paja", [(11.5, 11.5), (20.5, 11.5)], 1.0)
    f.linea("lana_gris", [(12, 18), (20, 18)], 0.4)
    f.linea("lana_gris", [(11, 21), (21, 21)], 0.4)
    return f.imagen()


def item_brea():
    f = _item()
    f.elipse("barro", 16, 20, 10, 9, textura=0.075)
    f.elipse("barro", 16, 11, 7, 2.5, tono=-1)
    f.elipse("brea", 16, 11, 6, 1.8, plano=True)
    f.poligono("brea", [(11, 11), (13, 11), (13, 17), (12, 19), (11, 16)], plano=True)
    f.punto(14, 10, "brea", 3)
    f.linea("barro", [(8, 18), (24, 18)], 0.5, tono=-2)
    return f.imagen()


def item_tablas():
    f = _item()
    for i, (y, dx) in enumerate([(22, 0), (16, 2), (10, -1)]):
        f.poligono("madera", [(4 + dx, y), (24 + dx, y - 6), (28 + dx, y - 3), (8 + dx, y + 3)], textura=0.1)
        f.poligono("madera", [(4 + dx, y), (8 + dx, y + 3), (8 + dx, y + 6), (4 + dx, y + 3)], tono=-1)
        f.poligono("madera", [(8 + dx, y + 3), (28 + dx, y - 3), (28 + dx, y), (8 + dx, y + 6)], tono=-1)
    return f.imagen()


def item_cuerpo():
    f = _item()
    f.elipse("blanco", 16, 17, 7, 13, textura=0.05)
    f.elipse("blanco", 16, 7, 4.5, 4.5)
    for y in (12, 18, 24):
        f.linea("paja", [(9.5, y), (22.5, y + 1)], 0.7)
    return f.imagen()


def item_pesos():
    f = _item()
    for i, (x, y) in enumerate([(11, 22), (21, 23), (16, 15), (12, 9)]):
        f.elipse("oro", x, y, 7, 4, textura=0.05)
        f.elipse("oro", x, y - 1, 7, 3.5, tono=1 if i % 2 else 0)
        f.elipse("oro", x, y - 1, 3.5, 1.6, tono=-1)
    return f.imagen()


def item_trofeo():
    """Un colmillo de ente colgado de un cordel."""
    f = _item()
    f.linea("cuero", [(6, 5), (16, 11), (26, 5)], 0.8)
    f.poligono("blanco", [(12, 10), (20, 10), (18, 21), (15, 29), (13.5, 20)], textura=0.05)
    f.linea("blanco", [(15, 12), (15, 24)], 0.5, tono=-2)
    f.elipse("cuero", 16, 10.5, 4.5, 1.6)
    return f.imagen()


def item_chicha():
    f = _item()
    f.elipse("vidrio", 16, 21, 9, 9)
    f.poligono("vidrio", [(12.5, 6), (19.5, 6), (20, 13), (12, 13)])
    f.elipse("cuero", 16, 5, 3.6, 2.0)
    f.capsula("vidrio", 21, 9, 25, 16, 1.2, tono=-1)
    f.elipse("vidrio", 13, 18, 2.2, 3.6, tono=1, sombra=False)
    return f.imagen()


def item_revisorio():
    f = _item()
    f.poligono("cuero", [(4, 5), (25, 4), (28, 7), (28, 28), (7, 29), (4, 26)], textura=0.1)
    f.poligono("blanco", [(25, 5), (28, 7), (28, 27), (25, 25)], tono=-1)
    f.poligono("magia", [(10, 9), (21, 8.5), (21.5, 23), (10.5, 23.5)], tono=-2)
    f.linea("magia", [(15.5, 10.5), (15.8, 22)], 0.7, tono=1)
    f.linea("magia", [(12.5, 13), (15.5, 16), (18.8, 13)], 0.7, tono=1)
    f.linea("magia", [(12.5, 20), (15.5, 17), (18.8, 20)], 0.7, tono=1)
    f.linea("rojo", [(9, 28.5), (9, 31)], 1.2)
    f.brillo("magia", 1)
    return f.imagen()


def item_arpon():
    f = _item()
    _arpon(f, 5, 28, 24, 9)
    f.linea("lana_gris", [(5, 28), (3, 24), (7, 20)], 0.6, tono=1)
    return f.imagen()


def item_cochayuyo():
    f = _item()
    for i in range(6):
        x = 9 + i * 2.6
        f.linea("musgo", [(x, 4), (x + (i - 2.5) * 0.8, 16), (x + (i - 2.5) * 2.2, 29)], 1.6, tono=i % 2)
    f.linea("paja", [(8, 15), (25, 15)], 1.2)
    return f.imagen()


def item_papas():
    f = _item()
    for x, y in [(10, 15), (16, 13), (22, 15), (13, 18), (19, 18)]:
        f.elipse("papa", x, y, 3.8, 3.2, textura=0.1)
    f.poligono("paja", [(4, 18), (28, 18), (25, 29), (7, 29)], textura=0.175)
    for x in range(7, 27, 3):
        f.linea("paja", [(x, 19), (x + 0.5, 28.5)], 0.4, tono=-2)
    return f.imagen()


# --- Escenario ---

def bote():
    """El Santa Rosita, el bote de Abdón."""
    f = Figura(96, 48, 30)
    f.poligono("bote_rojo", [(4, 18), (92, 14), (84, 34), (64, 40), (22, 40), (10, 32)], textura=0.05)
    f.poligono("blanco", [(5, 18), (92, 14), (91, 17.5), (6, 21.5)], tono=-1)
    f.poligono("madera", [(12, 20), (86, 17), (84, 22), (14, 24)], tono=-1, textura=0.1)
    for x in (30, 52, 72):
        f.poligono("madera", [(x, 18.5), (x + 4, 18.3), (x + 4, 23), (x, 23.2)], tono=1)
    f.linea("bote_rojo", [(10, 30), (84, 26)], 0.5, tono=-2)
    f.linea("madera", [(48, 18), (48, 2)], 1.4)
    f.linea("lana_gris", [(48, 3), (88, 15)], 0.4, tono=1)
    f.linea("lana_gris", [(48, 3), (8, 17)], 0.4, tono=1)
    f.linea("blanco", [(36, 33), (40, 33)], 0.5, tono=1)
    for i, x in enumerate(range(42, 62, 3)):
        f.punto(x, 33 - (i % 2), "blanco", 3)
    return f.imagen()


def pilote():
    f = Figura(16, 48, 31)
    f.capsula("madera", 8, 5, 8, 44, 4.5, textura=0.125)
    f.elipse("madera", 8, 4, 4.5, 2.2, tono=1)
    f.elipse("madera", 8, 4, 2.2, 1.0, tono=-1)
    f.elipse("musgo", 8, 38, 4.6, 3.5, textura=0.2)
    f.linea("musgo", [(5, 36), (4.5, 42)], 1.0)
    for y in (14, 22, 29):
        f.linea("madera", [(5, y), (9, y + 1)], 0.4, tono=-2)
    return f.imagen()


def cuerpo():
    """Un ahogado varado en la playa, enredado en red."""
    f = Figura(48, 20, 32)
    f.capsula("lana_gris", 14, 11, 40, 12, 4.5, textura=0.075)
    f.capsula("lana_gris", 38, 10, 46, 9, 2.2, tono=-1)
    f.capsula("lana_gris", 38, 14, 46, 15, 2.2)
    f.elipse("ahogado", 8, 11, 5, 4.5)
    f.punto(6, 10, "ahogado", 0)
    f.punto(8, 10, "ahogado", 0)
    f.capsula("ahogado", 18, 15, 26, 17, 1.8)
    for x in range(14, 40, 4):
        f.linea("lana_gris", [(x, 6.5), (x + 3, 16.5)], 0.4, tono=2)
    f.linea("musgo", [(20, 7), (28, 8), (33, 6)], 0.9, tono=1)
    return f.imagen()


VISTAS = ("frente", "espalda", "lado")

PERSONAJES = {
    "abdon": ABDON,
    "finao_muralla": FINAO_CARPINTERO,
    "finao_arponero": FINAO_PESCADOR,
    "finao_contador": FINAO_FERMIN,
    "finao_rezador": FINAO_REZADORA,
    "finao_saqueador": FINAO_CONTRABANDISTA,
    "ahogado": AHOGADO,
}
ENTES = {"trauco": trauco, "fiura": fiura}
SUBJEFES = {"invunche": invunche, "chonchon": chonchon}
ITEMS = {
    "item_pescado": item_pescado, "item_pescado_ahumado": item_ahumado, "item_sal": item_sal,
    "item_brea": item_brea, "item_madera": item_tablas, "item_cuerpo": item_cuerpo,
    "item_pesos": item_pesos, "item_trofeo": item_trofeo, "item_chicha": item_chicha,
    "item_revisorio": item_revisorio, "item_arpon": item_arpon, "item_cochayuyo": item_cochayuyo,
    "item_papas": item_papas,
}
ESCENARIO = {"bote": bote, "pilote": pilote, "cuerpo": cuerpo}


def todo():
    """Todos los sprites de este módulo: nombre de archivo → imagen."""
    out = {}
    cuadros = {"": 0, "_paso": 1, "_ataque": 2}
    for nombre, receta in PERSONAJES.items():
        for vista in VISTAS:
            for sufijo, cuadro in cuadros.items():
                out[f"{nombre}_{vista}{sufijo}"] = humano(receta, vista, cuadro)
    for nombre, fn in ENTES.items():
        for vista in VISTAS:
            for sufijo, cuadro in cuadros.items():
                out[f"{nombre}_{vista}{sufijo}"] = fn(vista, cuadro)
    for nombre, fn in SUBJEFES.items():
        for sufijo, cuadro in cuadros.items():
            out[f"{nombre}_frente{sufijo}"] = fn("frente", cuadro)
    for nombre, fn in {**ITEMS, **ESCENARIO}.items():
        out[nombre] = fn()
    return out
