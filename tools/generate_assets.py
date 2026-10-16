#!/usr/bin/env python3
"""Genera el arte pixel art y los sonidos provisorios de Marea Bruja.

Todo sale de este script, así se puede ajustar y volver a generar:

    python3 tools/generate_assets.py

Necesita Pillow y NumPy. Escribe en assets/sprites y assets/audio.
"""
import math
import random
import wave
from pathlib import Path

import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parent.parent
SPRITES = ROOT / "assets" / "sprites"
AUDIO = ROOT / "assets" / "audio"

PALETTE = {
    ".": None,
    "k": "#1b1a22",  # contorno
    "r": "#b8433a", "R": "#e04030",  # gorro chilote / ojos de ente
    "s": "#e0b48a", "e": "#1b1a22",  # piel y ojos de Abdón
    "w": "#7a5a3c", "W": "#5a3f29",  # chaleco de lana
    "b": "#34495e", "K": "#2b2522",  # pantalón y botas
    "g": "#8fa58a", "G": "#5f7560", "p": "#e8f0c8",  # piel de Finao
    "c": "#4b5d6b", "C": "#36454f", "a": "#3f6b3a",  # ropa mojada y algas
    "t": "#8a5a3a", "y": "#c9a54a", "Y": "#9a7a30",  # Trauco y su quilineja
    "x": "#7d7d86", "h": "#5a3f29",  # hacha de piedra
    "n": "#1e1e24", "f": "#a7b86a", "d": "#8c2f39", "D": "#5e1f27",  # Fiura
    "u": "#5f8fa0", "U": "#3e6676", "m": "#2c3e50", "M": "#1f2d3a",  # ahogado de Cai Cai
}


def hex_rgba(h):
    h = h.lstrip("#")
    return (int(h[0:2], 16), int(h[2:4], 16), int(h[4:6], 16), 255)


def from_ascii(rows, palette=PALETTE):
    w = max(len(r) for r in rows)
    img = Image.new("RGBA", (w, len(rows)), (0, 0, 0, 0))
    for y, row in enumerate(rows):
        for x, ch in enumerate(row):
            col = palette.get(ch)
            if col:
                img.putpixel((x, y), hex_rgba(col))
    return img


def recolor(rows, mapping):
    return ["".join(mapping.get(c, c) for c in r) for r in rows]


# --- Personajes (16x16) ---

ABDON = [
    "......kkkk......",
    ".....krrrrk.....",
    "....krrrrrrk....",
    "....kRRRRRRk....",
    "....kssssssk....",
    "....ksessesk....",
    "....kssssssk....",
    ".....kssssk.....",
    "...kwwwwwwwwk...",
    "..kwwWwwwwWwwk..",
    "..kswwwwwwwwsk..",
    "..kkwwWWWWwwkk..",
    "....kbbbbbbk....",
    "....kbbkkbbk....",
    "....kKKk.kKKk...",
    "....kkkk.kkkk...",
]
ABDON_WALK = ABDON[:14] + [
    "...kKKk..kKKk...",
    "...kkkk..kkkk...",
]

FINAO = [
    "................",
    ".....kkkkkk.....",
    "....kgggggak....",
    "....kaggggak....",
    "....kgpggpgk....",
    "....kggggggk....",
    "....kgGkkGgk....",
    ".....kggggk.....",
    "...kcccccccck...",
    "..kccCccccCcck..",
    "..kgccccccccgk..",
    "..kkccCaaCcckk..",
    "....kCCCCCCk....",
    "....kCCkkCCk....",
    "....kGGk.kGGk...",
    "....kkkk.kkkk...",
]
FINAO_WALK = FINAO[:14] + [
    "...kGGk..kGGk...",
    "...kkkk..kkkk...",
]

TRAUCO = [
    "................",
    "......kkkk......",
    "....kkyyyykk....",
    "...kyyYyyYyyk...",
    "..kkkkkkkkkkkk..",
    "....kttttttk....",
    "....ktRttRtk....",
    "....kttkkttk....",
    "...kkyyyyyykk...",
    "..xxkyYyyYyk....",
    "..xxkyyyyyyk....",
    "...hkyYyyYyk....",
    "...hkyyyyyyk....",
    "...h.kttkttk....",
    ".....kkk.kkk....",
    "................",
]
TRAUCO_WALK = TRAUCO[:13] + [
    "...hkttk.kttk...",
    "....kkk...kkk...",
    "................",
]

