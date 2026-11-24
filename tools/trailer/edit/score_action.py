# Score for the Brelm action trailer: original, synthesised here, no samples. 120 beats a minute.
# Quiet open -> braams under the great ones -> riser -> a breath -> the drop at 26 s (kick, booming sub, clap,
# war drums, a driven bass line) -> a dead stop at 51 s -> one great braam under the beacon -> the title hit.
# Reads timing.json from cut.py (BRELM_EDIT=action), writes score.wav beside it.
import json, os, wave
import numpy as np
from scipy.signal import butter, sosfilt

OUT = os.environ.get("BRELM_WORK", os.path.join(os.path.dirname(os.path.abspath(__file__)), "work"))
SR = 48000
tm = json.load(open(f"{OUT}/timing.json"))
T = tm["total"]; ST = tm["starts"]; M = tm["marks"]
N = int(T * SR)
t = np.arange(N) / SR
rng = np.random.default_rng(7)
BEAT = 0.5
DROP, STOP, BEACON, TITLE, END = M["drop"], M["stop"], M["beacon"], M["title"], M["end"]
REVEAL, BREATH = M["reveal"], M["breath"]
mix = np.zeros((N, 2))


def lp(x, f, o=2): return sosfilt(butter(o, f, "low", fs=SR, output="sos"), x, axis=0)
def hp(x, f, o=2): return sosfilt(butter(o, f, "high", fs=SR, output="sos"), x, axis=0)
def bp(x, lo, hi): return sosfilt(butter(2, [lo, hi], "band", fs=SR, output="sos"), x, axis=0)
def env(pts):
    xs, ys = zip(*pts); return np.interp(t, xs, ys)
def put(at, x, gain=1.0):
    i = int(at * SR)
    if i >= N: return
    if x.ndim == 1: x = np.c_[x, x]
    m = min(len(x), N - i); mix[i:i + m] += x[:m] * gain


def kick(at, gain=1.0, punch=1.0):
    n = int(0.6 * SR); tt = np.arange(n) / SR
    f = 42 + 110 * np.exp(-tt * 28)
    s = np.sin(2 * np.pi * np.cumsum(f) / SR) * np.exp(-tt * 5.5)
    click = rng.normal(0, 1, n) * np.exp(-tt * 300) * 0.3
    att = np.minimum(1, tt / 0.004)   # a few ms of attack: a step at full scale overshoots in the AAC encode
    put(at, np.tanh((s + click) * 2.2 * punch) * 0.8 * att, gain)


def sub(at, f=36.71, dur=1.4, gain=1.0):
    """The boom: an 808-like sub that drops a little in pitch and rings, driven so it is heard on small speakers."""
    n = int(dur * SR); tt = np.arange(n) / SR
    ff = f * (1 + 0.6 * np.exp(-tt * 18))
    s = np.sin(2 * np.pi * np.cumsum(ff) / SR) * np.exp(-tt * 2.2 / dur) * np.minimum(1, tt / 0.003)
    put(at, np.tanh(s * 2.6) * 0.75, gain)


def clap(at, gain=1.0):
    n = int(0.35 * SR); tt = np.arange(n) / SR
    nz = bp(rng.normal(0, 1, n), 900, 5200)
    e = np.exp(-tt * 18) + 0.6 * np.exp(-np.maximum(tt - 0.012, 0) * 30) * (tt > 0.012)
    tone = np.sin(2 * np.pi * 185 * tt) * np.exp(-tt * 25) * 0.5
    x = (nz * e * 0.5 + tone)
    put(at, np.c_[x, np.roll(x, 90)], gain)


def tom(at, f=90.0, gain=1.0):
    """A war drum: a skin's pitch falling, and the thump of the stick."""
    n = int(0.9 * SR); tt = np.arange(n) / SR
    ff = f * (1 + 0.5 * np.exp(-tt * 14))
    s = np.sin(2 * np.pi * np.cumsum(ff) / SR) * np.exp(-tt * 5)
    th = lp(rng.normal(0, 1, n), 600) * np.exp(-tt * 40) * 0.6
    put(at, np.tanh((s + th) * 1.6) * 0.7, gain)


