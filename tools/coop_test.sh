#!/usr/bin/env bash
# Two-machine check on one machine: a headless host raises a big world, a headless newcomer joins,
# and the world must arrive whole (sent in parts, packed small). Usage: bash tools/coop_test.sh
G=${G:-/home/user/godot/Godot_v4.3-stable_linux.x86_64}
PORT=${PORT:-24620}
H=$(mktemp); C=$(mktemp)
XDG_DATA_HOME=$(mktemp -d) timeout 220 "$G" --headless --path . -- host=$PORT begin=12 call=debug_snaphost name=Host > "$H" 2>&1 &
HP=$!
for i in $(seq 1 70); do grep -q "SNAPHOST ready" "$H" && break; sleep 3; done
XDG_DATA_HOME=$(mktemp -d) timeout 150 "$G" --headless --path . -- join=127.0.0.1:$PORT call=debug_snapclient name=Guest > "$C" 2>&1
kill $HP 2>/dev/null
if grep -qE "SNAPCLIENT ready=true day=42 pads=6000 waiting=false brisk=true" "$C"; then
	echo "pass  snapshot"
else
	echo "FAIL  snapshot   (host: $H  newcomer: $C)"; exit 1
fi

# The host sends a joiner away; the same name is turned back when it tries again
PORT2=$((PORT + 1))
H=$(mktemp); C=$(mktemp); C2=$(mktemp)
XDG_DATA_HOME=$(mktemp -d) timeout 260 "$G" --headless --path . -- host=$PORT2 begin=12 call=debug_kickhost name=Host > "$H" 2>&1 &
HP=$!
for i in $(seq 1 70); do grep -q "KICKHOST ready" "$H" && break; sleep 3; done
XDG_DATA_HOME=$(mktemp -d) timeout 150 "$G" --headless --path . -- join=127.0.0.1:$PORT2 call=debug_kickclient name=Guest > "$C" 2>&1
XDG_DATA_HOME=$(mktemp -d) timeout 90 "$G" --headless --path . -- join=127.0.0.1:$PORT2 call=debug_kickclient name=guest > "$C2" 2>&1
kill $HP 2>/dev/null
if grep -q "NETENDED The host has sent you away" "$C" && grep -q "NETENDED The host has sent you away" "$C2" && grep -q "KICKHOST sent=true" "$H"; then
	echo "pass  kick"
else
	echo "FAIL  kick   (host: $H  joiner: $C  again: $C2)"; exit 1
fi