FIURA = [
    "................",
    ".....nnnnnn.....",
    "....nnnnnnnn....",
    "...nnffffffnn...",
    "...nnfRffRfnn...",
    "...nnffkkffnn...",
    "...nn.ffff.nn...",
    "...nkddddddkn...",
    "..nkddDddDddkn..",
    "..nfkddddddkfn..",
    "...kkdDDDDdkk...",
    "....kddddddk....",
    "...kddddddddk...",
    "...kkkkkkkkkk...",
    ".....kf..fk.....",
    "................",
]
FIURA_WALK = FIURA[:14] + [
    "....kf....fk....",
    "................",
]

DROWNED_MAP = {"g": "u", "G": "U", "p": "R", "c": "m", "C": "M"}
AHOGADO = recolor(FINAO, DROWNED_MAP)
AHOGADO_WALK = recolor(FINAO_WALK, DROWNED_MAP)

BODY = [
    "..kkkk..........",
    ".kuuuukkkkkkkk..",
    ".kuUuukmmmmmmmk.",
    ".kuuuukmmMmmmmkk",
    "..kkkkkkkkkkkkk.",
]


# --- Texturas del mapa (16x16, procedurales con semilla fija) ---

def noise_tile(base, accents, seed, density=0.18, size=16):
    rng = random.Random(seed)
    img = Image.new("RGBA", (size, size), hex_rgba(base))
    for y in range(size):
        for x in range(size):
            if rng.random() < density:
                img.putpixel((x, y), hex_rgba(rng.choice(accents)))
    return img


def grass_tile():
    img = noise_tile("#55743f", ["#4a6837", "#62824a", "#6b8c4f"], 11)
    rng = random.Random(12)
    for _ in range(4):
        x, y = rng.randrange(1, 15), rng.randrange(2, 15)
        img.putpixel((x, y), hex_rgba("#7da35a"))
        img.putpixel((x, y - 1), hex_rgba("#7da35a"))
    return img


def forest_tile():
    img = noise_tile("#203d26", ["#1a3320", "#28492e", "#2f5535"], 21, 0.25)
    rng = random.Random(22)
    for _ in range(3):
        img.putpixel((rng.randrange(16), rng.randrange(16)), hex_rgba("#5c7d3a"))
    return img


def sand_tile():
    return noise_tile("#c2b083", ["#b3a173", "#cfbf93", "#a8956a"], 31, 0.2)


def path_tile():
    return noise_tile("#8c7653", ["#7d6847", "#9a8460", "#6f5c3e"], 41, 0.25)


def water_tile(frame):
    img = Image.new("RGBA", (16, 16), hex_rgba("#1f4766"))
    for y in range(16):
        for x in range(16):
            v = math.sin((x + frame * 4) * 0.8 + y * 1.7) + math.sin(y * 0.9 - frame * 2.0)
            if v > 1.3:
                img.putpixel((x, y), hex_rgba("#3d6f93"))
            elif v < -1.4:
                img.putpixel((x, y), hex_rgba("#173a55"))
    return img


def planks_tile(vertical=False):
    img = Image.new("RGBA", (16, 16), hex_rgba("#7a5a3c"))
    for i in range(16):
        for j in range(16):
            a, b = (i, j) if not vertical else (j, i)
            if b % 4 == 3:
                img.putpixel((a, b), hex_rgba("#4e3826"))
            elif (a * 7 + b * 3) % 11 == 0:
                img.putpixel((a, b), hex_rgba("#8d6b49"))
        # Uniones de las tablas, desfasadas por fila.
    for row in range(4):
        x = (row * 5 + 3) % 16
        for k in range(3):
            p = (x, row * 4 + k) if not vertical else (row * 4 + k, x)
            img.putpixel(p, hex_rgba("#4e3826"))
    return img


def tree_sprite(seed):
    rng = random.Random(seed)
    img = Image.new("RGBA", (32, 32), (0, 0, 0, 0))
    dark, mid, light = hex_rgba("#12301a"), hex_rgba("#1f4a28"), hex_rgba("#2f6a37")
    for y in range(26, 32):
        for x in range(14, 18):
            img.putpixel((x, y), hex_rgba("#4a3423"))
    blobs = [(16, 13, 11), (10, 17, 7), (22, 17, 7), (16, 7, 7)]
    for cx, cy, r in blobs:
        for y in range(32):
            for x in range(32):
                d = math.hypot(x - cx, y - cy)
                if d <= r:
                    img.putpixel((x, y), mid)
    for y in range(32):
        for x in range(32):
            if img.getpixel((x, y)) == mid:
                if rng.random() < 0.12 or (x + y) % 9 == 0 and y < 14:
                    img.putpixel((x, y), light)
                elif y > 18 and rng.random() < 0.35:
                    img.putpixel((x, y), dark)
    return outline(img)


def outline(img, color="#0e0d12"):
    w, h = img.size
    out = img.copy()
    for y in range(h):
        for x in range(w):
            if img.getpixel((x, y))[3] == 0:
                for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                    nx, ny = x + dx, y + dy
                    if 0 <= nx < w and 0 <= ny < h and img.getpixel((nx, ny))[3] > 0:
                        out.putpixel((x, y), hex_rgba(color))
                        break
    return out


def shingles(img, x0, y0, w, h, base, accent):
    """Tejuelas de alerce, la piel de las casas chilotas."""
    for y in range(y0, y0 + h):
        for x in range(x0, x0 + w):
            row = (y - y0) // 3
            off = 2 if row % 2 else 0
            edge = (y - y0) % 3 == 2 or (x - x0 + off) % 4 == 0 and (y - y0) % 3 == 1
            img.putpixel((x, y), hex_rgba(accent if edge else base))


def house_sprite(wall, accent, roof="#5b3a33"):
    img = Image.new("RGBA", (32, 30), (0, 0, 0, 0))
    for y in range(0, 12):
        half = 4 + y * 12 // 11
        for x in range(16 - half, 16 + half):
            img.putpixel((x, y), hex_rgba(roof if (x + y) % 5 else "#4a2e28"))
    shingles(img, 3, 12, 26, 18, wall, accent)
    for y in range(20, 30):
        for x in range(13, 19):
            img.putpixel((x, y), hex_rgba("#3a2a20"))
    for wx in (6, 22):
        for y in range(16, 21):
            for x in range(wx, wx + 5):
                img.putpixel((x, y), hex_rgba("#e8c86a" if (x + y) % 3 else "#c8a050"))
    return outline(img)


def church_sprite():
    img = Image.new("RGBA", (48, 60), (0, 0, 0, 0))
    yellow, edge = "#d9b65a", "#a8873a"
    # Torre con su cruz.
    for y in range(0, 6):
        img.putpixel((24, y), hex_rgba("#2b2522"))
    for x in range(22, 27):
        img.putpixel((x, 2), hex_rgba("#2b2522"))
    for y in range(6, 14):
        half = 1 + (y - 6) * 4 // 8
        for x in range(24 - half, 25 + half):
            img.putpixel((x, y), hex_rgba("#6b3a30"))
    shingles(img, 18, 14, 13, 14, yellow, edge)
    for y in range(18, 23):
        for x in range(22, 27):
            img.putpixel((x, y), hex_rgba("#2b2522"))
    # Techo de la nave y la fachada.
    for y in range(28, 36):
        half = 12 + (y - 28) * 12 // 8
        for x in range(24 - half, 24 + half):
            img.putpixel((x, y), hex_rgba("#6b3a30" if (x + y) % 4 else "#5a2f27"))
    shingles(img, 1, 36, 46, 24, yellow, edge)
    for y in range(44, 60):
        for x in range(19, 29):
            img.putpixel((x, y), hex_rgba("#5a3f29"))
    for x in (6, 36):
        for y in range(42, 50):
            for xx in range(x, x + 6):
                img.putpixel((xx, y), hex_rgba("#8fb0c8"))
    return outline(img)


def smokehouse_sprite():
    img = Image.new("RGBA", (28, 28), (0, 0, 0, 0))
    for y in range(0, 8):
        for x in range(19, 23):
            img.putpixel((x, y), hex_rgba("#5c5c64" if y % 3 else "#46464d"))
    for y in range(6, 12):
        half = 5 + (y - 6) * 9 // 6
        for x in range(14 - half, 14 + half):
            img.putpixel((x, y), hex_rgba("#3d2c22"))
    for y in range(12, 28):
        for x in range(2, 26):
            dark = x % 5 == 0
            img.putpixel((x, y), hex_rgba("#4e3826" if dark else "#6a4c33"))
    for y in range(18, 28):
        for x in range(10, 18):
            img.putpixel((x, y), hex_rgba("#e07a2a" if y > 23 and (x + y) % 2 else "#2a1d16"))
    return outline(img)


def witch_table_sprite():
    img = Image.new("RGBA", (28, 20), (0, 0, 0, 0))
    for y in range(6, 12):
        for x in range(1, 27):
            img.putpixel((x, y), hex_rgba("#4a3550" if y > 7 else "#5d4466"))
    for x in (3, 24):
        for y in range(12, 20):
            img.putpixel((x, y), hex_rgba("#3a2a40"))
            img.putpixel((x + 1, y), hex_rgba("#3a2a40"))
    # El Revisorio abierto y dos velas.
    for y in range(3, 8):
        for x in range(10, 18):
            img.putpixel((x, y), hex_rgba("#e8dcc0" if x != 14 else "#8a7a60"))
    for cx in (4, 23):
        for y in range(1, 7):
            img.putpixel((cx, y), hex_rgba("#efe6d0"))
        img.putpixel((cx, 0), hex_rgba("#ffb040"))
    return outline(img)


def bed_sprite():
    img = Image.new("RGBA", (28, 18), (0, 0, 0, 0))
    for y in range(0, 18):
        for x in range(0, 28):
            if y < 3 or x < 2 or x > 25:
                img.putpixel((x, y), hex_rgba("#5a3f29"))
            elif x < 8:
                img.putpixel((x, y), hex_rgba("#e8e0d0"))
            else:
                stripe = ((x // 3) + (y // 3)) % 2
                img.putpixel((x, y), hex_rgba("#a83a32" if stripe else "#c9a54a"))
    return outline(img)


def shop_sprite():
    img = house_sprite("#a8443a", "#7d2f28", roof="#3d3a40")
    # Letrero sobre la puerta.
    for y in range(13, 16):
        for x in range(9, 23):
            img.putpixel((x, y), hex_rgba("#e8dcc0" if y == 14 and x % 2 else "#5a3f29"))
    return img


def woodpile_sprite():
    img = Image.new("RGBA", (28, 14), (0, 0, 0, 0))
    for row, (y0, n, off) in enumerate([(8, 4, 1), (4, 3, 4), (0, 2, 7)]):
        for i in range(n):
            cx = off + i * 7 + 3
            for y in range(y0, y0 + 6):
                for x in range(cx - 3, cx + 3):
                    d = math.hypot(x - cx + 0.5, y - y0 - 2.5)
                    if d <= 3:
                        img.putpixel((x, y), hex_rgba("#c9a46a" if d < 1.6 else "#6a4a30"))
    return outline(img)


def barricade_sprite():
    img = Image.new("RGBA", (46, 12), (0, 0, 0, 0))
    for y in range(3, 9):
        for x in range(0, 46):
            img.putpixel((x, y), hex_rgba("#6a4c33" if y % 3 else "#4e3826"))
    for sx in range(2, 46, 8):
        for y in range(0, 12):
            img.putpixel((sx, y), hex_rgba("#4a3423"))
            img.putpixel((sx + 1, y), hex_rgba("#5a3f29"))
    return outline(img)


def save(img, name, frames=None):
    SPRITES.mkdir(parents=True, exist_ok=True)
    img.save(SPRITES / f"{name}.png")


def make_sprites():
    for name, a, b in [
        ("abdon", ABDON, ABDON_WALK), ("finao", FINAO, FINAO_WALK),
        ("trauco", TRAUCO, TRAUCO_WALK), ("fiura", FIURA, FIURA_WALK),
        ("ahogado", AHOGADO, AHOGADO_WALK),
    ]:
        save(from_ascii(a), name)
        save(from_ascii(b), name + "_paso")
    save(from_ascii(BODY), "cuerpo")
    save(grass_tile(), "pasto")
    save(forest_tile(), "monte")
    save(sand_tile(), "arena")
    save(path_tile(), "camino")
    save(water_tile(0), "mar_0")
    save(water_tile(1), "mar_1")
    save(planks_tile(), "tablas")
    save(planks_tile(vertical=True), "tablas_v")
    save(tree_sprite(1), "arbol_0")
    save(tree_sprite(2), "arbol_1")
    save(house_sprite("#d8d0b8", "#a89c80"), "casa_0")
    save(house_sprite("#5f8fa0", "#3e6676"), "casa_1")
    save(house_sprite("#c9a54a", "#9a7a30"), "casa_2")
    save(church_sprite(), "iglesia")
    save(smokehouse_sprite(), "ahumadero")
    save(witch_table_sprite(), "mesa_brujeria")
    save(bed_sprite(), "cama")
    save(shop_sprite(), "almacen")
    save(woodpile_sprite(), "lena")
    save(barricade_sprite(), "barricada")


# --- Sonido ---

RATE = 22050


def write_wav(name, samples):
    AUDIO.mkdir(parents=True, exist_ok=True)
    s = np.clip(samples, -1.0, 1.0)
    data = (s * 32000).astype(np.int16)
    with wave.open(str(AUDIO / f"{name}.wav"), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(RATE)
        w.writeframes(data.tobytes())


def t_axis(seconds):
    return np.arange(int(RATE * seconds)) / RATE


def env(n, attack=0.01, release=0.2):
    e = np.ones(n)
    a = max(1, int(RATE * attack))
    r = max(1, int(RATE * release))
    e[:a] = np.linspace(0, 1, a)
    e[-r:] *= np.linspace(1, 0, r)
    return e


def lowpass(x, alpha):
    """Filtro pasa bajos de un polo. `alpha` puede ser un número o un arreglo."""
    alphas = np.broadcast_to(np.asarray(alpha, dtype=float), x.shape)
    y = np.zeros_like(x)
    acc = 0.0
    for i in range(x.size):
        acc += alphas[i] * (x[i] - acc)
        y[i] = acc
    return y


def saw(freq, t):
    return 2.0 * (t * freq - np.floor(0.5 + t * freq))


def square(freq, t, duty=0.5):
    return np.where((t * freq) % 1.0 < duty, 1.0, -1.0)


def tri(freq, t):
    return 2.0 * np.abs(saw(freq, t)) - 1.0


def note_hz(semitone_from_a4):
    return 440.0 * 2 ** (semitone_from_a4 / 12.0)


def make_sfx():
    rng = np.random.default_rng(7)
    t = t_axis(0.16)
    write_wav("arpon", lowpass(rng.uniform(-1, 1, t.size), 0.35) * np.exp(-t * 22) * 0.8)

    t = t_axis(0.14)
    f = 140 * np.exp(-t * 9)
    thump = np.sin(2 * np.pi * np.cumsum(f) / RATE)
    write_wav("golpe", (thump * 0.9 + rng.uniform(-1, 1, t.size) * 0.25) * np.exp(-t * 25))

    t = t_axis(0.45)
    out = np.zeros(t.size)
    for i, semi in enumerate([3, 7, 10, 15]):
        start = int(i * 0.08 * RATE)
        seg = t[: t.size - start]
        out[start:] += tri(note_hz(semi), seg) * np.exp(-seg * 9) * 0.45
    write_wav("pesca", out)

    t = t_axis(0.5)
    write_wav("chapuzon", lowpass(rng.uniform(-1, 1, t.size), 0.12) * np.exp(-t * 7) * 1.4)

    t = t_axis(1.3)
    sweep = 220 * np.exp(-t * 1.2)
    phase = np.cumsum(sweep) / RATE
    eerie = saw(1, phase) * 0.3 + saw(1.01, phase * 1.5) * 0.2 + np.sin(2 * np.pi * phase * 0.5) * 0.4
    write_wav("reanimar", lowpass(eerie, 0.2) * env(t.size, 0.05, 0.6) * (0.7 + 0.3 * np.sin(t * 30)))

    t = t_axis(0.45)
    f = 300 * np.exp(-t * 5)
    squelch = square(1, np.cumsum(f) / RATE, 0.3) * 0.35
    write_wav("muere_ente", lowpass(squelch + rng.uniform(-1, 1, t.size) * 0.2, 0.25) * np.exp(-t * 6))

    t = t_axis(2.2)
    vib = 98 * (1 + 0.01 * np.sin(2 * np.pi * 5 * t))
    horn = saw(1, np.cumsum(vib) / RATE) + 0.5 * saw(1, np.cumsum(vib * 1.5) / RATE)
    write_wav("cuerno", lowpass(horn, 0.08) * env(t.size, 0.25, 0.8) * 1.6)

    t = t_axis(0.8)
    whoosh = lowpass(rng.uniform(-1, 1, t.size), 0.05 + 0.2 * t / 0.8) * 1.2
    chord = sum(np.sin(2 * np.pi * note_hz(s) * t) for s in (-21, -14, -9)) * 0.15
    write_wav("revisorio", (whoosh + chord) * env(t.size, 0.05, 0.5))

    t = t_axis(0.05)
    write_wav("clic", square(880, t) * np.exp(-t * 80) * 0.3)


def render_notes(notes, beat, voice, total_beats):
    """notes: lista de (beat_inicio, duración_en_beats, semitono desde A4 o None)."""
    out = np.zeros(int(RATE * beat * total_beats))
    for start, dur, semi in notes:
        if semi is None:
            continue
        n = int(RATE * beat * dur)
        t = np.arange(n) / RATE
        s = voice(note_hz(semi), t) * env(n, 0.01, min(0.15, beat * dur * 0.5))
        i = int(RATE * beat * start)
        out[i:i + n] += s[: max(0, min(n, out.size - i))]
    return out


def accordion(freq, t):
    return (saw(freq, t) * 0.5 + saw(freq * 1.003, t) * 0.5) * (0.85 + 0.15 * np.sin(2 * np.pi * 5.5 * t))


def make_music():
    # Día: un vals chilote en Re mayor, como de acordeón de fiesta de pueblo.
    beat = 0.42
    D, E, Fs, G, A, B, Cs = -7, -5, -3, -2, 0, 2, 4  # D4..C#5 relativos a A4
    melody_bars = [
        [(A, 1), (Fs, 1), (A, 1)], [(B, 2), (A, 1)], [(G, 1), (E, 1), (G, 1)], [(A, 3)],
        [(Fs, 1), (D, 1), (Fs, 1)], [(G, 2), (E, 1)], [(E, 1), (Cs - 12, 1), (E, 1)], [(D, 3)],
        [(A, 1), (B, 1), (A + 2, 1)], [(D + 12, 2), (B, 1)], [(A, 1), (G, 1), (Fs, 1)], [(E, 3)],
        [(Fs, 1), (G, 1), (A, 1)], [(B, 1), (A, 1), (G, 1)], [(Fs, 1), (E, 1), (Cs - 12, 1)], [(D, 3)],
    ]
    chords = [D, D, G - 12, A - 12, D, G - 12, A - 12, D, D, G - 12, D, A - 12, D, G - 12, A - 12, D]
    notes, bass, comp = [], [], []
    for bar, (phrase, root) in enumerate(zip(melody_bars, chords)):
        pos = bar * 3
        for semi, dur in phrase:
            notes.append((pos, dur, semi))
            pos += dur
        bass.append((bar * 3, 1, root - 12))
        third = 4  # acordes mayores, como en la ranchera chilota
        comp.append((bar * 3 + 1, 0.8, root + third))
        comp.append((bar * 3 + 2, 0.8, root + 7))
    total = 16 * 3
    mel = render_notes(notes, beat, accordion, total) * 0.32
    low = render_notes(bass, beat, lambda f, t: tri(f, t), total) * 0.45
    oom = render_notes(comp, beat, lambda f, t: square(f, t, 0.25), total) * 0.12
    day = lowpass(mel + low + oom, 0.45)
    write_wav("musica_dia", day * 0.8)

    # Noche: un zumbido grave en Re menor, olas y una melodía que aparece y se va.
    seconds = 32.0
    t = t_axis(seconds)
    rng = np.random.default_rng(3)
    drone = (np.sin(2 * np.pi * note_hz(-31) * t) * 0.35
             + saw(note_hz(-24), t) * 0.08 + np.sin(2 * np.pi * note_hz(-19) * t) * 0.12)
    drone = lowpass(drone, 0.05) * (0.8 + 0.2 * np.sin(2 * np.pi * t / 8.0))
    waves = lowpass(rng.uniform(-1, 1, t.size), 0.02) * (0.6 + 0.4 * np.sin(2 * np.pi * t / 6.4)) * 1.6
    beat = 1.0
    eerie = [(2, 3, -7 + 5), (6, 2, -7 + 3), (9, 4, -7 + 1), (16, 3, -7 + 8), (20, 2, -7 + 7), (24, 5, -7 + 3)]
    mel = render_notes(eerie, beat, lambda f, t: np.sin(2 * np.pi * f * t) * 0.6 + tri(f * 2, t) * 0.1, 32)
    pulse = render_notes([(b, 0.5, -31) for b in range(0, 32, 4)], beat, lambda f, t: np.sin(2 * np.pi * f * t) * np.exp(-t * 6), 32)
    night = drone + waves + mel[: t.size] * 0.35 + pulse[: t.size] * 0.6
    fade = int(RATE * 0.05)
    night[:fade] *= np.linspace(0, 1, fade)
    night[-fade:] *= np.linspace(1, 0, fade)
    write_wav("musica_noche", night * 0.7)


if __name__ == "__main__":
    make_sprites()
    make_sfx()
    make_music()
    print("Listo:", len(list(SPRITES.glob("*.png"))), "sprites y", len(list(AUDIO.glob("*.wav"))), "sonidos.")
