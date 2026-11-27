#!/usr/bin/env bash
# Saves kept by older versions of Brelm still load in this one: each fixture in tools/fixtures/saves/<tag>
# (a world, its pilgrim and the game's own save, made by tools/save_fixtures.sh) is put in a fresh
# user folder and played into. Prints one OLDSAVE line per fixture, then OLDSAVES all=true|false.
# Usage: bash tools/oldsave_test.sh
G=${GODOT:-${G:-/home/user/godot/Godot_v4.3-stable_linux.x86_64}}
cd "$(dirname "$0")/.."
all=true; n=0
for fx in tools/fixtures/saves/*/; do
	tag=$(basename "$fx")
	DATA=$(mktemp -d); U="$DATA/godot/app_userdata/Brelm- The Hermit of Nine Visions"
	mkdir -p "$U/wasteland"
	cp "$fx"/*.dat "$U/wasteland/"
	[ -f "$fx/brelm.save" ] && cp "$fx/brelm.save" "$U/"
	L=$(mktemp)
	XDG_DATA_HOME=$DATA OLDSAVE_FROM=$tag OLDSAVE_EXPECT="$PWD/$fx/expect.txt" timeout 200 "$G" --headless --path . -- level=12 call=debug_oldsave > "$L" 2>&1
	grep -h "SCRIPT ERROR" "$L" | head -3
	if grep -q "^OLDSAVE from=$tag same=true kept=true" "$L"; then :; else all=false; fi
	grep -E '^(OLDSAVE|  [a-z])' "$L" | head -12
	grep -q "^OLDSAVE" "$L" || echo "OLDSAVE from=$tag none   (log: $L)"
	n=$((n + 1))
done
echo "OLDSAVES n=$n all=$all"