def hat(at, gain=1.0):
    n = int(0.08 * SR); tt = np.arange(n) / SR
    put(at, hp(rng.normal(0, 1, n), 7000) * np.exp(-tt * 70) * 0.25, gain)


def braam(at, dur=3.0, gain=1.0, root=36.71):
    """The great horn: a stack of detuned saws on D, the filter opening as it swells, with a sub under it."""
    n = int(dur * SR); tt = np.arange(n) / SR
    x = np.zeros((n, 2))
    for mult, a in ((1, 1.0), (2, 0.7), (3, 0.35), (4, 0.3), (6, 0.15)):
        for ch, det in ((0, -0.35), (1, 0.35)):
            ph = rng.random()
            saw = 2 * (((root * mult + det) * tt + ph) % 1.0) - 1
            x[:, ch] += saw * a
    shape = np.minimum(1, tt / 0.08) * np.exp(-tt * 1.1 / dur * 2.0)
    dark, bright = lp(x, 220, 4), lp(x, 1800, 2)
    op = np.clip(tt / (dur * 0.35), 0, 1)[:, None] * np.exp(-tt / dur * 1.5)[:, None]
    y = (dark * (1 - op) + bright * op) * shape[:, None]
    y = np.tanh(y * 1.4) * 0.5
    put(at, y, gain)
    sub(at, root, min(dur, 2.5), gain * 0.9)


def riser(t0, t1, gain=1.0):
    i0, i1 = int(t0 * SR), int(t1 * SR); n = i1 - i0
    r = np.linspace(0, 1, n)
    nz = rng.normal(0, 1, (n, 2))
    # a noise sweep: high-passed noise growing, and a tone climbing
    x = hp(nz, 800) * (r ** 2.5)[:, None] * 0.09
    x += np.sin(2 * np.pi * np.cumsum(60 + 900 * r ** 3) / SR)[:, None] * (r ** 2)[:, None] * 0.10
    mix[i0:i1] += x * gain


def pad(t0, t1, freqs, gain=1.0, cut=1200):
    i0, i1 = int(t0 * SR), int(t1 * SR); n = i1 - i0; tt = np.arange(n) / SR
    x = np.zeros((n, 2))
    for f in freqs:
        for ch, det in ((0, -0.2), (1, 0.2)):
            vib = 1 + 0.004 * np.sin(2 * np.pi * 5.1 * tt + rng.random() * 6)
            w = 2 * np.pi * np.cumsum((f + det) * vib) / SR
            x[:, ch] += np.sin(w) + 0.3 * np.sin(2 * w) + 0.12 * np.sin(3 * w)
    e = np.minimum(1, tt / 1.2) * np.minimum(1, (tt[-1] - tt) / 1.0)
    mix[i0:i1] += lp(x, cut) * e[:, None] * 0.05 * gain


# ---- the open: a low drone and a bell, Speeb's
pad(0.0, REVEAL + 0.5, [36.71, 55.0, 73.42], 1.4, 600)
def bell(at, f=146.83, gain=1.0, dec=6.0):
    n = int(dec * 2 * SR); tt = np.arange(n) / SR
    parts = [(1, 1), (2.01, .5), (2.76, .35), (4.07, .2), (5.43, .12)]
    s = sum(a * np.sin(2 * np.pi * f * r * tt) * np.exp(-tt * (r ** .7) / dec * 3) for r, a in parts)
    put(at, np.c_[s, np.roll(s, 240)] * 0.6 * np.minimum(1, tt / 0.004)[:, None], gain)
bell(0.7, 146.83, 0.12)
sub(ST[1], 36.71, 2.5, 0.6)
for b in np.arange(ST[1], REVEAL, BEAT * 2):   # a slow heartbeat under the lands
    tom(b, 70, 0.25)

# ---- the great ones: a braam on each, war drums gathering beneath
for i in range(4, 8):
    braam(ST[i], 3.0, 0.75 if i < 7 else 0.6)
for b in np.arange(REVEAL, BREATH, BEAT):
    k = (b - REVEAL) / (BREATH - REVEAL)
    tom(b, 95, 0.25 + 0.45 * k)
    if int(round((b - REVEAL) / BEAT)) % 2 == 1:
        tom(b + BEAT / 2, 120, 0.15 + 0.3 * k)
