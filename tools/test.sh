#!/bin/bash
# Runs the game's headless checks and says which passed. Usage: GODOT=/path/to/godot bash tools/test.sh
G=${GODOT:-/home/user/godot/Godot_v4.3-stable_linux.x86_64}
cd "$(dirname "$0")/.."
D=$(mktemp -d)
pass=0; fail=0
check() {   # name, call, then patterns that must all be in the output
	local name=$1 call=$2; shift 2
	local data=$D
	[ "$name" = minds ] && data=$(mktemp -d)   # a fresh world: earlier checks leave camps and floors about
	XDG_DATA_HOME=$data timeout 150 "$G" --headless --path . -- level=12 call=$call > "$D/$name.log" 2>&1
	local ok=1
	grep -q "SCRIPT ERROR" "$D/$name.log" && ok=0
	for p in "$@"; do grep -qE "$p" "$D/$name.log" || ok=0; done
	if [ $ok = 1 ]; then echo "pass  $name"; pass=$((pass+1)); else echo "FAIL  $name   (log: $D/$name.log)"; fail=$((fail+1)); fi
}
check take_all   debug_takeall  "TAKEALL asked=3 hide=3 meat=2 bone=6 satchel_gone=true" "TAKEALL full asked=1 still_there=true" "TIDY wood=12"
check combat     debug_combat   "COMBAT wind frames=[1-9]" "COMBAT dodged hp ([0-9]+) -> \\1$" "COMBAT staggered=true wind_cancelled=true" "head ray hits=true body ray hits=false"
check guide      debug_guide    "GUIDE start step=0" "GUIDE saved step=[1-9]"
check base_stock debug_basestock "STOCK paid true"
check knock      debug_knock    "KNOCK idol start=[0-9.]+ furthest=(1[0-2]|[0-9])\\." "KNOCK rusher start=[0-9.]+ furthest=(1[0-3]|[0-9])\\."
check chest_name debug_chestname "CHESTNAME .*panel=container saved=mjikbr"
check blade      debug_blade    "BLADE out=true light=[1-9][0-9]* heavy=[1-9][0-9]*" "BLADE guarded=[0-9.]+ open=[0-9.]+ stamina_after_guard<100=true" "BLADE winded=true refused=true" "BLADE sheathed=true"
check recoil     debug_recoil   "RECOIL same=true lifted=0\.[0-9]+ settled=0\.0"
check practice   debug_practice "PRACTICE level 0 -> [1-9] dmg [0-9.]+ -> [0-9.]+ kept=true"
check great     debug_greatones "GREAT boss_ash ring=[1-9][0-9]* lane=[1-9][0-9]* fire=0 spent=true wroth false->true spent_harm=160" "GREAT boss_dunes ring=0 lane=0 fire=[1-9][0-9]* spent=false wroth false->true"
check blood     debug_blood    "BLOOD on=1 off=0"
check foes      debug_foes     "FOES gunman shot=true" "FOES parried=true guarded_harm=[0-9]\." "FOES dead_gone=true"
check armour    debug_armour   "ARMOUR foe plate=120 body=[0-9]+ head=40 pierce=[0-9]+ broken=true" "ARMOUR worn left=[0-9]+ took=[0-9]+ mend=\{ \"scrap\": [0-9]+ \} whole=120 kept=7"
check minds     debug_minds    "MINDS calm=calm quiet=calm loud=(search|hunt) band=(search|hunt) saw=hunt hurt=flee back=hunt"
check glass     debug_glass    "GLASS old=true new=false"
check cat       debug_cat      "CAT tamed=true riding=true faster=true sprint=true spent=true shared=true followed=true off=true back=true"
check hitbox    debug_hitbox   "HITBOX all=true heads=true"
check meals     debug_meals    "MEALS hp=true stam=true three=true held=true swapped=true worn=true comfort=1 rested=true xp=true saved=true"
check lands     debug_lands    "LANDS tiers=6 harder=true bites=true warded=true stuff=true"
check build     debug_build    "BUILD up=true kept=true bed=true stove=true shelf=true snug=true"
check inn       debug_inn      "INN towns=true meal=true talk=true snug=true walls=true"
check tabsfit    debug_tabsfit  "TABSFIT { \"craft\": 700, \"arms\": 700, \"wear\": 700, \"build\": 700 }"
check fixes     debug_fixes    "FIXES map_ready=true map_open_fast=true slept=true woke=true"
check newfoes   debug_newfoes  "NEWFOES made=8 hit=8 burning=true slowed=true hurts=true slow_speed=true"
check questfoes debug_questfoes "QUESTFOES cleared=true"
check slug      debug_slug     "SLUG early=false landed=true flight_ms=true"
check packfit   debug_packfit  "PACKFIT fits=true"
check regrow    debug_regrow   "REGROW far=true near_kept=true seen=true"
check power     debug_power    "POWER base=true grows=true hp_grows=true"
check wear      debug_wear     "WEAR before=false on=true off=true moved=true"
check sprint    debug_sprint   "SPRINT faster=true spends=true"
check sea       debug_sea      "SEA isles=4 dry=4 nodes=[1-9][0-9]+ ruins=4 open=true name=The Grey Sea" "SEA swimming=true afloat=true" "SEA tires=true" "SEA spawn_in_water=false"
check boat      debug_boat     "BOAT launched=true boats=1 left_pack=0" "BOAT aboard=true helm=true" "BOAT moved=[1-9][0-9.]* carried=true" "BOAT off=true riders=0" "BOAT sail=2 sloop_speed=([5-9]|1[0-9])\." "BOAT wrecked=true thrown=true"
check weather   debug_weather  "WEATHER long_night=true thaw=true cold=true warm=true choke=true covered=true hurt=true" "WEATHER gale_swell=true"
check books     debug_books    "BOOKS isle=true first=book_ship hidden=true read=true shown=true again=false"
check serpent   debug_serpent  "SERPENT open_water_found=true" "SERPENT rose=true" "SERPENT boat_hurt=true"
check greatraid debug_great "GREAT seventh=true warn=1 tonight=0" "GREAT spawned=[1-9][0-9]* alive=[0-9]+" "GREAT spoils=true"
check powers  debug_powers   "POWERS built=true refused=true laid=true lighter=true ended=true"
check tales   debug_tales    "TALES bad=\[\] told=([0-9]+)/\1"
check floors     debug_floors   "FLOORS distinct heights [1-5]:"
echo "$pass passed, $fail failed"
[ $fail = 0 ]
