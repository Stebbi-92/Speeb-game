"""Synthesizes the unseen horrors' noises. Run: python3 tools/make_horror_audio.py assets/audio"""
import sys, numpy as np, wave
OUT = sys.argv[1]; SR = 44100
rng = np.random.default_rng(66)
def T(d): return np.arange(int(d * SR)) / SR
def lp(x, c):
    X = np.fft.rfft(x); f = np.fft.rfftfreq(len(x), 1 / SR); return np.fft.irfft(X / (1 + (f / c) ** 4), len(x))
def bp(x, lo, hi):
    X = np.fft.rfft(x); f = np.fft.rfftfreq(len(x), 1 / SR); X[(f < lo) | (f > hi)] = 0; return np.fft.irfft(X, len(x))
def norm(x, p=0.8): return x / (np.max(np.abs(x)) + 1e-9) * p
def verb(x, decay=2.5, n=24):
    # a cheap hall: many delayed, filtered, decaying copies
    out = np.copy(x); L = len(x)
    out = np.concatenate([out, np.zeros(int(decay * SR))])
    for i in range(n):
        d = int(rng.uniform(0.02, decay * 0.8) * SR); g = 0.55 * np.exp(-3.0 * d / (decay * SR)) * rng.uniform(0.5, 1)
        out[d:d + L] += lp(x, 3000 - i * 80) * g
    return out
def save(name, x):
    x = np.clip(x, -1, 1); st = np.stack([x, x], 1)
    with wave.open(f"{OUT}/{name}.wav", "wb") as w:
        w.setnchannels(2); w.setsampwidth(2); w.setframerate(SR); w.writeframes((st * 32767).astype(np.int16).tobytes())
def voice(x, f0, formants, breath=0.3):
    # a throat: a buzzing source shaped by formants, with breath
    ph = np.cumsum(f0 / SR) * 2 * np.pi
    src = np.sign(np.sin(ph)) * 0.5 + np.sin(ph * 2) * 0.3 + breath * rng.standard_normal(len(x))
    return sum(a * bp(src, f - w, f + w) for f, w, a in formants)
# A wail from far off: a voice sliding down, too long for any lungs
x = T(4.5)
f0 = 330 * np.exp(-x * 0.25) * (1 + 0.04 * np.sin(2 * np.pi * 5.5 * x)) + 30 * np.sin(2 * np.pi * 0.7 * x)
w = voice(x, f0, [(700, 120, 1.0), (1150, 150, 0.7), (2600, 300, 0.25)], 0.5) * np.sin(np.pi * x / 4.5) ** 0.7
save("unseen_call", norm(verb(lp(w, 2200), 3.5), 0.75))
# Breath beside the ear: slow, wet, wrong
x = T(3.2)
env = np.maximum(0, np.sin(2 * np.pi * x / 1.6)) ** 1.5
br = bp(rng.standard_normal(len(x)), 300, 2400) * env + 0.3 * bp(rng.standard_normal(len(x)), 80, 300) * env
br *= 1 + 0.6 * (rng.random(len(x)) > 0.995)
save("unseen_breath", norm(br, 0.6))
# Clicks: a throat working, bones settling
x = T(1.6); c = np.zeros(len(x))
t = 0.0
while t < 1.4:
    i = int(t * SR); n = int(0.012 * SR)
    c[i:i + n] += bp(rng.standard_normal(n), 900, 5000) * np.exp(-np.arange(n) / SR * 400)
    t += rng.uniform(0.03, 0.12)
save("unseen_click", norm(verb(c, 1.2), 0.6))
# The scream, close
x = T(1.4)
f0 = 520 + 260 * np.sin(2 * np.pi * 7 * x) * np.exp(-x * 1.5) + rng.standard_normal(len(x)).cumsum() * 0.02
sc = voice(x, f0, [(900, 200, 1.0), (1900, 300, 0.8), (3200, 500, 0.5)], 1.2) * np.minimum(1, x / 0.05) * np.exp(-x * 1.2)
save("unseen_scream", norm(verb(sc, 1.5), 0.95))
# Something enormous moving below the ground, heard far away at night
x = T(7.0)
g = lp(rng.standard_normal(len(x)), 70) * np.sin(np.pi * x / 7.0) ** 2 + 0.4 * np.sin(2 * np.pi * (28 + 3 * np.sin(2 * np.pi * 0.2 * x)) * x) * np.sin(np.pi * x / 7.0)
save("horror_deep", norm(verb(g, 3.0), 0.85))
print("ok")
