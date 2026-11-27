#!/usr/bin/env bash
# Makes a save fixture from an older release, for tools/oldsave_test.sh: the tag is checked out
# beside this one, given the fixture maker (tools/fixtures/makesave.gd.txt), and played: it fills a
# world (buildings of every kind, beacons, pack, every arm) and keeps it, writing down what it holds.
# Usage: bash tools/save_fixtures.sh v0.24.0-alpha [more tags...]   (run after each release)
G=${GODOT:-${G:-/home/user/godot/Godot_v4.3-stable_linux.x86_64}}
cd "$(dirname "$0")/.."
ROOT=$PWD
for T in "$@"; do
	WT=$(mktemp -d)/old
	git worktree add -f --detach "$WT" "$T" > /dev/null || exit 1
	[ -d .godot ] && cp -r .godot "$WT/.godot"   # most imports are the same: far quicker
	cat tools/fixtures/makesave.gd.txt >> "$WT/world/wasteland.gd"
	(cd "$WT" && timeout 2400 "$G" --headless --import > /dev/null 2>&1)
	DATA=$(mktemp -d); OUT=$ROOT/tools/fixtures/saves/$T; mkdir -p "$OUT"
	(cd "$WT" && XDG_DATA_HOME=$DATA FIXTURE_OUT=$OUT/expect.txt timeout 400 "$G" --headless --path . -- level=12 call=debug_makesave 2>&1 | grep -E "MAKESAVE|SCRIPT ERROR")
	U="$DATA/godot/app_userdata/Brelm- The Hermit of Nine Visions"
	cp "$U"/brelm.save "$OUT/" 2>/dev/null
	cp "$U"/wasteland/*.dat "$OUT/"
	git worktree remove --force "$WT"
done
