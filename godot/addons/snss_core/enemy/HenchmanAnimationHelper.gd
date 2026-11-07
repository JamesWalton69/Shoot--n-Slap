class_name HenchmanAnimationHelper
extends RefCounted
## HenchmanAnimationHelper - retargets Mixamo animation tracks onto Tactical Soldier CC skeleton.
## Caches the retargeted AnimationLibrary so all henchmen share it with zero duplicate memory.

static var _cached_library: AnimationLibrary = null

const BONE_MAP: Dictionary = {
	"mixamorig_Hips": "CC_Base_Pelvis",
	"mixamorig_Spine": "CC_Base_Waist",
	"mixamorig_Spine1": "CC_Base_Spine01",
	"mixamorig_Spine2": "CC_Base_Spine02",
	"mixamorig_Neck": "CC_Base_NeckTwist01",
	"mixamorig_Head": "CC_Base_Head",
	"mixamorig_LeftShoulder": "CC_Base_L_Clavicle",
	"mixamorig_LeftArm": "CC_Base_L_Upperarm",
	"mixamorig_LeftForeArm": "CC_Base_L_Forearm",
	"mixamorig_LeftHand": "CC_Base_L_Hand",
	"mixamorig_RightShoulder": "CC_Base_R_Clavicle",
	"mixamorig_RightArm": "CC_Base_R_Upperarm",
	"mixamorig_RightForeArm": "CC_Base_R_Forearm",
	"mixamorig_RightHand": "CC_Base_R_Hand",
	"mixamorig_LeftUpLeg": "CC_Base_L_Thigh",
	"mixamorig_LeftLeg": "CC_Base_L_Calf",
	"mixamorig_LeftFoot": "CC_Base_L_Foot",
	"mixamorig_LeftToeBase": "CC_Base_L_ToeBase",
	"mixamorig_RightUpLeg": "CC_Base_R_Thigh",
	"mixamorig_RightLeg": "CC_Base_R_Calf",
	"mixamorig_RightFoot": "CC_Base_R_Foot",
	"mixamorig_RightToeBase": "CC_Base_R_ToeBase"
}

static func get_animation_library() -> AnimationLibrary:
	if _cached_library != null:
		return _cached_library

	var lib := AnimationLibrary.new()

	_load_and_retarget(lib, "walk", "res://assets/animations/pistol_walk.fbx", Animation.LOOP_LINEAR)
	_load_and_retarget(lib, "idle", "res://assets/animations/pistol_idle.fbx", Animation.LOOP_LINEAR)
	_load_and_retarget(lib, "hit", "res://assets/animations/hit_reaction.fbx", Animation.LOOP_NONE)
	_load_and_retarget(lib, "death", "res://assets/animations/Falling_Back_Death.fbx", Animation.LOOP_NONE)

	_cached_library = lib
	return _cached_library

static func _load_and_retarget(lib: AnimationLibrary, anim_name: String, path: String, loop_mode: Animation.LoopMode) -> void:
	var clip_scene := load(path) as PackedScene
	if not clip_scene:
		return

	var clip_inst := clip_scene.instantiate()
	var clip_player: AnimationPlayer = null
	for child in clip_inst.get_children():
		if child is AnimationPlayer:
			clip_player = child
			break

	if not clip_player:
		clip_inst.free()
		return

	var src_anim_name := "mixamo_com"
	if not clip_player.has_animation(src_anim_name):
		var list := clip_player.get_animation_list()
		if list.size() > 0:
			src_anim_name = list[0]

	if not clip_player.has_animation(src_anim_name):
		clip_inst.free()
		return

	var src_anim := clip_player.get_animation(src_anim_name)
	var retargeted := Animation.new()
	retargeted.length = src_anim.length
	retargeted.loop_mode = loop_mode

	for t in range(src_anim.get_track_count()):
		var track_path := String(src_anim.track_get_path(t))
		var parts := track_path.split(":")
		if parts.size() == 2:
			var prefix := parts[0]
			var bone := parts[1]
			if BONE_MAP.has(bone):
				var new_bone: String = BONE_MAP[bone]
				var new_path := "%s:%s" % [prefix, new_bone]
				var new_idx := retargeted.add_track(src_anim.track_get_type(t))
				retargeted.track_set_path(new_idx, NodePath(new_path))
				retargeted.track_set_interpolation_type(new_idx, src_anim.track_get_interpolation_type(t))

				for k in range(src_anim.track_get_key_count(t)):
					var time := src_anim.track_get_key_time(t, k)
					var val = src_anim.track_get_key_value(t, k)
					var trans := src_anim.track_get_key_transition(t, k)
					if src_anim.track_get_type(t) == Animation.TYPE_POSITION_3D and bone == "mixamorig_Hips":
						if val is Vector3:
							val = Vector3(val.x * 0.01, val.y * 0.01 + 0.95, val.z * 0.01)
					retargeted.track_insert_key(new_idx, time, val, trans)

	lib.add_animation(anim_name, retargeted)
	clip_inst.free()
