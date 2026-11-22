"""Synthesizes the game's ambient loops and one-shot effects. Run: python3 tools/make_audio.py assets/audio"""
import sys, subprocess, numpy as np, wave, os
OUT = sys.argv[1]; SR = 44100
rng = np.random.default_rng(9)
def lp(x, a):  # one-pole lowpass, a in (0,1)
    y = np.empty_like(x); s = 0.0
    for i in range(len(x)): s += a * (x[i] - s); y[i] = s
    return y
def lp_fast(x, cutoff):
    X = np.fft.rfft(x); f = np.fft.rfftfreq(len(x), 1 / SR)
    return np.fft.irfft(X / (1 + (f / cutoff) ** 4), len(x))
def bp(x, lo, hi):
    X = np.fft.rfft(x); f = np.fft.rfftfreq(len(x), 1 / SR)
    X[(f < lo) | (f > hi)] = 0
    return np.fft.irfft(X, len(x))
def loopify(x, xf=2.0):
    n = int(xf * SR); head = x[:n].copy(); body = x[n:].copy()
    r = np.linspace(0, 1, n); body[-n:] = body[-n:] * (1 - r) + head * r
    return body
def norm(x, peak=0.8): return x / (np.max(np.abs(x)) + 1e-9) * peak
def save(name, x, ogg=True):
    x = np.clip(x, -1, 1); st = np.stack([x, x], 1) if x.ndim == 1 else x
    wp = f"{OUT}/{name}.wav"
    with wave.open(wp, "wb") as w:
        w.setnchannels(2); w.setsampwidth(2); w.setframerate(SR); w.writeframes((st * 32767).astype(np.int16).tobytes())
    if ogg:
        subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", wp, "-c:a", "libvorbis", "-q:a", "4", f"{OUT}/{name}.ogg"], check=True); os.remove(wp)
t = lambda d: np.arange(int(d * SR)) / SR
D = 24
T = t(D)
# wind: noise with slow swells
n = rng.standard_normal(len(T)); w = lp_fast(n, 500) + 0.4 * bp(n, 600, 1400) * (0.5 + 0.5 * np.sin(2 * np.pi * T / 7.0))
w *= 0.55 + 0.45 * np.sin(2 * np.pi * T / 11.0 + 1) * np.sin(2 * np.pi * T / 5.3)
save("wind", norm(loopify(w), 0.6))
# drone: low beating fifths
d = sum(a * np.sin(2 * np.pi * f * T + p) for f, a, p in [(55, 1, 0), (55.3, .8, 1), (82.4, .5, 2), (110.2, .3, 0), (164.8, .12, 1)])
d *= 0.7 + 0.3 * np.sin(2 * np.pi * T / 12.0)
save("drone", norm(loopify(d + 0.05 * lp_fast(rng.standard_normal(len(T)), 200)), 0.5))
# whispers: breathy syllable bursts
wh = np.zeros(len(T))
for _ in range(70):
    s = rng.uniform(0, D - 1); L = rng.uniform(0.15, 0.6); i0 = int(s * SR); m = int(L * SR)
    seg = bp(rng.standard_normal(m), rng.uniform(1500, 2500), rng.uniform(4000, 7000)) * np.sin(np.linspace(0, np.pi, m)) ** 2
    wh[i0:i0 + m] += seg[:len(wh) - i0] * rng.uniform(0.3, 1)
save("whispers", norm(loopify(wh), 0.5))
# birds
b = np.zeros(len(T))
for _ in range(45):
    s = rng.uniform(0, D - 1); i0 = int(s * SR); f0 = rng.uniform(2500, 4500)
    for k in range(rng.integers(1, 5)):
        L = rng.uniform(0.05, 0.14); m = int(L * SR); tt = np.arange(m) / SR
        f = f0 + rng.uniform(-1500, 1500) * tt / L
        seg = np.sin(2 * np.pi * np.cumsum(f) / SR) * np.sin(np.pi * tt / L) ** 2
        j = i0 + int(k * 0.17 * SR); b[j:j + m] += seg[:max(0, len(b) - j)] * 0.6
