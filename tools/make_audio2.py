"""Synthesizes the hostile cries, the saucer, the Praying Hands' choir and the relics' sounds.
Run: python3 tools/make_audio2.py assets/audio"""
import sys, subprocess, numpy as np, wave, os
OUT = sys.argv[1]; SR = 44100
rng = np.random.default_rng(31)
t = lambda d: np.arange(int(d * SR)) / SR
def norm(x, peak=0.8): return x / (np.max(np.abs(x)) + 1e-9) * peak
def bp(x, lo, hi):
    X = np.fft.rfft(x); f = np.fft.rfftfreq(len(x), 1 / SR)
    X[(f < lo) | (f > hi)] = 0
    return np.fft.irfft(X, len(x))
def lp(x, cutoff):
    X = np.fft.rfft(x); f = np.fft.rfftfreq(len(x), 1 / SR)
    return np.fft.irfft(X / (1 + (f / cutoff) ** 4), len(x))
def formants(x, peaks):
    X = np.fft.rfft(x); f = np.fft.rfftfreq(len(x), 1 / SR)
    g = sum(a * np.exp(-((f - c) / w) ** 2) for c, w, a in peaks)
    return np.fft.irfft(X * g, len(x))
def reverb(x, secs=1.5, wet=0.35):
    n = int(secs * SR); ir = rng.standard_normal(n) * np.exp(-np.arange(n) / SR * 6.9 / secs)
    ir = lp(ir, 5000); L = len(x) + n
    y = np.fft.irfft(np.fft.rfft(x, L) * np.fft.rfft(ir, L), L)
    y = norm(y, np.max(np.abs(x)))
    out = np.zeros(L); out[:len(x)] += x * (1 - wet); out += y * wet
    return out
def saw(phase): return 2.0 * (phase % 1.0) - 1.0
def fade(x, a=0.005, r=0.05):
    n1, n2 = int(a * SR), int(r * SR); x = x.copy()
    x[:n1] *= np.linspace(0, 1, n1); x[-n2:] *= np.linspace(1, 0, n2); return x
def save(name, x, ogg=False):
    x = np.clip(x, -1, 1); st = np.stack([x, x], 1)
    wp = f"{OUT}/{name}.wav"
    with wave.open(wp, "wb") as w:
        w.setnchannels(2); w.setsampwidth(2); w.setframerate(SR); w.writeframes((st * 32767).astype(np.int16).tobytes())
    if ogg:
        subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", wp, "-c:a", "libvorbis", "-q:a", "4", f"{OUT}/{name}.ogg"], check=True); os.remove(wp)

# Shrieks: a sweeping, cracking cat-scream with a ring-modulated undertone
for k in range(4):
    d = rng.uniform(0.9, 1.4); x = t(d); u = x / d
    f0 = rng.uniform(700, 1000) * (1 + 0.9 * np.sin(np.pi * u ** 0.7)) * (1 + 0.03 * rng.standard_normal(len(x)).cumsum() / np.sqrt(len(x)) * 30)
    f0 *= 1 + 0.06 * np.sin(2 * np.pi * rng.uniform(9, 16) * x)
    ph = np.cumsum(f0) / SR
    v = saw(ph) + 0.6 * saw(ph * 0.5 + 0.13) + 0.4 * saw(ph * 1.51)
    v = formants(v, [(1200, 400, 1.0), (2800, 600, 0.8), (4200, 900, 0.4)])
    v *= 1 + 0.8 * np.sin(2 * np.pi * rng.uniform(55, 90) * x)
    v += 0.5 * bp(rng.standard_normal(len(x)), 2000, 8000)
    v = np.tanh(norm(v, 1) * 3.5)
    env = np.minimum(1, x / 0.04) * (1 - u) ** 1.4
    save(f"shriek_{k}", norm(reverb(fade(v * env), 0.9, 0.3), 0.85))

# Growls: a low rattling throat, unsteady
for k in range(3):
    d = rng.uniform(1.0, 1.5); x = t(d); u = x / d
    f0 = rng.uniform(55, 80) * (1 + 0.2 * np.sin(2 * np.pi * 3 * x)) * (1 + 0.15 * u)
    ph = np.cumsum(f0) / SR
    v = saw(ph) + 0.5 * np.sign(np.sin(2 * np.pi * ph * 2.01))
    v *= 0.6 + 0.4 * np.sin(2 * np.pi * rng.uniform(18, 28) * x)
    v += 0.7 * bp(rng.standard_normal(len(x)), 150, 1400) * (0.5 + 0.5 * np.sin(2 * np.pi * 23 * x))
    v = formants(v, [(300, 150, 1.0), (700, 250, 0.7), (1500, 400, 0.3)])
    v = np.tanh(norm(v, 1) * 4)
    env = np.minimum(1, x / 0.08) * np.sin(np.pi * np.minimum(u * 1.1, 1)) ** 0.5
    save(f"growl_{k}", norm(reverb(fade(v * env), 0.8, 0.25), 0.85))

