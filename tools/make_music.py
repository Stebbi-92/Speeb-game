# Makes Brelm's small score in code: slow pads, plucked strings, bells and drums.
# These stand in until free recordings (CC0 or CC-BY) take their places; a file of the same name in
# assets/music replaces a piece. Usage: python3 tools/make_music.py [out_dir]
import os
import subprocess
import sys

import numpy as np

SR = 44100
OUT = sys.argv[1] if len(sys.argv) > 1 else os.path.join(os.path.dirname(__file__), "..", "assets", "music")
rng = np.random.default_rng(1771)


def hz(note):
    """A note name like 'D3' or 'F#4' to its frequency."""
    names = {"C": 0, "C#": 1, "Db": 1, "D": 2, "D#": 3, "Eb": 3, "E": 4, "F": 5, "F#": 6, "Gb": 6,
             "G": 7, "G#": 8, "Ab": 8, "A": 9, "A#": 10, "Bb": 10, "B": 11}
    n, o = note[:-1], int(note[-1])
    return 440.0 * 2 ** ((names[n] + 12 * (o + 1) - 69) / 12)


def env(n, a, r):
    e = np.ones(n)
    ai, ri = int(a * SR), int(r * SR)
    if ai:
        e[:ai] = np.linspace(0, 1, ai) ** 2
    if ri:
        e[-ri:] *= np.linspace(1, 0, ri) ** 2
    return e


def pad(notes, dur, a=2.5, r=3.0, bright=0.35):
    """A soft chord: each note a few detuned saw-like voices, rounded off."""
    n = int(dur * SR)
    t = np.arange(n) / SR
    out = np.zeros(n)
    for note in notes:
        f = hz(note)
        for d in (-0.12, 0.0, 0.11):
            ff = f * 2 ** (d / 12)
            ph = rng.uniform(0, 6.28)
            for k in range(1, 7):
                out += (bright ** (k - 1)) / k * np.sin(2 * np.pi * ff * k * t + ph * k)
    out *= env(n, a, r) * (1.0 + 0.08 * np.sin(2 * np.pi * 0.13 * t))
    return out / (len(notes) * 3)


def pluck(note, dur=2.5, damp=0.996):
    """A plucked string (Karplus-Strong)."""
    f = hz(note)
    n = int(dur * SR)
    p = max(2, int(SR / f))
    buf = rng.uniform(-1, 1, p)
    out = np.zeros(n)
    for i in range(n):
        out[i] = buf[i % p]
        buf[i % p] = damp * 0.5 * (buf[i % p] + buf[(i + 1) % p])
    return out * env(n, 0.002, 0.4) * 0.6


def bell(note, dur=4.0):
    f = hz(note)
    n = int(dur * SR)
    t = np.arange(n) / SR
    out = np.zeros(n)
    for ratio, amp, dec in ((1.0, 1.0, 1.2), (2.76, 0.5, 2.0), (5.4, 0.25, 3.5), (8.93, 0.12, 5.0)):
        out += amp * np.exp(-dec * t) * np.sin(2 * np.pi * f * ratio * t)
    return out * env(n, 0.003, 0.5) * 0.35


def drum(dur=1.2, f0=70.0):
    n = int(dur * SR)
    t = np.arange(n) / SR
    f = f0 * (1 + 1.5 * np.exp(-t * 30))
    body = np.sin(2 * np.pi * np.cumsum(f) / SR) * np.exp(-t * 5)
    hit = rng.uniform(-1, 1, n) * np.exp(-t * 60) * 0.3
    return (body + hit) * 0.9


def drone(note, dur, a=4.0):
    n = int(dur * SR)
    t = np.arange(n) / SR
    f = hz(note)
    out = np.sin(2 * np.pi * f * t) + 0.5 * np.sin(2 * np.pi * f * 2.003 * t) + 0.25 * np.sin(2 * np.pi * f * 3.01 * t)
    return out * env(n, a, a) * (0.8 + 0.2 * np.sin(2 * np.pi * 0.07 * t)) * 0.3


def place(track, sound, at):
    i = int(at * SR)
    j = min(len(track), i + len(sound))
    track[i:j] += sound[: j - i]


def reverb(x, wet=0.35):
    """A small hall: four combs and two all-passes (Schroeder)."""
    y = np.zeros(len(x) + SR * 3)
    xx = np.concatenate([x, np.zeros(SR * 3)])
    for d, g in ((1557, 0.84), (1617, 0.83), (1491, 0.85), (1422, 0.86)):
        c = np.zeros(len(xx))
        for i in range(0, len(xx), d):
            seg = xx[i:i + d]
            prev = c[i - d:i - d + len(seg)] if i >= d else np.zeros(len(seg))
            c[i:i + len(seg)] = seg + g * prev
        y += c / 4
    for d, g in ((225, 0.5), (556, 0.5)):
        z = np.zeros(len(y))
        for i in range(0, len(y), d):
            seg = y[i:i + d]
            prev_z = z[i - d:i - d + len(seg)] if i >= d else np.zeros(len(seg))
            prev_y = y[i - d:i - d + len(seg)] if i >= d else np.zeros(len(seg))
            z[i:i + len(seg)] = -g * seg + prev_y + g * prev_z
        y = z
    return np.concatenate([x, np.zeros(SR * 3)]) * (1 - wet) + y * wet


