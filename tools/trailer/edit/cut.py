# Cuts the Brelm gameplay trailer from the filmed shots (clips/*.mp4, filmed by tools/trailer in the game repo).
# Usage: python3 cut.py CLIPDIR [--res 2560x1440] [--preview]
# Writes seg_*.mp4, timing.json and game_audio.wav into work/, then score.py writes the score and
# finish.py (this file with --finish) lays everything together.
import json, os, subprocess, sys
from PIL import Image, ImageDraw, ImageFont

SRC = os.path.dirname(os.path.abspath(__file__))
FONT = os.environ.get("BRELM_FONT", os.path.join(SRC, "Marcellus-Regular.ttf"))
CLIPS = sys.argv[1]
RES = next((a.split("=")[1] for a in sys.argv if a.startswith("--res=")), "1920x1080")
W, H = map(int, RES.split("x"))
FPS = 30
PREVIEW = "--preview" in sys.argv
WORK = os.environ.get("BRELM_WORK", os.path.join(SRC, "work"))
os.makedirs(WORK, exist_ok=True)
BAR = round(H * 0.0963)  # letterbox, about 2.2:1, as in the teaser

# Grades: the teaser's look, dark and a little desaturated, warm highlights, cool shadows
G_DAY = "eq=brightness=-0.03:contrast=1.08:saturation=0.72:gamma=0.95"
G_DUSK = "eq=brightness=-0.02:contrast=1.06:saturation=0.85:gamma=0.97"
G_WARM = "eq=brightness=-0.04:contrast=1.14:saturation=0.9:gamma=0.93,colorbalance=rs=0.04:bs=-0.05:rm=0.06:bm=-0.06:rh=0.05:bh=-0.04"
G_NIGHT = "eq=brightness=0.0:contrast=1.05:saturation=0.9:gamma=1.0"
G_FIGHT = "eq=brightness=-0.02:contrast=1.1:saturation=0.8:gamma=0.97"