# Screech: the spitter's cry before it casts
x = t(0.7); u = x / 0.7
f0 = 2400 + 1300 * u + 200 * np.sin(2 * np.pi * 21 * x)
v = np.sin(2 * np.pi * np.cumsum(f0) / SR) + 0.5 * saw(np.cumsum(f0 * 0.5) / SR)
v = np.tanh((v + 0.4 * bp(rng.standard_normal(len(x)), 3000, 9000)) * 2.5) * np.minimum(1, x / 0.02) * (1 - u) ** 1.2
save("screech", norm(reverb(fade(v), 0.7, 0.3), 0.75))

# Roar: the crowned form, deep and long
x = t(2.6); u = x / 2.6
f0 = 48 * (1 + 0.4 * np.sin(np.pi * u)); ph = np.cumsum(f0) / SR
v = saw(ph) + 0.7 * saw(ph * 1.007) + 0.5 * saw(ph * 3.02)
v *= 0.65 + 0.35 * np.sin(2 * np.pi * 31 * x)
v += 0.6 * bp(rng.standard_normal(len(x)), 100, 2500)
hi = np.cumsum(500 * (1 + 0.8 * np.sin(np.pi * u))) / SR
v += 0.5 * formants(saw(hi), [(1100, 400, 1), (2500, 600, 0.6)])
v = np.tanh(norm(formants(v, [(250, 200, 1), (800, 400, 0.8), (2000, 800, 0.4)]), 1) * 4) * np.minimum(1, x / 0.15) * (1 - u) ** 0.8
save("roar", norm(reverb(fade(v), 2.0, 0.4), 0.95))

# Chitter: the mites, many small clicking mouths
x = t(0.6); v = np.zeros(len(x))
for k in range(18):
    i = int(rng.uniform(0, 0.55) * SR); m = int(0.018 * SR); tt = np.arange(m) / SR
    v[i:i + m] += np.sin(2 * np.pi * rng.uniform(3000, 5500) * tt) * np.exp(-tt * 300)
v += 0.2 * bp(rng.standard_normal(len(x)), 4000, 9000) * np.sin(np.pi * x / 0.6)
save("chitter", norm(fade(v), 0.6))

# Saucer hum: a pulsing low engine and a wavering whine (loop)
x = t(6.0)
v = np.sin(2 * np.pi * 62 * x) + 0.6 * np.sin(2 * np.pi * 93.5 * x) + 0.3 * np.sign(np.sin(2 * np.pi * 31 * x)) * 0.4
v *= 0.7 + 0.3 * np.sin(2 * np.pi * 2.0 * x)
v += 0.25 * np.sin(2 * np.pi * np.cumsum(1300 + 260 * np.sin(2 * np.pi * 0.5 * x)) / SR)
v += 0.1 * bp(rng.standard_normal(len(x)), 200, 900)
save("saucer_hum", norm(lp(v, 3000), 0.6), ogg=True)

# Beam: the red light falls and lets down the mites
x = t(1.6); u = x / 1.6
f0 = 900 * (1 - 0.6 * u) * (1 + 0.1 * np.sin(2 * np.pi * 14 * x))
v = np.sin(2 * np.pi * np.cumsum(f0) / SR) + 0.4 * saw(np.cumsum(f0 * 0.25) / SR)
v = (v + 0.4 * bp(rng.standard_normal(len(x)), 500, 4000)) * np.sin(np.pi * u) ** 0.6
save("beam", norm(reverb(fade(v), 1.0, 0.35), 0.7))

# The Praying Hands: a gospel choir, Amen, swelling out of the light
def choir(chord, d, attack=0.12):
    x = t(d); v = np.zeros(len(x))
    for f in chord:
        for det in (-0.006, 0.0, 0.0055):
            vib = 1 + 0.009 * np.sin(2 * np.pi * rng.uniform(4.8, 6.0) * x + rng.uniform(0, 6))
            v += saw(np.cumsum(f * (1 + det) * vib) / SR + rng.uniform())
    v = formants(v, [(750, 120, 1.0), (1150, 160, 0.6), (2800, 300, 0.35), (3500, 400, 0.15)])
    env = np.minimum(1, x / attack) * np.minimum(1, (d - x) / 0.25)
    return v * env