save("birds", norm(loopify(b), 0.35))
# cave: rumble + drips
c = lp_fast(rng.standard_normal(len(T)), 90) * 3
for _ in range(30):
    i0 = int(rng.uniform(0, D - 1) * SR); m = int(0.25 * SR); tt = np.arange(m) / SR
    f = rng.uniform(900, 1800) * (1 + 2 * np.exp(-tt * 40))
    c[i0:i0 + m] += 0.25 * np.sin(2 * np.pi * np.cumsum(f) / SR) * np.exp(-tt * 18)
save("cave", norm(loopify(c), 0.55))
# soft lulling pad
p = sum(np.sin(2 * np.pi * f * T) * a for f, a in [(220, .6), (277.2, .4), (329.6, .4), (440, .2), (554.4, .1)])
p *= 0.6 + 0.4 * np.sin(2 * np.pi * T / 6)
save("lull", norm(loopify(lp_fast(p, 1500)), 0.4))
# glitch bed: crackle and digital tones
g = np.zeros(len(T))
for _ in range(80):
    i0 = int(rng.uniform(0, D - 1) * SR); m = int(rng.uniform(0.02, 0.2) * SR)
    seg = np.sign(np.sin(2 * np.pi * rng.uniform(100, 1200) * np.arange(m) / SR)) * rng.uniform(0.1, 0.5)
    g[i0:i0 + m] += seg[:len(g) - i0]
save("glitchbed", norm(loopify(g * 0.5 + 0.6 * d / np.max(np.abs(d))), 0.4))
# heartbeat
h = np.zeros(len(T))
for k in np.arange(0, D, 1.1):
    for off, a in [(0, 1), (0.28, 0.7)]:
        i0 = int((k + off) * SR); m = int(0.18 * SR); tt = np.arange(m) / SR
        h[i0:i0 + m] += a * np.sin(2 * np.pi * 48 * tt) * np.exp(-tt * 25)
save("heartbeat", norm(loopify(h, 0.5), 0.7))
# one-shots
def oneshot(d): return t(d)
x = oneshot(7); bell = sum(a * np.sin(2 * np.pi * f * x) * np.exp(-x * dk) for f, a, dk in [(130.8, 1, .5), (261.6 * 1.01, .6, .8), (392 * 1.02, .3, 1.2), (523 * 1.05, .25, 1.6), (697, .15, 2.4), (1050, .08, 3)])
# The bell is now a recording: see tools/make_bell.py
# save("bell", norm(bell * (1 - np.exp(-x * 300)), 0.8))
x = oneshot(0.22); st = lp_fast(rng.standard_normal(len(x)), 400) * np.exp(-x * 30)
save("step", norm(st, 0.5), ogg=False)
x = oneshot(0.9); cv = bp(rng.standard_normal(len(x)), 1500, 6000) * (0.5 + 0.5 * np.abs(np.sin(2 * np.pi * 9 * x))) * np.sin(np.pi * x / 0.9)
save("carve", norm(cv, 0.5), ogg=False)
x = oneshot(4); cr = lp_fast(rng.standard_normal(len(x)), 150) * np.exp(-x * 0.9) + 0.3 * bp(rng.standard_normal(len(x)), 300, 2000) * np.exp(-x * 2)
save("crumble", norm(cr, 0.9), ogg=False)
x = oneshot(1.5); rp = np.sin(2 * np.pi * (600 + 300 * np.exp(-x * 8)) * x) * np.exp(-x * 4) * 0.5 + 0.2 * lp_fast(rng.standard_normal(len(x)), 800) * np.exp(-x * 6)
save("ripple", norm(rp, 0.5), ogg=False)
x = oneshot(0.6); gl = np.sign(np.sin(2 * np.pi * 180 * x * (1 + 3 * x))) * (rng.random(len(x)) > 0.3) * np.exp(-x * 4)
save("glitch", norm(gl, 0.5), ogg=False)
x = oneshot(3); sw = bp(rng.standard_normal(len(x)), 200, 3000) * np.sin(np.pi * x / 3) ** 2
save("whoosh", norm(sw, 0.8), ogg=False)
x = oneshot(2.5); sn = sum(np.sin(2 * np.pi * f * x) * np.exp(-x * 1.5) for f in [65, 98, 131])
save("deny", norm(sn * (1 - np.exp(-x * 60)), 0.7), ogg=False)
print("ok")
# --- combat
x = oneshot(1.4)
blast = lp_fast(rng.standard_normal(len(x)), 2500) * np.exp(-x * 7) + 1.2 * np.sin(2 * np.pi * 55 * x) * np.exp(-x * 9) + 0.3 * lp_fast(rng.standard_normal(len(x)), 300) * np.exp(-x * 2.5)
save("shotgun", norm(blast * (1 - np.exp(-x * 900)), 0.95), ogg=False)
def click(at, f, d=0.03):
    y = np.zeros(int(0.6 * SR)); i = int(at * SR); m = int(d * SR); tt = np.arange(m) / SR
    y[i:i + m] += bp(rng.standard_normal(m), f, f * 4) * np.exp(-tt * 120)
    return y
