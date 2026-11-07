extends Node3D
## PlayerBodyMesh - full-body realistic operator mesh for protagonist ("Sigma-7").
## Uses the provided high-detail Tactical Soldier model.
## Head and sunglasses cast shadows only to avoid camera clipping when looking down.

func _ready() -> void:
	# Head accessories cast shadow only so they don't clip the first-person camera
	var head_names := [
		"Hat_LP2", "Glass_LP1", "CC_Base_Eye", "CC_Base_Teeth",
		"CC_Base_Tongue", "CC_Base_EyeOcclusion", "CC_Base_TearLine"
	]
	for node_name in head_names:
		var node := find_child(node_name, true, false) as GeometryInstance3D
		if node:
			node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY
