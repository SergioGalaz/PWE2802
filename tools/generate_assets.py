#!/usr/bin/env python3
"""Genera el pixel art y los sonidos de Marea Bruja.

Todo sale de este script, así se puede ajustar y volver a generar:

    python3 tools/generate_assets.py

Necesita Pillow y NumPy. Escribe en assets/sprites y assets/audio, y con tools/defold.py
hornea el mapa, la interfaz y los atlas. El dibujo de los sprites y la paleta están en
tools/arte.py.
"""
import wave

import numpy as np

import defold
from arte import ROOT, SPRITES, make_sprites

AUDIO = ROOT / "assets" / "audio"


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
    defold.preparar()
    make_sfx()
    make_music()
    print("Listo:", len(list(SPRITES.glob("*.png"))), "sprites y", len(list(AUDIO.glob("*.wav"))), "sonidos.")
