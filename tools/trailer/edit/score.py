# Score for the Brelm gameplay trailer (built on the teaser's score). Everything musical is synthesised here (original, no licence needed).
# Two CC0 beds from the Fantasy Ambient Sound Effects Pack (kmontesdev): sound-1.wav (air) and sound-4.wav (low rumble).
import numpy as np, json, subprocess, os
from scipy.signal import butter, sosfilt
import wave

OUT = os.environ.get("BRELM_WORK", os.path.join(os.path.dirname(os.path.abspath(__file__)), "work"))
LIB = os.environ.get("BRELM_LIB", "/mnt/project-files/brelm-game/asset-library/fantasy-ambient-cc0/")
SR = 48000
tm = json.load(open(f"{OUT}/timing.json"))
T = tm["total"]; st = tm["starts"]
N = int(T * SR)
t = np.arange(N) / SR
rng = np.random.default_rng(3)

def load(p):
    raw = subprocess.run(["ffmpeg", "-v", "error", "-i", p, "-ac", "2", "-ar", str(SR), "-f", "f32le", "-"], capture_output=True).stdout
    return np.frombuffer(raw, np.float32).reshape(-1, 2).copy()

def loop(x, n, xf=SR * 2):
    out = np.zeros((n, 2), np.float32); pos = 0
    ramp = np.linspace(0, 1, xf)[:, None]
    while pos < n:
        seg = x.copy(); seg[:xf] *= ramp; seg[-xf:] *= ramp[::-1]
        m = min(len(seg), n - pos); out[pos:pos + m] += seg[:m]; pos += len(seg) - xf
    return out

def env(points):
    xs, ys = zip(*points); return np.interp(t, xs, ys)

def lp(x, f, order=2): return sosfilt(butter(order, f, "low", fs=SR, output="sos"), x, axis=0)
def hp(x, f, order=2): return sosfilt(butter(order, f, "high", fs=SR, output="sos"), x, axis=0)
def bp(x, lo, hi): return sosfilt(butter(2, [lo, hi], "band", fs=SR, output="sos"), x, axis=0)

mix = np.zeros((N, 2))

# --- beds (CC0)
air = loop(load(LIB + "sound-1.wav"), N)
rum = loop(load(LIB + "sound-4.wav"), N)
air /= np.abs(air).max() + 1e-9; rum /= np.abs(rum).max() + 1e-9
M = tm["marks"]
F = M["forms"]
S = {6: M["fight"] - 2.5, 7: M["fight"], 14: M["breath"], 15: M["beacon"], 16: M["town2"], 18: M["title"], 19: M["end"], 0: 0.0, 1: M["lands"], 5: M["town1"]}
bed_env = env([(0, 0), (3, .8), (S[14] - .2, 1), (S[14], .0), (S[15], .0), (S[15] + 1, .8), (T - 3, .6), (T, 0)])
mix += air * 0.10 * bed_env[:, None]
mix += lp(rum, 400) * 0.30 * bed_env[:, None]

# --- wind: filtered noise with slow gusts
noise = rng.normal(0, 1, (N, 2))
gust = 0.6 + 0.4 * np.sin(2 * np.pi * t / 9.0) * np.sin(2 * np.pi * t / 3.7 + 1)
wind = bp(noise, 250, 1400) * gust[:, None]
mix += wind * 0.022 * bed_env[:, None]

# --- drone pad: D minor-ish, low and slow (D1, A1, D2, F2, A2), detuned pairs for width
def pad(freqs, amps, det=0.15):
    o = np.zeros((N, 2))
    for f, a in zip(freqs, amps):
        for ch, d in ((0, -det), (1, det)):
            ph = rng.random() * 6.28
            w = 2 * np.pi * (f + d) * t + ph
            tone = np.sin(w) + 0.35 * np.sin(2 * w) + 0.15 * np.sin(3 * w)  # soft, slightly reedy
            lfo = 0.75 + 0.25 * np.sin(2 * np.pi * t / (7 + 5 * rng.random()) + rng.random() * 6)
            o[:, ch] += a * tone * lfo
    return lp(o, 900)

drone = pad([36.71, 55.0, 73.42, 87.31, 110.0], [1.0, .8, .6, .35, .3])
d_env = env([(0, 0), (4, .5), (S[6], .8), (S[7], 1.0), (S[14] - .2, 1.3), (S[14], 0), (S[15], 0), (S[15] + .05, .9), (S[18], 1.2), (T - 0.5, 0), (T, 0)])
mix += drone * 0.11 * d_env[:, None]