pad(REVEAL, BREATH, [146.83, 174.61, 220.0], 0.9, 2200)
riser(BREATH - 3.0, BREATH, 1.0)
# the breath: everything cut dead, one low whoosh in
mix[int(BREATH * SR):int(DROP * SR)] *= 0.0
riser(DROP - 0.6, DROP, 0.4)

# ---- the drop: kick on every beat, the sub on the bar, clap on two and four, drums, a driven bass
bass_notes = [36.71, 36.71, 43.65, 41.20]   # D, D, F, E: one per bar, the last bar of four turns
for b in np.arange(DROP, STOP, BEAT):
    i = int(round((b - DROP) / BEAT))
    kick(b, 1.0)
    if i % 4 == 0:
        sub(b, bass_notes[(i // 4) % 4], 1.9, 0.9)
    if i % 2 == 1:
        clap(b, 0.55)
    hat(b + BEAT / 2, 0.5)
    hat(b + BEAT / 4, 0.25); hat(b + 3 * BEAT / 4, 0.25)
    if i % 8 in (6, 7):
        tom(b, 110, 0.5); tom(b + BEAT / 2, 85, 0.5)
# the bass line: eighth notes of a sawtooth, ducked by each kick so the boom has room
i0, i1 = int(DROP * SR), int(STOP * SR); n = i1 - i0; tt = np.arange(n) / SR
bar = (tt // 2.0).astype(int) % 4
f0 = np.array(bass_notes)[bar] * 2
saw = 2 * ((np.cumsum(f0) / SR) % 1.0) - 1
gate = ((tt % 0.25) < 0.2).astype(float)
duck = 1 - 0.8 * np.exp(-(tt % BEAT) * 9)
bl = lp(np.tanh(saw * 2.5), 700, 4) * gate * duck * 0.16
mix[i0:i1] += np.c_[bl, bl]
pad(DROP, STOP, [293.66, 349.23, 440.0], 0.5, 3000)
for x in ST:
    if DROP <= x < STOP:
        sub(x, 36.71, 0.8, 0.35)        # a hit on every cut
braam(DROP, 2.0, 0.6)
braam(DROP + 16 * BEAT, 2.0, 0.5)
riser(STOP - 2.0, STOP, 0.8)

# ---- the stop: silence, then the beacon
mix[int(STOP * SR):int((STOP + 0.6) * SR)] *= 0.0
sub(STOP + 0.6, 29.14, 2.4, 0.5)
bell(STOP + 0.6, 73.42, 0.18, 8)
braam(BEACON + 2.6, 5.0, 0.9)          # "Light them."
pad(BEACON, TITLE, [146.83, 220.0, 293.66, 369.99], 1.2, 2600)
for b in np.arange(BEACON + 3.0, TITLE - 0.5, BEAT):
    k = (b - BEACON - 3.0) / (TITLE - BEACON - 3.5)
    tom(b, 90, 0.3 + 0.5 * k)
riser(TITLE - 2.0, TITLE, 0.9)

# ---- the title: the biggest hit, then quiet
mix[int((TITLE - 0.05) * SR):int(TITLE * SR)] *= 0.0
kick(TITLE, 1.2, 1.4)
sub(TITLE, 36.71, 4.5, 1.2)
braam(TITLE, 4.5, 0.9)
bell(TITLE + 0.02, 73.42, 0.22, 10)
bell(END + 1.1, 293.66, 0.035, 5)

mix = mix * env([(0, 0), (0.3, 1), (T - 1.5, 1), (T, 0)])[:, None]
mix = np.tanh(mix * 1.3) / 1.3
mix = mix / (np.abs(mix).max() + 1e-9) * 0.62   # room for the game's own sound on top
pcm = (mix * 32767).astype(np.int16)
with wave.open(f"{OUT}/score.wav", "wb") as w:
    w.setnchannels(2); w.setsampwidth(2); w.setframerate(SR); w.writeframes(pcm.tobytes())
print("ok", T)
