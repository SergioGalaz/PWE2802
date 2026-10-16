"""Casas, iglesia, estaciones y árboles con el mismo sombreado de los personajes.

Los edificios se ven en tres cuartos: la fachada de frente con luz y un costado en
sombra, como en la referencia. Todo se dibuja a 1,5 unidades del mundo por píxel,
igual que los personajes, para que los píxeles tengan el mismo tamaño en pantalla.
"""
import math

from figuras import Figura


def rect(f, rampa, x, y, w, h, **kw):
    f.poligono(rampa, [(x, y), (x + w, y), (x + w, y + h), (x, y + h)], **kw)


def tejuelas(f, rampa, x0, y0, x1, y1, tono=2, inclinacion=0.0, zona=None):
    """Hileras de tejuelas de alerce con la punta redonda, píxel a píxel.

    `inclinacion` sube las hileras hacia la derecha, para los costados en perspectiva.
    `zona` es un polígono opcional que limita dónde van.
    """
    for x in range(int(x0), int(x1)):
        dy = (x - x0) * inclinacion
        for y in range(int(y0 - dy), int(y1 - dy)):
            ly = int(y + dy - y0)
            hilera = ly // 4
            lx = (x - int(x0) + (2 if hilera % 2 else 0)) % 5
            fila = ly % 4
            if fila == 3:
                t = tono - 1 if lx in (1, 2, 3) else tono - 2
            elif lx == 0 and fila > 0:
                t = tono - 1
            elif fila == 0 and lx == 2:
                t = tono + 1
            else:
                continue
            if zona and not _dentro(x + 0.5, y + 0.5, zona):
                continue
            f.pix(x, y, rampa, max(0, min(3, t)), solo_encima=True)


def tablas_verticales(f, rampa, x0, y0, x1, y1, tono=2, ancho=4, inclinacion=0.0):
    for x in range(int(x0), int(x1)):
        dy = (x - x0) * inclinacion
        lx = (x - int(x0)) % ancho
        for y in range(int(y0 - dy), int(y1 - dy)):
            if lx == 0:
                f.pix(x, y, rampa, max(0, tono - 2), solo_encima=True)
            elif lx == 1 and (y * 7 + x * 3) % 13 == 0:
                f.pix(x, y, rampa, min(3, tono + 1), solo_encima=True)


def ventana(f, x, y, w=10, h=12, luz=True, costado=False):
    marco = "muro_blanco"
    rect(f, marco, x - 1.5, y - 1.5, w + 3, h + 3, plano=True, tono=1 if costado else 2)
    rect(f, "fuego" if luz else "cielo", x, y, w, h, plano=True, tono=1 if costado else 2)
    # Más luz abajo, como una lámpara adentro, y el reflejo arriba.
    if luz:
        rect(f, "fuego", x, y + h / 2, w, h / 2, plano=True, tono=2 if costado else 3)
    for i in range(int(w / 3)):
        f.pix(x + 1 + i, y + 1, "muro_blanco", 3)
    rect(f, marco, x + w / 2 - 0.6, y, 1.2, h, plano=True, tono=1 if costado else 2)
    rect(f, marco, x, y + h / 2 - 0.6, w, 1.2, plano=True, tono=1 if costado else 2)
    rect(f, "madera", x - 2.5, y + h + 1.5, w + 5, 1.8, tono=1)


def puerta(f, x, y, w=14, h=22):
    rect(f, "muro_blanco", x - 1.5, y - 1.5, w + 3, h + 1.5, plano=True, tono=2)
    rect(f, "madera", x, y, w, h, plano=True, tono=1)
    for i in range(1, 4):
        xx = x + w * i / 4
        rect(f, "madera", xx - 0.4, y, 0.8, h, plano=True, tono=0)
    rect(f, "madera", x, y, 2.2, h, plano=True, tono=2)
    f.pix(x + w - 3, y + h * 0.55, "oro", 3)
    rect(f, "madera", x - 3, y - 3.5, w + 6, 2.0, tono=1)


