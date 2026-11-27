#!/usr/bin/env bash
# Co-op through any router, on one machine: the lobby worker runs locally (wrangler dev), a headless host
# waits at its meeting place, and a newcomer joins by the host's code over a WebRTC link (forced, though
# both are on this machine). The world must arrive whole over the link; a second newcomer then walks
# about for a while and says how much went over its link. Prints one LINKTEST line for tools/test.sh.
# Needs Node.js; wrangler is taken from $WRANGLER, else fetched once with npm into ~/.cache/brelm-wrangler.
# Usage: bash tools/link_test.sh
G=${GODOT:-${G:-/home/user/godot/Godot_v4.3-stable_linux.x86_64}}
cd "$(dirname "$0")/.."
ROOT=$PWD
W=${WRANGLER:-$HOME/.cache/brelm-wrangler/node_modules/.bin/wrangler}
if [ ! -x "$W" ]; then
	mkdir -p "$HOME/.cache/brelm-wrangler" && (cd "$HOME/.cache/brelm-wrangler" && npm init -y > /dev/null && npm i -s wrangler@4 > /dev/null 2>&1)
fi
[ -x "$W" ] || { echo "LINKTEST none (no wrangler)"; exit 0; }
LPORT=${LPORT:-8797}; PORT=${PORT:-24650}
L=$(mktemp); H=$(mktemp); C=$(mktemp); R=$(mktemp)
(cd tools/lobby && exec timeout 400 "$W" dev --local --port $LPORT --ip 127.0.0.1 --persist-to "$(mktemp -d)" > "$L" 2>&1) &
LP=$!
for i in $(seq 1 40); do curl -s "http://127.0.0.1:$LPORT/list" > /dev/null 2>&1 && break; sleep 2; done
LOBBY=http://127.0.0.1:$LPORT
XDG_DATA_HOME=$(mktemp -d) timeout 330 "$G" --headless --path . -- lobby=$LOBBY joincode=LINKTS host=$PORT begin=12 call=debug_snaphost name=Host linkonly > "$H" 2>&1 &
HP=$!
for i in $(seq 1 70); do grep -q "SNAPHOST ready" "$H" && break; sleep 3; done
relay=$(curl -s "$LOBBY/code/LINKTS" | grep -o '"relay":true' | head -1)
XDG_DATA_HOME=$(mktemp -d) timeout 150 "$G" --headless --path . -- lobby=$LOBBY linkonly code=LINKTS call=debug_snapclient name=Guest > "$C" 2>&1
kill $HP 2>/dev/null
# A host of a plain world (the one above ends soon after its newcomer), for the walker
H2=$(mktemp)
XDG_DATA_HOME=$(mktemp -d) timeout 300 "$G" --headless --path . -- lobby=$LOBBY joincode=LINKTR host=$((PORT + 1)) begin=12 name=Host linkonly > "$H2" 2>&1 &
HP=$!
for i in $(seq 1 70); do grep -q "land 12 begins" "$H2" && break; sleep 3; done
sleep 5
XDG_DATA_HOME=$(mktemp -d) LINKRATE_SECS=${LINKRATE_SECS:-40} timeout 200 "$G" --headless --path . -- lobby=$LOBBY linkonly code=LINKTR call=debug_linkrate name=Walker > "$R" 2>&1
kill $HP 2>/dev/null; kill $LP 2>/dev/null; pkill -f "wrangler.*--port $LPORT" 2>/dev/null
grep -h "SCRIPT ERROR" "$H" "$C" "$R" | head -3
joined=false; grep -qE "SNAPCLIENT ready=true day=42 pads=6000 waiting=false brisk=true link=true" "$C" && joined=true
fellback=false; grep -q "Trying its address instead" "$C" "$R" && fellback=true
rate=$(grep -o "LINKRATE .*" "$R" | head -1)
echo "LINKTEST listed=${relay:+true} joined=$joined fellback=$fellback $rate   (host: $H  newcomer: $C  walker: $R  lobby: $L)"
