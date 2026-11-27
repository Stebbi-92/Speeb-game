#!/usr/bin/env bash
# The dedicated server's persistent world: it is raised at once and paused while no one is there,
# runs while a player is in it, and is saved and paused again when they leave.
# With "api", the commands of the server's window are tried instead (one SERVERAPI line).
# Usage: bash tools/server_test.sh [api]   (prints one SERVERWORLD line for tools/test.sh)
G=${GODOT:-${G:-/home/user/godot/Godot_v4.3-stable_linux.x86_64}}
cd "$(dirname "$0")/.."
PORT=${PORT:-24630}
if [ "$1" = api ]; then
	S=$(mktemp)
	XDG_DATA_HOME=$(mktemp -d) timeout 400 "$G" --headless --path . -- server port=$((PORT + 2)) world=apitest lobby= api_test > "$S" 2>&1
	grep -h "SCRIPT ERROR" "$S" | head -5
	grep "^SERVERAPI" "$S" || echo "SERVERAPI none   (server log: $S)"
	exit 0
fi
DATA=$(mktemp -d); S=$(mktemp); C=$(mktemp)
XDG_DATA_HOME=$DATA timeout 330 "$G" --headless --path . -- server port=$PORT world=testworld seed=4242 lobby= status_log > "$S" 2>&1 &
SP=$!
for i in $(seq 1 80); do grep -q "is paused (no players)" "$S" && break; sleep 3; done
idle=false; grep '^STATUS' "$S" | grep '"paused":true' | grep -q '"players":\[\]' && idle=true
made=false; ls "$DATA"/godot/app_userdata/*/wasteland/world_testworld.dat > /dev/null 2>&1 && made=true
at_rest=$(grep -m1 "is paused (no players)" "$S" | grep -oE "Day [0-9]+, [0-9:]+")
sleep 8   # paused: its clock must not move meanwhile
XDG_DATA_HOME=$(mktemp -d) timeout 200 "$G" --headless --path . -- join=127.0.0.1:$PORT call=debug_serverclient name=Visitor > "$C" 2>&1
for i in $(seq 1 10); do [ "$(grep -c 'is paused (no players)' "$S")" -ge 2 ] && break; sleep 1; done
woke=$(grep -m1 "The world runs again" "$S" | grep -oE "Day [0-9]+, [0-9:]+")
rest2=$(grep "is paused (no players)" "$S" | sed -n 2p | grep -oE "Day [0-9]+, [0-9:]+")
held=false; [ -n "$at_rest" ] && [ "$at_rest" = "$woke" ] && held=true
ran=false; [ -n "$rest2" ] && [ "$rest2" != "$woke" ] && ran=true
saved=false; grep -q "The last player left. The world is saved." "$S" && saved=true
# One named in the bans file is turned away at the door, and the world sleeps on
U=$(ls -d "$DATA"/godot/app_userdata/*/ | head -1)
echo '{"names": ["outcast"], "ips": []}' > "$U/server_bans.json"
B=$(mktemp)
XDG_DATA_HOME=$(mktemp -d) timeout 90 "$G" --headless --path . -- join=127.0.0.1:$PORT call=debug_kickclient name=Outcast > "$B" 2>&1
banned=false; grep -q "NETENDED The host has sent you away" "$B" && [ "$(grep -c 'The world runs again' "$S")" = 1 ] && banned=true
joined=false; grep -q "SERVERCLIENT ready=true" "$C" && grep -q '"players":\[{"id":[0-9]*,"name":"Visitor"' "$S" && joined=true
kill $SP 2>/dev/null
grep -h "SCRIPT ERROR" "$S" "$C" | head -5
echo "SERVERWORLD made=$made idle_paused=$idle held=$held joined=$joined ran=$ran saved=$saved repaused=$([ -n "$rest2" ] && echo true || echo false) banned=$banned   (rest $at_rest, woke $woke, rest again $rest2. Server log: $S  player log: $C)"