# (clip or None for black, in-point s, length s, grade, [(line, t_in, t_out, size, y)], game-audio gain, fade in, fade out)
EDIT_V1 = [
    (None, 0, 4.0, None, [("Speeb sees.", 0.8, 3.4, 52, 0.47)], 0, 0, 0),                                   # 0 open
    ("s01_dawn_ash", 0.8, 5.0, G_WARM, [("The Ashen Waste.", 1.4, 4.5, 44, 0.80)], 0.7, 1.2, 0.3),       # 1 lands
    ("s03_rust_dunes", 1.0, 4.0, G_DUSK, [], 0.7, 0.3, 0.3),
    ("s04_salt_frost", 1.5, 3.0, G_DAY, [], 0.7, 0.3, 0.3),
    ("s02_dead_forest", 1.0, 4.0, G_DUSK, [], 0.7, 0.3, 0.3),
    ("s06_cinderwick_dusk", 1.0, 5.0, G_DUSK, [("A few towns still keep a fire.", 1.0, 4.5, 40, 0.80)], 0.7, 0.3, 0.4),
    ("s08_fp_shotgun", 1.6, 4.0, G_FIGHT, [], 0.9, 0.0, 0.0),                                             # 7 first fight
    ("s10_fp_rifle", 0.8, 4.5, G_FIGHT, [], 0.9, 0.0, 0.0),
    ("s11_night_horde", 0.8, 5.0, G_NIGHT, [("They wear his face.", 0.5, 4.6, 40, 0.76), ("They are not him.", 2.0, 4.6, 40, 0.82)], 0.7, 0.0, 0.0),
    ("s12_fp_flamer", 1.0, 2.5, G_NIGHT, [], 0.9, 0.0, 0.0),
    ("s13_rocket", 0.6, 1.4, G_FIGHT, [], 1.0, 0.0, 0.0),
    (None, 0, 2.6, None, [("Nine beacons stand dead.", 0.5, 2.4, 44, 0.47)], 0, 0, 0),                                                                      # 12 breath
    ("s14_beacon_kindle", 1.4, 7.5, G_NIGHT, [("Light them, one by one.", 3.2, 7.2, 42, 0.80)], 0.9, 0.8, 0.0),  # 13 beacon
    ("s15_cinderwick_night", 1.0, 4.5, G_NIGHT, [("Walk it together. Up to eight.", 0.3, 3.7, 42, 0.80)], 0.5, 0.0, 0.7),  # 14 town
    (None, 0, 5.5, "title", [], 0, 0, 0),                                                                   # 16 title
    (None, 0, 4.5, None, [("Alpha out now", 0.6, 4.0, 34, 0.45), ("speeb.org/game", 1.1, 4.0, 52, 0.53)], 0, 0, 0),  # 17 end
]
MARKS_V1 = dict(lands=1, town1=5, fight=6, forms=8, breath=11, beacon=12, town2=13, title=14, end=15)
# The action cut (2026-11-23): 120 beats a minute, so every cut lands on a beat (0.5 s) and the drop at 26 s.
# Optional 9th field: {"flash": True} opens the shot from white, for the hits on the drop.
EDIT_ACTION = [
    (None, 0, 4.0, None, [("Speeb sees.", 0.8, 3.4, 52, 0.47)], 0, 0, 0),                                          # 0 open
    ("s03_rust_dunes", 1.0, 3.0, G_DUSK, [("The Ashen Waste.", 0.6, 2.8, 44, 0.80)], 0.5, 0.6, 0.0),             # 1 lands 4
    ("s06_cinderwick_dusk", 1.0, 3.0, G_DUSK, [], 0.5, 0.0, 0.0),                                                # 7
    ("s02_dead_forest", 1.0, 2.0, G_DUSK, [], 0.5, 0.0, 0.0),                                                    # 10
    ("s17_drake", 0.5, 3.5, G_WARM, [("They wear his face.", 0.4, 3.3, 40, 0.80)], 0.6, 0.0, 0.0),                # 4 reveals 12
    ("s07_forms_wait", 0.5, 4.0, G_DUSK, [("They are not him.", 0.4, 3.6, 40, 0.80)], 0.6, 0.0, 0.0),             # 15.5
    ("s18_golem", 0.5, 2.5, G_DUSK, [], 0.6, 0.0, 0.0),                                                          # 19.5
    ("s11_night_horde", 1.5, 3.0, G_NIGHT, [], 0.7, 0.0, 0.3),                                                   # 22
    (None, 0, 1.0, None, [], 0, 0, 0),                                                                           # 8 breath before the drop 25
    ("s08_fp_shotgun", 1.4, 2.5, G_FIGHT, [], 1.0, 0.0, 0.0, {"flash": True}),                                   # 9 drop 26
    ("s10_fp_rifle", 1.0, 2.5, G_FIGHT, [], 1.0, 0.0, 0.0),                                                      # 28.5
    ("s19_minigun", 1.0, 2.5, G_FIGHT, [], 1.0, 0.0, 0.0),                                                       # 31
    ("s24_gaunt_rise", 0.8, 2.5, G_NIGHT, [], 1.0, 0.0, 0.0, {"flash": True}),                                   # 33.5
    ("s20_lmg", 0.8, 2.5, G_FIGHT, [], 1.0, 0.0, 0.0),                                                           # 36
    ("s21_glaive", 0.4, 2.5, G_FIGHT, [], 1.0, 0.0, 0.0),                                                        # 38.5
    ("s12_fp_flamer", 1.0, 2.0, G_NIGHT, [], 1.0, 0.0, 0.0),                                                     # 41
    ("s13_sniper", 1.0, 3.0, G_FIGHT, [], 1.0, 0.0, 0.0),                                                        # 43
    ("s22_matron_charge", 1.0, 3.0, G_WARM, [], 1.0, 0.0, 0.0, {"flash": True}),                                 # 46
    ("s23_drake_live", 1.0, 2.0, G_WARM, [], 1.0, 0.0, 0.0),                                                     # 49
    (None, 0, 3.0, None, [("Nine beacons stand dead.", 0.6, 2.8, 44, 0.47)], 0, 0, 0),                             # 19 stop 51
    ("s14_beacon_kindle", 1.4, 6.0, G_NIGHT, [("Light them.", 2.6, 5.8, 46, 0.80)], 0.9, 0.5, 0.0),                # 20 beacon 54
    ("s15_cinderwick_night", 1.0, 3.0, G_NIGHT, [("Walk it together. Up to eight.", 0.3, 2.9, 42, 0.80)], 0.5, 0.0, 0.6),  # 60
    (None, 0, 5.5, "title", [], 0, 0, 0),                                                                        # 22 title 63
    (None, 0, 4.5, None, [("Alpha out now", 0.6, 4.0, 34, 0.45), ("speeb.org/game", 1.1, 4.0, 52, 0.53)], 0, 0, 0),  # 23 end
]
MARKS_ACTION = dict(lands=1, reveal=4, breath=8, drop=9, stop=19, beacon=20, town2=21, title=22, end=23)

