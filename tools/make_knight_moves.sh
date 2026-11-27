#!/bin/bash
# Bakes Nerd Survivor's walk, run and melee stance onto the knight (folk/knight.glb), whose own "Walk" barely
# steps. Only the donor's motion is used, never its mesh. Usage: tools/make_knight_moves.sh <nerd_survivor.glb> [godot]
SRC=$1
G=${2:-godot}
cd "$(dirname "$0")/.."
SRC=$SRC TGT=res://assets/models/foes/folk/knight.glb PREFIX=" " ONLY_MAPPED=1 \
	ALIAS="Hips=Root_M,Spine=Spine1_M,Spine1=-,Spine2=Chest_M,Neck=Neck_M,Head=Head_M,LeftArm=Shoulder_L,LeftForeArm=Elbow_L,LeftHand=Wrist_L,RightArm=Shoulder_R,RightForeArm=Elbow_R,RightHand=Wrist_R,LeftUpLeg=Hip_L,LeftLeg=Knee_L,LeftFoot=Ankle_L,LeftToeBase=Toes_L,RightUpLeg=Hip_R,RightLeg=Knee_R,RightFoot=Ankle_R,RightToeBase=Toes_R" \
	CLIPS="Walk=Walk Forward,Run=Run Forward,Idle=Melee Idle" \
	OUT=res://assets/models/foes/folk/knight_moves.res \
	$G --headless --path . -s tools/bake_stranger_moves.gd | grep -E "PACE|SAVE"
