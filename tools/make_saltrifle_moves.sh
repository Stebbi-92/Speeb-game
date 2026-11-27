#!/bin/bash
# Bakes Nerd Survivor's rifle aim and rifle stance onto the skeleton warrior (folk/skelet_warrior.glb), for the
# Salt Rifleman: its own clips hold a sword low. Only the donor's motion is used, never its mesh. Its deforming bones
# hang from rig controls its own clips move, so every bone gets a track (ALL_TRACKS); its binds lie in another
# frame, so its rest is used (USE_REST); its helmet, belt and pauldrons hang from controls, which follow the
# bones they lie on (FOLLOW).
# Usage: tools/make_saltrifle_moves.sh <nerd_survivor.glb> [godot]
SRC=$1
G=${2:-godot}
cd "$(dirname "$0")/.."
SRC=$SRC TGT=res://assets/models/foes/folk/skelet_warrior.glb PREFIX=" " ALL_TRACKS=1 USE_REST=1 \
	ALIAS="Hips=DEF-spine_05,Spine=DEF-spine.001_06,Spine1=DEF-spine.002_07,Spine2=DEF-spine.003_08,Neck=DEF-spine.004_09,Head=DEF-spine.006_011,LeftArm=DEF-upper_arm.L_0176,LeftForeArm=DEF-forearm.L_0178,LeftHand=DEF-hand.L_0180,RightArm=DEF-upper_arm.R_0241,RightForeArm=DEF-forearm.R_0243,RightHand=DEF-hand.R_0245,LeftUpLeg=DEF-thigh.L_072,LeftLeg=DEF-shin.L_074,LeftFoot=DEF-foot.L_076,LeftToeBase=DEF-toe.L_077,RightUpLeg=DEF-thigh.R_090,RightLeg=DEF-shin.R_092,RightFoot=DEF-foot.R_094,RightToeBase=DEF-toe.R_095" \
	FOLLOW="ORG-spine.006_0107=DEF-spine.006_011,hips_018=DEF-spine_05,ORG-upper_arm.L_01=DEF-upper_arm.L_0176,ORG-upper_arm.R_0182=DEF-upper_arm.R_0241" \
	CLIPS="${CLIPS:-Aim=Rifle Aim,Idle=Idle Rifle}" \
	OUT=${OUT:-res://assets/models/foes/folk/skelet_rifle_moves.res} \
	$G --headless --path . -s tools/bake_stranger_moves.gd | grep -E "PACE|SAVE|FRAME|ERROR"
