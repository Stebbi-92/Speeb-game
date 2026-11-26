#!/bin/bash
# Makes the townsfolk's bodies: splits the PS2 pairs (tools/make_people.gd), then bakes Nerd Survivor's moves onto
# each (tools/bake_stranger_moves.gd). Usage: tools/make_people.sh <nerd_survivor.glb> [godot]
# First copy the four ps2_*_pair.glb (Humans of the World, see CREDITS.md) into assets/models/people. They are not
# kept in the game: only what is made from them (the .scn bodies, their textures and the _moves.res clips).
SRC=$1
G=${2:-godot}
cd "$(dirname "$0")/.."
$G --headless --path . -s tools/make_people.gd
for n in nordic amerindian senegalese tamil; do
	for s in f m; do
		SRC=$SRC TGT=res://assets/models/people/${n}_$s.scn PREFIX=" " ONLY_MAPPED=1 USE_REST=1 \
			OUT=res://assets/models/people/${n}_${s}_moves.res \
			CLIPS="Idle=Loop Idle Default,Stand=Personality Stoic,Walk=Walk Forward,Run=Run Forward,Talk=What?,Wave=HI!,Work=Loop Repair" \
			$G --headless --path . -s tools/bake_stranger_moves.gd | grep -E "PACE|SAVE"
	done
done
