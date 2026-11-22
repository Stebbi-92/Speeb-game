"""The beacon bell from a recorded bell strike (Kenney Impact Sounds, CC0): the strike, the same an octave
down for weight, and a long hall tail (the strike run through a decaying-noise room), about six seconds.
Usage: python3 tools/make_bell.py <impactBell_heavy_001.ogg>"""
import subprocess, sys
import numpy as np

SR = 44100
def load(path, rate=SR):
	raw = subprocess.run(["ffmpeg", "-v", "error", "-i", path, "-f", "f32le", "-ac", "1", "-ar", str(rate), "-"], capture_output=True, check=True).stdout
	return np.frombuffer(raw, dtype=np.float32).astype(np.float64)

strike = load(sys.argv[1])
low = load(sys.argv[1], SR // 2)   # read at half the rate and played at the full one: an octave down, twice as long
n = int(SR * 6.5)
dry = np.zeros(n)
dry[:len(strike)] += strike
dry[:len(low)] += low * 1.2
rng = np.random.default_rng(7)
t = np.arange(int(SR * 4.0)) / SR
ir = rng.standard_normal(len(t)) * np.exp(-t * 1.6)
ir[: int(SR * 0.02)] *= np.linspace(0, 1, int(SR * 0.02))
# Darker as it fades: a gentle low-pass on the room
k = np.exp(-np.arange(64) / 10.0)
ir = np.convolve(ir, k / k.sum(), mode="same")
wet = np.fft.irfft(np.fft.rfft(dry, 2 * n) * np.fft.rfft(ir, 2 * n))[:n]
out = dry * 0.8 + wet / np.abs(wet).max() * np.abs(dry).max() * 0.55
fade = np.ones(n)
fs = int(SR * 4.8)
fade[fs:] = np.linspace(1, 0, n - fs) ** 2
out *= fade
out = out / np.abs(out).max() * 0.8
subprocess.run(["ffmpeg", "-v", "error", "-y", "-f", "f32le", "-ar", str(SR), "-ac", "1", "-i", "-", "-c:a", "libvorbis", "-q:a", "6", "assets/audio/bell.ogg"],
	input=out.astype(np.float32).tobytes(), check=True)