def techo(f, rampa, puntos, tono=2, filas=3):
    """Un plano de techo con hileras horizontales."""
    f.poligono(rampa, puntos, plano=True, tono=tono)
    ys = [p[1] for p in puntos]
    xs = [p[0] for p in puntos]
    for y in range(int(min(ys)) + 1, int(max(ys)), filas):
        for x in range(int(min(xs)), int(max(xs)) + 1):
            if _dentro(x + 0.5, y + 0.5, puntos):
                f.pix(x, y, rampa, max(0, tono - 1))


def _dentro(x, y, pts):
    dentro = False
    j = len(pts) - 1
    for i in range(len(pts)):
        xi, yi = pts[i]
        xj, yj = pts[j]
        if (yi > y) != (yj > y) and x < (xj - xi) * (y - yi) / (yj - yi + 1e-9) + xi:
            dentro = not dentro
        j = i
    return dentro


def casa(muro, techo_rampa="rojo", semilla=1, ventanas_luz=True):
    """Casa chilota de tejuelas, con la fachada en luz y el costado en sombra."""
    f = Figura(108, 104, semilla)
    base = 100
    fx0, fx1, top = 6, 74, 46
    lado = 26
    sube = 8
    # Costado en sombra y su tejado.
    f.poligono(muro, [(fx1, top), (fx1 + lado, top - sube), (fx1 + lado, base - sube), (fx1, base)], plano=True, tono=1)
    tejuelas(f, muro, fx1, top, fx1 + lado, base, tono=1, inclinacion=sube / lado)
    ventana(f, fx1 + 8, top + 14 - 3, w=9, h=12, luz=ventanas_luz, costado=True)
    cx = (fx0 + fx1) / 2
    cumbre = 12
    techo(f, techo_rampa, [(cx, cumbre), (fx1 + 2, top + 1), (fx1 + lado + 2, top - sube + 1), (cx + lado, cumbre - sube)],
          tono=1)
    # Fachada con su frontón.
    fachada = [(fx0, top), (cx, cumbre + 2), (fx1, top), (fx1, base), (fx0, base)]
    f.poligono(muro, fachada, plano=True, tono=2)
    tejuelas(f, muro, fx0, cumbre + 2, fx1, base, tono=2, zona=fachada)
    f.linea("alerce", [(fx0 - 3, top + 2), (cx, cumbre - 1), (fx1 + 3, top + 2)], 3.2, tono=1)
    f.linea("alerce", [(fx0 - 3, top + 3.5), (cx, cumbre + 0.5), (fx1 + 3, top + 3.5)], 0.8, tono=0)
    rect(f, muro, fx0, top + 4, fx1 - fx0, 2.0, plano=True, tono=0)  # sombra del alero
    ventana(f, cx - 4, cumbre + 16, w=8, h=9, luz=ventanas_luz)
    ventana(f, fx0 + 8, top + 14, luz=ventanas_luz)
    ventana(f, fx1 - 18, top + 14, luz=ventanas_luz)
    puerta(f, cx - 7, base - 23, w=14, h=23)
    # Basa de piedra y chimenea.
    rect(f, "piedra", fx0 - 1, base - 3, fx1 - fx0 + 2, 4, textura=0.3)
    f.poligono("piedra", [(fx1, base - 3), (fx1 + lado, base - sube - 3), (fx1 + lado, base - sube + 1), (fx1, base + 1)],
               tono=-1, textura=0.3)
    rect(f, "piedra", cx + lado * 0.6, cumbre - 9, 6, 13, textura=0.35)
    rect(f, "piedra", cx + lado * 0.6 - 1, cumbre - 10, 8, 2, tono=1)
    for i, (dx, dy, r) in enumerate([(3, -14, 2.4), (6, -19, 3.0), (4, -25, 2.4)]):
        f.elipse("humo", cx + lado * 0.6 + dx, cumbre + dy, r, r * 0.8, sombra=False, tono=1 - i % 2)
    return f.imagen()