CUT = os.environ.get("BRELM_EDIT", "action")
EDIT, MARKS = (EDIT_ACTION, MARKS_ACTION) if CUT == "action" else (EDIT_V1, MARKS_V1)


def text_png(txt, size, path, y):
    """A line of spaced Marcellus text with a soft dark glow, as a transparent PNG the size of the frame."""
    from PIL import ImageFilter
    s = H / 1080
    size = int(size * s)
    im = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    f = ImageFont.truetype(FONT, size)
    lay = Image.new("L", (W, H), 0)
    dr = ImageDraw.Draw(lay)
    sp = size * 0.12
    width = sum(dr.textlength(c, font=f) for c in txt) + sp * (len(txt) - 1)
    x, yy = W / 2 - width / 2, int(H * y)
    for c in txt:
        dr.text((x, yy), c, font=f, fill=255)
        x += dr.textlength(c, font=f) + sp
    glow = lay.filter(ImageFilter.GaussianBlur(6 * s)).point(lambda v: int(v * 0.5))
    im.paste((0, 0, 0, 255), (0, 0), glow)
    im.paste((236, 228, 214, 255), (0, 0), lay)
    im.save(path)


def title_png(path):
    from PIL import ImageFilter
    s = H / 1080
    im = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    for txt, size, y, col in (("BRELM", 150, 0.40, (236, 228, 214)), ("THE  ASHEN  WASTE", 38, 0.58, (200, 170, 130))):
        f = ImageFont.truetype(FONT, int(size * s))
        lay = Image.new("L", (W, H), 0)
        dr = ImageDraw.Draw(lay)
        sp = size * s * 0.18
        width = sum(dr.textlength(c, font=f) for c in txt) + sp * (len(txt) - 1)
        x = W / 2 - width / 2
        for c in txt:
            dr.text((x, int(H * y)), c, font=f, fill=255)
            x += dr.textlength(c, font=f) + sp
        glow = lay.filter(ImageFilter.GaussianBlur(14 * s)).point(lambda v: int(v * 0.35))
        im.paste((255, 170, 90, 255), (0, 0), glow)
        im.paste(col + (255,), (0, 0), lay)
    im.save(path)