save("pump", norm(click(0.02, 900) + click(0.2, 1200) + 0.5 * click(0.1, 300, 0.12), 0.7), ogg=False)
save("shell", norm(click(0.02, 1500) + 0.6 * click(0.09, 700), 0.5), ogg=False)
x = oneshot(0.8); hiss = bp(rng.standard_normal(len(x)), 2000, 7000) * np.sin(np.pi * x / 0.8) ** 0.5 * np.exp(-x * 2)
save("hiss", norm(hiss, 0.6), ogg=False)
x = oneshot(1.2); dz = lp_fast(rng.standard_normal(len(x)), 1200) * np.exp(-x * 5) + np.sin(2 * np.pi * (300 * np.exp(-x * 3)) * x) * np.exp(-x * 4)
save("dissolve", norm(dz, 0.7), ogg=False)
x = oneshot(0.5); hu = np.sin(2 * np.pi * 70 * x) * np.exp(-x * 10) + 0.4 * lp_fast(rng.standard_normal(len(x)), 600) * np.exp(-x * 14)
save("hurt", norm(hu, 0.8), ogg=False)
x = oneshot(0.7); sp = np.sin(2 * np.pi * (500 + 900 * np.exp(-x * 9)) * x) * np.exp(-x * 6) * 0.6 + 0.3 * bp(rng.standard_normal(len(x)), 800, 3000) * np.exp(-x * 10)
save("spit", norm(sp, 0.6), ogg=False)
x = oneshot(0.4); bt = lp_fast(rng.standard_normal(len(x)), 900) * np.exp(-x * 18) + 0.5 * np.sin(2 * np.pi * 140 * x) * np.exp(-x * 20)
save("bite", norm(bt, 0.7), ogg=False)
print("combat ok")
# combat music: a slow war drum under the drone
T2 = t(16)
dr = np.zeros(len(T2))
for k, (beat, a) in enumerate([(0, 1), (0.75, 0.5), (1.5, 0.8), (2.0, 1), (2.75, 0.5), (3.5, 0.9)] * 4):
    pass
for bar in range(4):
    for beat, a in [(0, 1), (0.75, 0.5), (1.5, 0.8), (2.0, 1), (2.75, 0.5), (3.5, 0.9)]:
        i0 = int((bar * 4 + beat) * SR); m = int(0.6 * SR); tt = np.arange(m) / SR
        seg = a * (np.sin(2 * np.pi * (60 + 40 * np.exp(-tt * 20)) * tt) * np.exp(-tt * 6) + 0.25 * lp_fast(rng.standard_normal(m), 400) * np.exp(-tt * 25))
        dr[i0:i0 + m] += seg[:max(0, len(dr) - i0)]
pad = sum(np.sin(2 * np.pi * f * T2) * a for f, a in [(55, 1), (82.4, .5), (58.3, .4), (110, .25)]) * (0.6 + 0.4 * np.sin(2 * np.pi * T2 / 8))
save("combat", norm(dr + 0.35 * pad / np.max(np.abs(pad)), 0.8))
print("music ok")