def write(name, x, loop=False):
    x = reverb(x)
    if loop:
        # The tail of the hall folds back onto the start, so the loop has no seam
        tail = x[-SR * 3:].copy()
        x = x[: -SR * 3]
        x[: len(tail)] += tail
    x = x / (np.max(np.abs(x)) + 1e-9) * 0.7
    st = np.stack([x, np.roll(x, 331)], axis=1)
    raw = (st * 32767).astype(np.int16).tobytes()
    os.makedirs(OUT, exist_ok=True)
    path = os.path.join(OUT, name + ".ogg")
    subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-f", "s16le", "-ar", str(SR), "-ac", "2", "-i", "-",
                    "-c:a", "libvorbis", "-q:a", "4", path], input=raw, check=True)
    print(name, round(len(x) / SR, 1), "s")


def dawn():
    chords = [["D3", "A3", "F#4"], ["A2", "E3", "C#4"], ["B2", "F#3", "D4"], ["G2", "D3", "B3"]] * 2
    x = np.zeros(SR * 66)
    for i, c in enumerate(chords):
        place(x, pad(c, 10.0, 3.0, 3.5), i * 8.0)
    tune = ["F#4", "A4", "B4", "A4", "E4", "F#4", "D4", "E4", "A4", "B4", "D5", "C#5", "B4", "A4"]
    for i, nt in enumerate(tune):
        place(x, bell(nt) * 0.8, 6.0 + i * 3.6 + (0.6 if i % 3 == 2 else 0.0))
    write("dawn", x)


def night():
    x = np.zeros(SR * 72)
    place(x, drone("D2", 72.0, 6.0), 0)
    for i, c in enumerate([["D3", "F3", "A3"], ["Bb2", "F3", "D4"], ["C3", "G3", "E4"], ["D3", "F3", "A3"], ["G2", "D3", "Bb3"], ["A2", "E3", "C#4"]]):
        place(x, pad(c, 15.0, 5.0, 5.0, 0.25) * 0.8, i * 11.0)
    for at, nt in ((8, "A4"), (19, "F4"), (27, "E4"), (38, "D5"), (46, "A4"), (57, "C#5"), (63, "D5")):
        place(x, bell(nt, 5.0) * 0.5, at)
    write("night", x)


def seventh():
    beat = 0.75
    x = np.zeros(int(SR * beat * 48))
    place(x, drone("D2", beat * 48, 1.0) * 1.2, 0)
    for i in range(48):
        if i % 4 in (0, 3) or i % 8 == 6:
            place(x, drum(1.0, 60 if i % 4 == 0 else 85) * (1.0 if i % 4 == 0 else 0.6), i * beat)
    for i, c in enumerate([["D3", "F3", "A3"], ["Eb3", "G3", "Bb3"], ["D3", "F3", "A3"], ["C3", "Eb3", "G3"]]):
        place(x, pad(c, beat * 13, 1.5, 2.0, 0.5) * 0.9, i * beat * 12)
    write("seventh", x, loop=True)


def swell():
    x = np.zeros(SR * 12)
    p = pad(["D3", "A3", "D4", "F#4", "A4"], 12.0, 5.0, 4.0, 0.45)
    place(x, p * 1.4, 0)
    for i, nt in enumerate(["D5", "A4", "F#5", "D6"]):
        place(x, bell(nt, 6.0), 4.5 + i * 0.35)
    write("swell", x)


def town():
    x = np.zeros(SR * 64)
    prog = [["G2", "D3", "B3"], ["E2", "B2", "G3"], ["C3", "G3", "E4"], ["D3", "A3", "F#4"]] * 2
    arps = [["G3", "B3", "D4", "B3"], ["E3", "G3", "B3", "G3"], ["C4", "E4", "G4", "E4"], ["D4", "F#4", "A4", "F#4"]] * 2
    for i, c in enumerate(prog):
        place(x, pad(c, 9.5, 1.5, 2.5, 0.3) * 0.6, i * 8.0)
        for j in range(16):
            place(x, pluck(arps[i][j % 4], 2.0), i * 8.0 + j * 0.5)
    write("town", x)


def sea():
    x = np.zeros(SR * 72)
    for i, c in enumerate([["A2", "E3", "C4"], ["F2", "C3", "A3"], ["G2", "D3", "B3"], ["E2", "B2", "G#3"], ["A2", "E3", "C4"], ["D2", "A2", "F3"]]):
        place(x, pad(c, 16.0, 6.0, 6.0, 0.3), i * 12.0)
    t = np.arange(len(x)) / SR
    surge = 0.75 + 0.25 * np.sin(2 * np.pi * t / 9.0)
    x *= surge
    for at, nt in ((10, "E5"), (22, "C5"), (35, "B4"), (47, "G#4"), (58, "A4")):
        place(x, bell(nt, 6.0) * 0.4, at)
    write("sea", x)


def great():
    beat = 0.5
    x = np.zeros(int(SR * beat * 64))
    place(x, drone("C2", beat * 64, 0.5) * 1.4, 0)
    for i in range(64):
        if i % 2 == 0 or i % 16 in (13, 15):
            place(x, drum(0.8, 55 if i % 4 == 0 else 80) * (1.0 if i % 4 == 0 else 0.55), i * beat)
    for i, c in enumerate([["C3", "Eb3", "G3"], ["Db3", "F3", "Ab3"], ["C3", "Eb3", "G3"], ["B2", "D3", "F#3"]]):
        place(x, pad(c, beat * 17, 0.8, 1.5, 0.6), i * beat * 16)
    write("great", x, loop=True)


if __name__ == "__main__":
    for f in (dawn, night, seventh, swell, town, sea, great):
        f()
