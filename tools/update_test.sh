#!/bin/bash
# Tests a split update end to end, here, with a local server standing in for GitHub:
#   the "installed" game (this project as it is, a full pack beside the program) finds a newer release,
#   fetches its code pack and only the parts it lacks, restarts onto it, and the new version runs.
# Two releases are tried: one changing only code (every part comes from the installed game), and one
# whose textures part is new (that part is fetched, the rest come from the installed game).
# Usage: bash tools/update_test.sh        (prints UPDATE ... ok / FAIL)
G=${GODOT:-/home/user/godot/Godot_v4.3-stable_linux.x86_64}
cd "$(dirname "$0")/.."
ROOT=$PWD
T=$(mktemp -d)
PORT=${PORT:-8766}
VER=$(sed -n 's/^config\/version="\(.*\)"/\1/p' project.godot)
NEW=0.99.0-alpha
cp project.godot "$T/project.godot.keep"
restore() { cp "$T/project.godot.keep" "$ROOT/project.godot"; rm -f "$ROOT/parts.json"; }
trap restore EXIT
python3 tools/split_pack.py plan
mkdir -p "$T/inst"
cp "$G" "$T/inst/Brelm"
$G --headless --path . --export-pack "Linux" "$T/inst/Brelm.pck" > "$T/export-a.log" 2>&1 || { echo "FAIL export"; exit 1; }
sed -i "s/^config\/version=.*/config\/version=\"$NEW\"/" project.godot
$G --headless --path . --export-pack "Linux" "$T/full-b.pck" > "$T/export-b.log" 2>&1 || { echo "FAIL export"; exit 1; }
restore
python3 -m http.server "$PORT" --bind 127.0.0.1 --directory "$T/srv" > /dev/null 2>&1 &
SRV=$!
mkdir -p "$T/srv"
trap 'restore; kill $SRV 2>/dev/null' EXIT
fail=0
for CASE in ${CASES:-code textures whole}; do
	D="$T/srv/releases/download/v$NEW"
	rm -rf "$T/srv/releases"; mkdir -p "$D"
	CHANGED=$([ $CASE = textures ] && echo textures || echo "")
	if [ $CASE = whole ]; then
		# A release this build has no pack for (a new engine or plugin): only the whole game, zipped
		rm -rf "$T/zipsrc"; mkdir -p "$T/zipsrc"; cp "$G" "$T/zipsrc/Brelm"; cp "$T/full-b.pck" "$T/zipsrc/Brelm.pck"
		(cd "$T/zipsrc" && python3 -c "import zipfile,sys; z=zipfile.ZipFile(sys.argv[1],'w',zipfile.ZIP_DEFLATED); [z.write(n) for n in ('Brelm','Brelm.pck')]" "$D/Brelm-Linux.zip")
	else
		SPLIT_TEST_CHANGED=$CHANGED python3 tools/split_pack.py split "$T/full-b.pck" Linux "$D" > /dev/null
	fi
	python3 - "$T/srv" "$NEW" "$PORT" <<'P'
import json, os, sys, hashlib
srv, new, port = sys.argv[1:4]
d = os.path.join(srv, "releases/download/v" + new)
assets = []
for n in sorted(os.listdir(d)):
	h = hashlib.sha256(open(os.path.join(d, n), "rb").read()).hexdigest()
	assets.append({"name": n, "browser_download_url": "http://127.0.0.1:%s/releases/download/v%s/%s" % (port, new, n), "size": os.path.getsize(os.path.join(d, n)), "digest": "sha256:" + h})
json.dump([{"tag_name": "v" + new, "name": "Test " + new, "body": "", "html_url": "", "draft": False, "assets": assets}], open(os.path.join(srv, "releases.json"), "w"))
P
	DATA=$(mktemp -d)
	export XDG_DATA_HOME=$DATA WANT=$NEW BRELM_RELEASES="http://127.0.0.1:$PORT/releases.json" BRELM_PACK_HOME="http://127.0.0.1:$PORT/releases/download/"
	# First the installed game alone, as a player would have started it before (it notes its parts),
	# then the update: the second start is the new version, started by the first
	(cd "$T" && timeout 300 "$T/inst/Brelm" --headless -- level=12 call=debug_folk > "$T/$CASE-0.log" 2>&1)
	(cd "$T" && timeout 600 "$T/inst/Brelm" --headless -- level=12 call=debug_updtest > "$T/$CASE-1.log" 2>&1)
	# the restarted game writes to the same terminal; wait for it to end
	for i in $(seq 1 150); do pgrep -f "inst/Brelm|put-in-place" > /dev/null || break; sleep 2; done
	grep -h UPDTEST "$T/$CASE-1.log"
	if [ $CASE = whole ]; then
		want=$(grep "UPDTEST on $NEW code_pack=false" "$T/$CASE-1.log")
		grep -q "UPDTEST leftovers=false" "$T/$CASE-1.log" || want=""
	elif [ $CASE = code ]; then
		want=$(grep "UPDTEST on" "$T/$CASE-1.log" | grep -c fetched | grep -x 0)   # every part from the installed game
	else
		want=$(grep "UPDTEST on" "$T/$CASE-1.log" | grep -o '"textures": "fetched"')
	fi
	if grep -q "UPDTEST on $NEW" "$T/$CASE-1.log" && [ -n "$want" ] && grep -q "UPDTEST folk ok" "$T/$CASE-1.log"; then
		echo "UPDATE $CASE ok"
	else
		echo "UPDATE $CASE FAIL (logs in $T)"; fail=1
	fi
	unset XDG_DATA_HOME WANT BRELM_RELEASES BRELM_PACK_HOME
done
exit $fail
