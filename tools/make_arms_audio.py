"""Synthesizes the arsenal's sounds. Run: python3 tools/make_arms_audio.py assets/audio"""
import sys, numpy as np, wave
OUT = sys.argv[1]; SR = 44100
rng = np.random.default_rng(31)
def oneshot(d): return np.arange(int(d * SR)) / SR
def lp(x, cutoff):
    X = np.fft.rfft(x); f = np.fft.rfftfreq(len(x), 1 / SR)
    return np.fft.irfft(X / (1 + (f / cutoff) ** 4), len(x))
def bp(x, lo, hi):
    X = np.fft.rfft(x); f = np.fft.rfftfreq(len(x), 1 / SR); X[(f < lo) | (f > hi)] = 0
    return np.fft.irfft(X, len(x))
def norm(x, peak=0.8): return x / (np.max(np.abs(x)) + 1e-9) * peak
def noise(x): return rng.standard_normal(len(x))
def save(name, x):
    x = np.clip(x, -1, 1); st = np.stack([x, x], 1)
    with wave.open(f"{OUT}/{name}.wav", "wb") as w:
        w.setnchannels(2); w.setsampwidth(2); w.setframerate(SR); w.writeframes((st * 32767).astype(np.int16).tobytes())
attack = lambda x, k=900: 1 - np.exp(-x * k)
# A gunshot: a sharp crack, a body of low thump, and a tail; sizes vary per gun
def shot(d, crack, crack_decay, thump_f, thump_decay, tail_cut, tail_decay, tail_amt):
    x = oneshot(d)
    y = lp(noise(x), crack) * np.exp(-x * crack_decay)
    y += 1.0 * np.sin(2 * np.pi * thump_f * x) * np.exp(-x * thump_decay)
    y += tail_amt * lp(noise(x), tail_cut) * np.exp(-x * tail_decay)
    return y * attack(x)
save("pistol", norm(shot(0.9, 4500, 18, 90, 22, 600, 4, 0.35), 0.85))
save("revolver", norm(shot(1.3, 3500, 12, 70, 14, 450, 3, 0.5), 0.95))
save("mg", norm(shot(0.45, 4000, 22, 80, 26, 700, 7, 0.3), 0.85))
save("minigun", norm(shot(0.18, 5000, 40, 110, 45, 900, 18, 0.2), 0.75))
save("sniper", norm(shot(2.6, 3000, 9, 48, 7, 300, 1.4, 0.8), 1.0))
x = oneshot(0.35); s = bp(noise(x), 600, 5000) * np.exp(-x * 30) + 0.4 * np.sin(2 * np.pi * 140 * x) * np.exp(-x * 40)
save("supp", norm(s * attack(x, 2000), 0.6))
x = oneshot(1.6); r = bp(noise(x), 200, 3500) * (np.exp(-x * 2.2)) + 0.8 * np.sin(2 * np.pi * 60 * x) * np.exp(-x * 10)
save("rocket", norm(r * attack(x, 300), 0.85))
x = oneshot(3.2)
b = lp(noise(x), 1800) * np.exp(-x * 5) + 1.6 * np.sin(2 * np.pi * (40 + 30 * np.exp(-x * 6)) * x) * np.exp(-x * 3) + 0.6 * lp(noise(x), 180) * np.exp(-x * 1.1)
save("boom", norm(b * attack(x, 600), 1.0))
x = oneshot(0.4); sw = bp(noise(x), 400, 2500) * np.sin(np.pi * np.clip(x / 0.3, 0, 1)) ** 2
save("swing", norm(sw, 0.5))
x = oneshot(0.45); ch = lp(noise(x), 1500) * np.exp(-x * 25) + 0.7 * np.sin(2 * np.pi * 120 * x) * np.exp(-x * 30) + 0.25 * bp(noise(x), 2500, 6000) * np.exp(-x * 40)
save("chop", norm(ch * attack(x, 3000), 0.8))
x = oneshot(0.3); th = lp(noise(x), 500) * np.exp(-x * 35)
save("thud", norm(th * attack(x, 3000), 0.6))
print("ok")
# --- aircraft and the hit tick
x = oneshot(9.0)
env = np.exp(-((x - 4.0) / 1.6) ** 2)
j = bp(noise(x), 300, 6000) * env + 0.6 * lp(noise(x), 250) * np.exp(-((x - 4.3) / 2.2) ** 2)
j += 0.15 * np.sin(2 * np.pi * (900 - 500 * (x > 4) * (x - 4) / 5) * x) * env
save("jet", norm(j, 0.9))
x = oneshot(2.2)
saw = (np.mod(x * 70, 1.0) - 0.5) * (x < 1.4)
br = lp(saw + 0.4 * noise(x) * (x < 1.4), 1400) * (1 - np.exp(-x * 40)) + 0.4 * lp(noise(x), 300) * np.exp(-(x - 1.3).clip(0) * 2)
save("brrt", norm(br, 0.95))
x = oneshot(2.4)
rot = lp(noise(x), 220) * (0.4 + 0.6 * np.abs(np.sin(2 * np.pi * 5.5 * x)) ** 4) + 0.25 * bp(noise(x), 800, 3000) * (np.abs(np.sin(2 * np.pi * 5.5 * x + 1)) ** 8)
fade = np.minimum(1, np.minimum(x / 0.3, (2.4 - x) / 0.3))
save("rotor", norm(rot * fade, 0.8))
x = oneshot(0.08); tk = np.sin(2 * np.pi * 1900 * x) * np.exp(-x * 90)
save("tick", norm(tk, 0.35))
print("ok")