def almacen():
    f = Figura(108, 104, 9)
    img = casa("muro_rojo", "zinc", semilla=9)
    # Letrero de madera sobre la puerta, con letras claras.
    f2 = Figura(108, 104, 10)
    rect(f2, "alerce", 16, 52, 50, 10, tono=1)
    rect(f2, "muro_blanco", 18, 54, 46, 7, plano=True, tono=3)
    # ALMACÉN en letras de 3x5.
    letras = ["010.100.10001.010.011.111.1001", "101.100.11011.101.100.100.1101", "111.100.10101.111.100.110.1011",
              "101.100.10001.101.100.100.1001", "101.111.10001.101.011.111.1001"]
    ancho = len(letras[0])
    for fila, patron in enumerate(letras):
        for i, ch in enumerate(patron):
            if ch == "1":
                f2.pix(41 - ancho // 2 + i, 55 + fila, "traje", 0)
    # Un barril y un saco al lado de la puerta.
    f2.elipse("madera", 88, 90, 6, 8, textura=0.15)
    rect(f2, "metal", 82, 85, 12, 1.2, plano=True, tono=1)
    rect(f2, "metal", 82, 94, 12, 1.2, plano=True, tono=1)
    f2.elipse("sal", 99, 94, 5, 6, textura=0.1)
    encima = f2.imagen()
    img.alpha_composite(encima)
    return img


def iglesia():
    f = Figura(132, 184, 20)
    o = 20  # todo baja para dejar espacio a la torre y la cruz
    base = 182
    fx0, fx1, top = 10, 100, 82 + o
    lado, sube = 26, 8
    cx = (fx0 + fx1) / 2
    cumbre = 60 + o
    # Costado y techo de la nave.
    f.poligono("muro_ocre", [(fx1, top), (fx1 + lado, top - sube), (fx1 + lado, base - sube), (fx1, base)], plano=True, tono=1)
    tejuelas(f, "muro_ocre", fx1, top, fx1 + lado, base, tono=1, inclinacion=sube / lado)
    for i in range(2):
        x = fx1 + 6 + i * 11
        rect(f, "cielo", x, top + 18 - (x - fx1) * sube / lado, 5, 14, plano=True, tono=1)
    techo(f, "zinc", [(cx, cumbre), (fx1 + 2, top + 1), (fx1 + lado + 2, top - sube + 1), (cx + lado, cumbre - sube)], tono=1)
    # Torre: base cuadrada, segundo cuerpo y aguja.
    tx0, tx1 = cx - 15, cx + 15
    f.poligono("muro_ocre", [(tx1, 26 + o), (tx1 + 9, 22 + o), (tx1 + 9, cumbre - 4), (tx1, cumbre)], plano=True, tono=1)
    tejuelas(f, "muro_ocre", tx1, 26 + o, tx1 + 9, cumbre, tono=1, inclinacion=4 / 9)
    rect(f, "muro_ocre", tx0, 26 + o, 30, cumbre - 26 - o + 4, plano=True, tono=2)
    tejuelas(f, "muro_ocre", tx0, 26 + o, tx1, cumbre + 4, tono=2)
    rect(f, "traje", cx - 10, 32 + o, 8, 12, plano=True, tono=1)
    rect(f, "traje", cx + 2, 32 + o, 8, 12, plano=True, tono=1)
    for y in range(34 + o, 44 + o, 3):
        rect(f, "alerce", cx - 10, y, 8, 1, plano=True, tono=2)
        rect(f, "alerce", cx + 2, y, 8, 1, plano=True, tono=2)
    f.elipse("muro_blanco", cx, 51 + o, 4.5, 4.5)
    f.elipse("traje", cx, 51 + o, 3.2, 3.2, plano=True, tono=2)
    f.linea("muro_blanco", [(cx, 49 + o), (cx, 51 + o), (cx + 1.6, 52 + o)], 0.5)
    f.linea("alerce", [(tx0 - 2, 26 + o), (tx1 + 2, 26 + o), (tx1 + 11, 22 + o)], 2.0, tono=1)
    # Aguja de zinc con la cruz.
    f.poligono("zinc", [(tx1, 25 + o), (tx1 + 9, 21 + o), (cx + 2, 0 + o)], plano=True, tono=1)
    f.poligono("zinc", [(tx0, 25 + o), (tx1, 25 + o), (cx, 0 + o)], plano=True, tono=2)
    for y in range(4 + o, 25 + o, 3):
        w = (y - o) * 15 / 25
        rect(f, "zinc", cx - w, y, w * 2, 0.8, plano=True, tono=1)
    f.linea("traje", [(cx, o - 16), (cx, o + 1)], 1.2, tono=2)
    f.linea("traje", [(cx - 4, o - 11), (cx + 4, o - 11)], 1.2, tono=2)
    # Fachada con frontón, ventanas en arco y el pórtico de tres arcos.
    fachada = [(fx0, top), (cx, cumbre + 2), (fx1, top), (fx1, base), (fx0, base)]
    f.poligono("muro_ocre", fachada, plano=True, tono=2)
    tejuelas(f, "muro_ocre", fx0, cumbre + 2, fx1, base, tono=2, zona=fachada)
    f.linea("alerce", [(fx0 - 3, top + 2), (cx, cumbre - 1), (fx1 + 3, top + 2)], 3.0, tono=1)
    rect(f, "muro_ocre", fx0, top + 4, fx1 - fx0, 2.0, plano=True, tono=0)
    for x in (fx0 + 12, fx1 - 24):
        rect(f, "muro_blanco", x - 1.5, top + 12, 15, 20, plano=True, tono=2)
        f.elipse("muro_blanco", x + 6, top + 12, 7.5, 6, plano=True, tono=2)
        rect(f, "cielo", x, top + 13, 12, 18, plano=True, tono=2)
        f.elipse("cielo", x + 6, top + 13, 6, 4.5, plano=True, tono=2)
        rect(f, "cielo", x, top + 13, 5, 7, plano=True, tono=3)
        rect(f, "muro_blanco", x + 5.4, top + 9, 1.2, 22, plano=True, tono=2)
    rect(f, "muro_blanco", fx0, base - 50, fx1 - fx0, 3, tono=1)
    rect(f, "alerce", fx0, base - 47, fx1 - fx0, 2, plano=True, tono=1)
    ancho = (fx1 - fx0 - 8) / 3
    for i in range(3):
        x0 = fx0 + 4 + i * (ancho + 0)
        ax = x0 + 3
        aw = ancho - 6
        rect(f, "traje", ax, base - 36, aw, 36, plano=True, tono=1)
        f.elipse("traje", ax + aw / 2, base - 36, aw / 2, 6, plano=True, tono=1)
        rect(f, "traje", ax, base - 36, aw, 6, plano=True, tono=0)
        if i == 1:
            puerta(f, ax + aw / 2 - 8, base - 26, w=16, h=26)
    for i in range(4):
        x = fx0 + 3 + i * ancho
        rect(f, "muro_blanco", x, base - 45, 4, 45, textura=0.05)
    rect(f, "piedra", fx0 - 2, base - 3, fx1 - fx0 + 4, 4, textura=0.3)
    return f.imagen()


def ahumadero():
    f = Figura(76, 76, 30)
    base = 74
    fx0, fx1, top = 6, 52, 34
    lado, sube = 18, 6
    # Chimenea de piedra con humo.
    rect(f, "piedra", 56, 8, 10, 30, textura=0.35)
    rect(f, "piedra", 55, 6, 12, 3, tono=1)
    for i, (dx, dy, r) in enumerate([(2, -2, 3), (6, -7, 3.8), (3, -12, 3)]):
        f.elipse("humo", 61 + dx, 6 + dy, r, r * 0.8, sombra=False, tono=1 - i % 2)
    f.poligono("madera", [(fx1, top), (fx1 + lado, top - sube), (fx1 + lado, base - sube), (fx1, base)], plano=True, tono=1)
    tablas_verticales(f, "madera", fx1, top, fx1 + lado, base, tono=1, inclinacion=sube / lado)
    techo(f, "zinc", [(fx0 - 4, top + 1), (fx0 + 6, 18), (fx1 + lado + 2, 18 - sube), (fx1 + lado + 3, top - sube + 1),
                      (fx1 + 3, top + 1)], tono=2)
    rect(f, "madera", fx0, top, fx1 - fx0, base - top, plano=True, tono=2)
    tablas_verticales(f, "madera", fx0, top, fx1, base, tono=2)
    rect(f, "madera", fx0, top, fx1 - fx0, 2, plano=True, tono=0)
    # Boca del fogón, con brasas y pescados colgando.
    rect(f, "traje", fx0 + 10, top + 8, 26, base - top - 8, plano=True, tono=0)
    for x in (fx0 + 15, fx0 + 22, fx0 + 29):
        f.linea("paja", [(x, top + 8), (x, top + 11)], 0.5)
        f.poligono("oro", [(x - 1.6, top + 11), (x + 1.6, top + 11), (x + 1.0, top + 19), (x, top + 21), (x - 1.0, top + 19)],
                   tono=-1)
    for y in range(base - 9, base):
        for x in range(fx0 + 11, fx0 + 35):
            v = (x * 5 + y * 3) % 7
            f.pix(x, y, "fuego", 3 if v == 0 else (2 if v < 3 else 1))
    f.linea("madera", [(fx0 + 9, top + 8), (fx0 + 37, top + 8)], 1.4, tono=1)
    return f.imagen()


def mesa_brujeria():
    f = Figura(76, 54, 31)
    # Tablero en tres cuartos con mantel morado y flecos.
    f.poligono("magia", [(4, 22), (60, 22), (72, 14), (16, 14)], plano=True, tono=0)
    for x0 in (8, 56):
        rect(f, "madera", x0, 30, 4, 22, tono=1)
    rect(f, "madera", 66, 22, 3, 22, tono=-1)
    f.poligono("morado", [(4, 22), (60, 22), (60, 36), (4, 36)], plano=True, tono=1)
    f.poligono("morado", [(60, 22), (72, 14), (72, 28), (60, 36)], plano=True, tono=0)
    for x in range(4, 60, 3):
        f.poligono("morado", [(x, 36), (x + 2, 36), (x + 1, 39)], plano=True, tono=0)
    f.poligono("morado", [(4, 22), (60, 22), (72, 14), (16, 14)], plano=True, tono=2)
    for x in range(10, 60, 9):
        f.linea("oro", [(x, 24), (x + 4, 30), (x + 8, 24)], 0.5, tono=-1)
    # El Revisorio abierto con su brillo, un cráneo y dos velas.
    f.poligono("cuero", [(22, 20), (44, 20), (48, 15), (26, 15)], tono=0)
    f.poligono("blanco", [(23, 19), (33, 19), (36, 15.5), (27, 15.5)], plano=True, tono=3)
    f.poligono("blanco", [(34, 19), (43, 19), (46.5, 15.5), (37, 15.5)], plano=True, tono=2)
    for i in range(3):
        f.pix(28 + i * 2, 17, "magia", 2)
        f.pix(39 + i * 2, 17, "magia", 2)
    f.elipse("blanco", 54, 13, 4.5, 4.2)
    f.pix(52, 13, "traje", 0)
    f.pix(55, 13, "traje", 0)
    f.pix(53, 16, "traje", 0)
    for cx, alto in ((12, 12), (66, 9)):
        rect(f, "blanco", cx - 1.5, 18 - alto, 3, alto, tono=1)
        f.elipse("fuego", cx, 16 - alto, 1.4, 2.4, plano=True, tono=3)
        f.pix(cx, 15 - alto, "fuego", 3)
    return f.imagen()


def cama():
    f = Figura(76, 50, 32)
    rect(f, "madera", 2, 2, 8, 44, tono=1)
    rect(f, "madera", 66, 10, 6, 36, tono=0)
    f.poligono("madera", [(8, 38), (68, 38), (68, 44), (8, 44)], tono=1)
    f.poligono("blanco", [(8, 8), (66, 8), (66, 38), (8, 38)], plano=True, tono=2)
    f.elipse("blanco", 18, 14, 8, 5)
    colores = ["rojo", "muro_ocre", "muro_azul", "musgo", "muro_rojo", "paja"]
    for j, y in enumerate(range(18, 38, 6)):
        for i, x in enumerate(range(10, 66, 7)):
            rampa = colores[(i + j * 2) % len(colores)]
            rect(f, rampa, x, y, 7, 6, plano=True, tono=2 if (i + j) % 2 else 1)
            for k in range(0, 7, 2):
                f.pix(x + k, y, "blanco", 3)
    f.poligono("blanco", [(8, 37), (66, 37), (66, 40), (8, 40)], plano=True, tono=1)
    return f.imagen()


def lena():
    f = Figura(76, 38, 33)
    for y0, n, off in [(22, 5, 2), (11, 4, 9), (0, 3, 16)]:
        for i in range(n):
            cx = off + i * 14.5 + 7
            cy = y0 + 7.5
            f.elipse("madera", cx + 2, cy, 7, 7, tono=-1)
            f.elipse("paja", cx, cy, 6.6, 6.6)
            for r in (4.6, 2.6):
                for a in range(0, 360, 20):
                    f.pix(cx + math.cos(math.radians(a)) * r, cy + math.sin(math.radians(a)) * r, "paja", 1)
            f.pix(cx, cy, "madera", 1)
    return f.imagen()


def barricada():
    f = Figura(124, 34, 34)
    for y0 in (12, 21):
        rect(f, "madera", 0, y0, 124, 6, textura=0.15)
    for sx in range(4, 124, 15):
        f.poligono("madera", [(sx - 3.2, 34), (sx - 3.2, 6), (sx, 0), (sx + 3.2, 6), (sx + 3.2, 34)], textura=0.15)
        f.linea("paja", [(sx - 3.5, 14), (sx + 3.5, 16)], 0.9)
        f.linea("paja", [(sx - 3.5, 23), (sx + 3.5, 25)], 0.9)
    return f.imagen()


def arbol(semilla):
    """Un canelo frondoso o un ciprés de las Guaitecas, con luz arriba a la izquierda."""
    f = Figura(86, 96, semilla)
    f.capsula("madera", 43, 62, 43, 92, 4.5, textura=0.2)
    f.capsula("madera", 43, 80, 36, 70, 2.2, textura=0.2)
    f.elipse("madera", 43, 93, 7, 2.2, tono=-1)
    if semilla % 2:
        manchas = [(43, 44, 26, 22), (24, 54, 15, 13), (62, 54, 15, 13), (43, 22, 17, 15), (30, 34, 12, 11), (57, 33, 12, 11)]
    else:
        manchas = [(43, 66 - i * 11, 20 - i * 2.8, 9) for i in range(6)] + [(43, 4, 4, 5)]
    for i, (cx, cy, rx, ry) in enumerate(manchas):
        f.elipse("hoja", cx, cy, rx, ry, textura=0.18)
        f.elipse("hoja", cx - rx * 0.3, cy - ry * 0.35, rx * 0.45, ry * 0.4, textura=0.25, tono=1, sombra=False)
    return f.imagen()


def todo():
    return {
        "casa_0": casa("muro_blanco", "rojo", semilla=1),
        "casa_1": casa("muro_azul", "zinc", semilla=2),
        "casa_2": casa("muro_ocre", "rojo", semilla=3),
        "almacen": almacen(),
        "iglesia": iglesia(),
        "ahumadero": ahumadero(),
        "mesa_brujeria": mesa_brujeria(),
        "cama": cama(),
        "lena": lena(),
        "barricada": barricada(),
        "arbol_0": arbol(1),
        "arbol_1": arbol(2),
    }
