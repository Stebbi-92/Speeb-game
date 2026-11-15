#!/bin/bash
# Runs the game's headless checks and says which passed. Usage: GODOT=/path/to/godot bash tools/test.sh
G=${GODOT:-/home/user/godot/Godot_v4.3-stable_linux.x86_64}
cd "$(dirname "$0")/.."
D=$(mktemp -d)
pass=0; fail=0
check() {   # name, call, then patterns that must all be in the output
	local name=$1 call=$2; shift 2
	XDG_DATA_HOME=$D timeout 150 "$G" --headless --path . -- level=12 call=$call > "$D/$name.log" 2>&1
	local ok=1
	grep -q "SCRIPT ERROR" "$D/$name.log" && ok=0
	for p in "$@"; do grep -qE "$p" "$D/$name.log" || ok=0; done
	if [ $ok = 1 ]; then echo "pass  $name"; pass=$((pass+1)); else echo "FAIL  $name   (log: $D/$name.log)"; fail=$((fail+1)); fi
}
check take_all   debug_takeall  "TAKEALL asked=3 hide=3 meat=2 bone=6 satchel_gone=true" "TAKEALL full asked=1 still_there=true" "TIDY wood=12"
check combat     debug_combat   "COMBAT wind frames=[1-9]" "COMBAT dodged hp ([0-9]+) -> \\1$" "COMBAT staggered=true wind_cancelled=true" "head ray hits=true body ray hits=false"
check guide      debug_guide    "GUIDE start step=0" "GUIDE saved step=[1-9]"
check base_stock debug_basestock "STOCK paid true"
check floors     debug_floors   "FLOORS distinct heights [1-5]:"
check knock      debug_knock    "KNOCK idol start=[0-9.]+ furthest=(1[0-2]|[0-9])\\." "KNOCK rusher start=[0-9.]+ furthest=(1[0-3]|[0-9])\\."
check chest_name debug_chestname "CHESTNAME .*panel=container saved=mjikbr"
check blade      debug_blade    "BLADE out=true light=[1-9][0-9]* heavy=[1-9][0-9]*" "BLADE guarded=[0-9.]+ open=[0-9.]+ stamina_after_guard<100=true" "BLADE winded=true refused=true" "BLADE sheathed=true"
check recoil     debug_recoil   "RECOIL same=true lifted=0\.[0-9]+ settled=0\.0"
check practice   debug_practice "PRACTICE level 0 -> [1-9] dmg [0-9.]+ -> [0-9.]+ kept=true"
check great     debug_greatones "GREAT boss_ash ring=[1-9][0-9]* lane=[1-9][0-9]* fire=0 spent=true wroth false->true spent_harm=160" "GREAT boss_dunes ring=0 lane=0 fire=[1-9][0-9]* spent=false wroth false->true"
echo "$pass passed, $fail failed"
[ $fail = 0 ]