def seg(i, e):
    clip, tin, dur, grade, lines, ga, fin, fout = e[:8]
    opts = e[8] if len(e) > 8 else {}
    out = f"{WORK}/seg_{i:02d}.mp4"
    inputs, fl = [], []
    if clip:
        inputs += ["-ss", str(tin), "-t", str(dur), "-i", f"{CLIPS}/{clip}.mp4"]
        v = f"[0:v]fps={FPS},scale={W}:{H}:flags=lanczos,{grade},vignette=angle=0.55,noise=alls=2:allf=t"
    else:
        inputs += ["-f", "lavfi", "-t", str(dur), "-i", f"color=c=black:s={W}x{H}:r={FPS}"]
        v = "[0:v]null"
    if opts.get("flash"):
        v += ",fade=t=in:st=0:d=0.12:color=white"
    if fin:
        v += f",fade=t=in:st=0:d={fin}"
    if fout:
        v += f",fade=t=out:st={dur - fout}:d={fout}"
    v += f",drawbox=x=0:y=0:w=iw:h={BAR}:c=black:t=fill,drawbox=x=0:y=ih-{BAR}:w=iw:h={BAR}:c=black:t=fill[v0]"
    fl.append(v)
    last = "v0"
    pngs = []
    if grade == "title":
        p = f"{WORK}/title.png"; title_png(p); pngs.append((p, 0.4, dur - 0.9, 1.6, 1.0))
    for k, (txt, t0, t1, size, y) in enumerate(lines):
        p = f"{WORK}/line_{i:02d}_{k}.png"; text_png(txt, size, p, y); pngs.append((p, t0, t1, 0.9, 0.7))
    for k, (p, t0, t1, fi, fo) in enumerate(pngs):
        inputs += ["-loop", "1", "-t", str(dur), "-framerate", str(FPS), "-i", p]
        n = len(inputs and [x for x in inputs if x == "-i"]) - 1
        fl.append(f"[{n}:v]format=rgba,fade=t=in:st={t0}:d={fi}:alpha=1,fade=t=out:st={t1 - fo}:d={fo}:alpha=1[t{k}]")
        fl.append(f"[{last}][t{k}]overlay=0:0:format=auto[o{k}]")
        last = f"o{k}"
    # game audio, or silence
    if clip:
        a = f"[0:a]aresample=48000,volume={ga}"
        if fin: a += f",afade=t=in:st=0:d={min(fin, 0.5)}"
        if fout: a += f",afade=t=out:st={dur - fout}:d={fout}"
        a += ",apad[a]"
    else:
        inputs += ["-f", "lavfi", "-t", str(dur), "-i", "anullsrc=r=48000:cl=stereo"]
        n = len([x for x in inputs if x == "-i"]) - 1
        a = f"[{n}:a]anull[a]"
    fl.append(a)
    cmd = ["ffmpeg", "-v", "error", "-y", *inputs, "-filter_complex", ";".join(fl), "-map", f"[{last}]", "-map", "[a]",
           "-t", str(dur), "-c:v", "libx264", "-preset", "veryfast" if PREVIEW else "slow", "-crf", "24" if PREVIEW else "14",
           "-pix_fmt", "yuv420p", "-c:a", "pcm_s16le", "-ar", "48000", "-ac", "2", out]
    subprocess.run(cmd, check=True)
    return out


if __name__ == "__main__":
    only = [int(a) for a in sys.argv[2:] if a.isdigit()]
    starts, t = [], 0.0
    for e in EDIT:
        starts.append(t); t += e[2]
    json.dump(dict(starts=starts, total=t, names=[e[0] for e in EDIT], marks={k: starts[v] for k, v in MARKS.items()}), open(f"{WORK}/timing.json", "w"))
    segs = []
    for i, e in enumerate(EDIT):
        if only and i not in only:
            segs.append(f"{WORK}/seg_{i:02d}.mp4"); continue
        print("seg", i, e[0], flush=True)
        segs.append(seg(i, e))
    with open(f"{WORK}/list.txt", "w") as f:
        for s in segs:
            f.write(f"file '{s}'\n")
    subprocess.run(["ffmpeg", "-v", "error", "-y", "-f", "concat", "-safe", "0", "-i", f"{WORK}/list.txt", "-c", "copy", f"{WORK}/picture.mov"], check=True)
    subprocess.run(["ffmpeg", "-v", "error", "-y", "-i", f"{WORK}/picture.mov", "-vn", "-c:a", "pcm_s16le", f"{WORK}/game_audio.wav"], check=True)
    # Lay the score under the picture and the game's own sound, then a 1080p copy
    score = os.environ.get("BRELM_SCORE", f"{WORK}/score.wav")
    final = os.environ.get("BRELM_OUT", f"{WORK}/brelm-gameplay-trailer-{H}p.mp4")
    if os.path.exists(score) and not PREVIEW:
        subprocess.run(["ffmpeg", "-v", "error", "-y", "-i", f"{WORK}/picture.mov", "-i", score, "-filter_complex",
                        "[0:a]volume=0.8[g];[1:a]volume=1.0[s];[g][s]amix=inputs=2:normalize=0,alimiter=limit=0.79:level=disabled[a]",
                        "-map", "0:v", "-map", "[a]", "-c:v", "libx264", "-preset", "slow", "-crf", "19", "-pix_fmt", "yuv420p",
                        "-c:a", "aac", "-b:a", "256k", "-movflags", "+faststart", final], check=True)
        if H > 1080:
            subprocess.run(["ffmpeg", "-v", "error", "-y", "-i", final, "-vf", "scale=1920:1080:flags=lanczos", "-c:v", "libx264",
                            "-preset", "slow", "-crf", "18", "-c:a", "copy", "-movflags", "+faststart", final.replace(f"{H}p", "1080p")], check=True)
        print("final", final)
    print("total", t)
