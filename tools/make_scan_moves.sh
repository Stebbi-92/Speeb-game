#!/bin/bash
# Bakes Nerd Survivor's walk and run onto two scanned bodies whose own clips do not step. Only the donor's motion
# is used, never its mesh. Usage: tools/make_scan_moves.sh <nerd_survivor.glb> [godot]
#  - the Gaunt (horror_monster.glb, its own "Walk" a stagger in place): walk, run and idle, limb for limb
#  - the Unseen (unseen_humandeer.glb, its one clip a crouched sway): only its hips and legs, its bent-back deer's
#    legs set by IK where the donor's ankles go (LEG_IK), its feet held flat (FOOT_HOLD); the rest of it keeps the
#    sway of its own clip (OWN_CLIP)
SRC=$1
G=${2:-godot}
cd "$(dirname "$0")/.."
SRC=$SRC TGT=res://assets/models/foes/horror_monster/horror_monster.glb PREFIX="AboveMonsterRig_Bind_" ONLY_MAPPED=1 \
	CLIPS="Walk=Walk Forward,Run=Run Forward,Idle=Loop Idle Default" \
	OUT=res://assets/models/foes/horror_monster/gaunt_moves.res \
	$G --headless --path . -s tools/bake_stranger_moves.gd | grep -E "PACE|SAVE"
SRC=$SRC TGT=res://assets/models/foes/unseen/unseen_humandeer.glb PREFIX=" " ONLY_MAPPED=1 USE_REST=1 UP_Y=1 LEG_IK=1 FOOT_HOLD=1 \
	OWN_CLIP="Take 001" MAP_ONLY="Hips,LeftUpLeg,LeftLeg,LeftFoot,RightUpLeg,RightLeg,RightFoot" \
	ALIAS="Hips=C_Hip_J_00,Spine=C_spine_01_J_018,Spine1=C_spine_02_J_019,Spine2=C_spine_03_J_020,Neck=C_Neck_J_022,Head=C_Head_J_023,LeftArm=L_shoulder_J_034,LeftForeArm=L_elbow_J_035,LeftHand=L_wrist_J_036,RightArm=R_shoulder_J_053,RightForeArm=R_elbow_J_054,RightHand=R_wrist_J_055,LeftUpLeg=L_upper_leg_J_072,LeftLeg=L_knee_J_073,LeftFoot=L_ankle_J_074,LeftToeBase=L_feet_J_076,RightUpLeg=R_upper_leg_J_078,RightLeg=R_knee_J_079,RightFoot=R_ankle_J_080,RightToeBase=R_feet_J_082" \
	CLIPS="Walk=Walk Forward,Run=Run Forward" \
	OUT=res://assets/models/foes/unseen/unseen_moves.res \
	$G --headless --path . -s tools/bake_stranger_moves.gd | grep -E "PACE|SAVE"
