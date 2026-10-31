#!/bin/bash
# Usage: tools/shoot.sh <outprefix> <user args...>   Runs the game under Xvfb and copies screenshots out.
OUT=$1; shift
U="/root/.local/share/godot/app_userdata/Brelm- The Hermit of Nine Visions"
rm -f "$U"/shot_*.png
cd /home/user/brelm
timeout 600 xvfb-run -a -s "-screen 0 1600x900x24" /home/user/godot/Godot_v4.3-stable_linux.x86_64 --path . --resolution 1600x900 -- "$@" 2>&1 | grep -vE "ALSA|audio_driver|dummy driver|^\s*$|at: (init_output|initialize)|leaked|resources still|at: (cleanup|clear)" | head -40
for f in "$U"/shot_*.png; do [ -f "$f" ] && python3 -c "
from PIL import Image; import sys
im=Image.open(sys.argv[1]); im.convert('RGB').resize((960,540)).save(sys.argv[2])" "$f" "${OUT}_$(basename "$f" .png | sed 's/shot_//').jpg"; done
ls ${OUT}_* 2>/dev/null