# a higher, colder layer that enters for the forms and the beacons
high = pad([293.66, 349.23, 440.0], [.4, .3, .25], det=0.6)
h_env = env([(0, 0), (S[6], 0), (S[6] + 2, .6), (S[7], .3), (S[14] - .2, 1.2), (S[14], 0), (S[15], 0), (S[15] + 4, .7), (T - 1, 0), (T, 0)])
mix += lp(high, 2500) * 0.035 * h_env[:, None]

# --- hits
def boom(at, gain=1.0, f0=70, f1=32, dec=2.5, tail=1.0):
    n = int((dec * 2.5) * SR); tt = np.arange(n) / SR
    f = f1 + (f0 - f1) * np.exp(-tt * 3)
    s = np.sin(2 * np.pi * np.cumsum(f) / SR) * np.exp(-tt / dec * 1.2)
    nz = lp(rng.normal(0, 1, n), 700) * np.exp(-tt * 6) * 0.6 * tail
    x = (s + nz)[:, None] * [1, 1]
    i = int(at * SR); m = min(n, N - i); mix[i:i + m] += x[:m] * gain

def bell(at, f=146.83, gain=1.0, dec=6.0):
    n = int(dec * 2 * SR); tt = np.arange(n) / SR
    parts = [(1, 1), (2.01, .5), (2.76, .35), (4.07, .2), (5.43, .12)]
    s = sum(a * np.sin(2 * np.pi * f * r * tt) * np.exp(-tt * (r ** .7) / dec * 3) for r, a in parts)
    s *= np.minimum(1, tt / 0.004)
    x = np.c_[s, np.roll(s, 240)] * 0.6
    i = int(at * SR); m = min(n, N - i); mix[i:i + m] += x[:m] * gain

def pulse(t0, t1, bpm0, bpm1, gain):
    """A low heartbeat that quickens through the fights."""
    at = t0
    while at < t1:
        k = (at - t0) / (t1 - t0)
        boom(at, gain * (0.5 + 0.5 * k), 58, 34, 0.5, 0.3)
        boom(at + 0.22, gain * 0.45 * (0.5 + 0.5 * k), 52, 32, 0.4, 0.2)
        at += 60.0 / (bpm0 + (bpm1 - bpm0) * k)

bell(S[0] + 0.7, 146.83, 0.12)       # "Speeb sees."
boom(S[1] - 0.05, 0.55)              # first sight of the waste
bell(S[1] + 0.2, 110.0, 0.08, 8)
bell(S[5] + 0.6, 220.0, 0.04, 6)     # the town
boom(F + 2.0, 0.55, 60, 28)          # "They are not him."
pulse(S[7], S[14] - 0.3, 66, 96, 0.30)
for x in st:
    if S[7] <= x < S[14]:
        boom(x, 0.35, 75, 30, 1.2, 1.2)   # a hit on each cut through the fights

# riser into the black, cut dead
i0, i1 = int(max(x for x in st if x < S[14]) * SR), int(S[14] * SR)
rt = np.linspace(0, 1, i1 - i0)
rise = hp(rng.normal(0, 1, (i1 - i0, 2)), 1500) * (rt ** 3)[:, None] * 0.05
rise += np.sin(2 * np.pi * np.cumsum(40 + 60 * rt ** 2) / SR)[:, None] * (rt ** 2)[:, None] * 0.12
mix[i0:i1] += rise
mix[int(S[14] * SR):int(S[15] * SR)] *= 0.0

bell(S[15] + 0.05, 73.42, 0.16, 10)  # the beacon
bell(S[15] + 4.4, 146.83, 0.10, 8)   # "Light them"
bell(S[16] + 0.3, 220.0, 0.05, 6)     # the town at night
boom(S[18], 1.0, 80, 30, 3.5, 1.4)   # title
bell(S[18] + 0.02, 73.42, 0.22, 10)
bell(S[18] + 0.02, 146.83, 0.10, 8)
bell(S[19] + 1.1, 293.66, 0.035, 5)  # the address

mix = mix * env([(0, 0), (0.3, 1), (T - 1.5, 1), (T, 0)])[:, None]
mix = np.tanh(mix * 1.2) / 1.2
pk = np.abs(mix).max(); mix = mix / pk * 0.85
pcm = (mix * 32767).astype(np.int16)
with wave.open(f"{OUT}/score.wav", "wb") as w:
    w.setnchannels(2); w.setsampwidth(2); w.setframerate(SR); w.writeframes(pcm.tobytes())
print("ok", T)