n = lambda m: 440 * 2 ** ((m - 69) / 12)
eb = [n(m) for m in (51, 58, 63, 67, 70, 75, 79)]
bb = [n(m) for m in (46, 58, 62, 65, 70, 74, 77, 82)]
a = norm(choir(eb, 1.1), 1); b = norm(choir(bb, 3.2, 0.2), 1)
x = t(4.3); v = np.zeros(len(x))
v[:len(a)] += a * 0.8; i = int(1.0 * SR); v[i:i + len(b)] += b
org = sum(np.sin(2 * np.pi * f * x) * w for f, w in [(n(34), .5), (n(46), .5), (n(58), .25)]) * np.minimum(1, x / 0.3) * np.exp(-x * 0.5)
bell = sum(np.sin(2 * np.pi * f * x) * np.exp(-x * dk) for f, dk in [(n(82), 1.5), (n(89), 2.2), (n(94), 3.0)])
v = v * 0.7 + org * 0.6 + bell * 0.25
v = v * np.minimum(1, (4.3 - x) / 0.6)
save("choir", norm(reverb(v, 3.0, 0.45), 0.9), ogg=True)

# Relics
x = t(0.9); u = x / 0.9
ch = np.zeros(len(x))
for k in range(9):
    i = int(rng.uniform(0, 0.75) * SR); m = int(0.05 * SR); tt = np.arange(m) / SR
    ch[i:i + m] += sum(np.sin(2 * np.pi * f * tt) for f in rng.uniform(2500, 6000, 3)) * np.exp(-tt * 80)
grap = ch * 0.5 + 0.8 * bp(rng.standard_normal(len(x)), 300, 3000) * np.sin(np.pi * u) ** 2
save("grapple", norm(fade(grap), 0.7))
x = t(0.5); fl = lp(rng.standard_normal(len(x)), 900) * np.exp(-x * 6) + 0.4 * bp(rng.standard_normal(len(x)), 1500, 5000) * np.exp(-x * 30)
save("lantern", norm(fade(fl), 0.55))
save("censer", norm(fade(ch * 0.7 + 0.3 * bp(rng.standard_normal(len(ch)), 2000, 7000) * np.exp(-t(0.9) * 4)), 0.5))
x = t(0.9); dr = np.zeros(len(x))
for k in range(3):
    i = int((0.08 + k * 0.25) * SR); m = int(0.16 * SR); tt = np.arange(m) / SR
    dr[i:i + m] += np.sin(2 * np.pi * (180 + 300 * tt) * tt) * np.sin(np.pi * tt / 0.16) * 0.8
dr += 0.15 * lp(rng.standard_normal(len(x)), 600)
save("drink", norm(fade(dr), 0.6))
x = t(1.2); pk = sum(np.sin(2 * np.pi * f * x) * np.exp(-x * 4) for f in (n(76), n(83), n(88)))
save("relic", norm(reverb(fade(pk), 1.2, 0.3), 0.6))

# The spider: critter squeaks, a dry skitter of many feet, and a hiss before it leaps
for k in range(3):
    d = rng.uniform(0.35, 0.6); x = t(d); u = x / d
    f0 = rng.uniform(2200, 3200) * (1 + 0.35 * np.sin(np.pi * u * rng.uniform(1, 3))) * (1 + 0.04 * np.sin(2 * np.pi * 38 * x))
    v = np.sin(2 * np.pi * np.cumsum(f0) / SR) + 0.3 * np.sin(4 * np.pi * np.cumsum(f0) / SR)
    v *= (np.sin(2 * np.pi * rng.uniform(12, 22) * x) > -0.3) * np.sin(np.pi * u) ** 0.7
    save(f"critter_{k}", norm(reverb(fade(v), 0.5, 0.2), 0.7))
x = t(0.7); v = np.zeros(len(x))
for k in range(40):
    i = int(rng.uniform(0, 0.65) * SR); m = int(0.008 * SR); tt = np.arange(m) / SR
    v[i:i + m] += bp(rng.standard_normal(m), 1500, 7000) * np.exp(-tt * 600) * rng.uniform(0.4, 1)
save("skitter", norm(fade(v), 0.7))
x = t(0.8); u = x / 0.8
v = bp(rng.standard_normal(len(x)), 2500, 9000) * np.minimum(1, x / 0.03) * (1 - u) ** 1.5
v += 0.3 * np.sin(2 * np.pi * np.cumsum(1800 - 900 * u) / SR) * (1 - u)
save("spider_hiss", norm(reverb(fade(v), 0.6, 0.25), 0.8))
print("ok")
