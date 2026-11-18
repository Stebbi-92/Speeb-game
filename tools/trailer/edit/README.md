# Trailer edit

`cut.py` cuts the filmed clips (render.ps1's `clips` folder) into the gameplay trailer: grade, letterbox,
titles in Marcellus, the game's own sound, and `score.flac` (an original score, synthesised by `score.py`
from the edit's timing; its two ambient beds are CC0, Fantasy Ambient Sound Effects Pack by kmontesdev).

    set BRELM_WORK=D:\BrelmTrailer\edit
    set BRELM_FONT=D:\BrelmTrailer\game\assets\fonts\Marcellus-Regular.ttf
    set BRELM_SCORE=D:\BrelmTrailer\edit\score.wav     (ffmpeg -i score.flac score.wav)
    python cut.py D:\BrelmTrailer\clips --res=2560x1440

Needs Python 3 with Pillow, and ffmpeg on PATH. Writes brelm-gameplay-trailer-1440p.mp4 and -1080p.mp4.
