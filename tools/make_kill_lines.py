"""Records Brelm's kill lines with Kokoro TTS, then pitches each one up high and unevenly.
Run: python3 tools/make_kill_lines.py <kokoro dir> assets/audio/kills"""
import sys, subprocess, random, os, soundfile as sf
from kokoro_onnx import Kokoro
VD, OUT = sys.argv[1:3]
LINES = [
    "Back to the void.", "Be weighed.", "Balance is restored.", "Speeb sees you.", "Return to the stillness.",
    "You were judged.", "Not today.", "The scales tip.", "Silence.", "Survive that.",
    "Another trial.", "Do not whine.", "Unblinking.", "Begone, lesser one.", "Your form is undone.",
    "I am still standing.", "Judgment is swift.", "Into obscurity.", "Be still.", "The paw has spoken.",
]
k = Kokoro(f"{VD}/kokoro-v1.0.onnx", f"{VD}/voices-v1.0.bin")
rnd = random.Random(9)
voices = ["am_michael", "am_adam", "bm_george", "bm_lewis"]
for i, line in enumerate(LINES):
    audio, sr = k.create(line, voice=voices[i % len(voices)], speed=rnd.uniform(1.0, 1.25), lang="en-us")
    dry = f"{OUT}/_dry{i}.wav"
    sf.write(dry, audio, sr)
    shift = rnd.uniform(1.75, 2.3)  # very high
    # asetrate raises pitch and speed; atempo pulls the speed partway back; vibrato makes it waver
    tempo = max(0.5, min(2.0, 1.0 / shift * rnd.uniform(1.15, 1.4)))
    flt = f"asetrate={int(sr * shift)},aresample=44100,atempo={tempo:.3f},vibrato=f={rnd.uniform(5, 9):.1f}:d={rnd.uniform(0.2, 0.45):.2f},volume=1.6"
    subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", dry, "-af", flt, "-c:a", "libvorbis", "-q:a", "5", f"{OUT}/kill_{i:02d}.ogg"], check=True)
    os.remove(dry)
    print(i, line)
