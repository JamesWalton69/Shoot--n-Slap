class_name ImpactFX
extends Node3D
## ImpactFX - dynamic particle bursts, spark emitters, shockwaves, and decals.
## Handles both ballistic bullet impacts and visceral comic-tactical melee slap impacts.

static func spawn_bullet_impact(parent: Node, hit_pos: Vector3, hit_normal: Vector3) -> void:
	if parent == null:
		return

	var root_node := Node3D.new()
	root_node.name = "BulletImpact"
	parent.add_child(root_node)
	root_node.global_position = hit_pos
	if hit_normal.length_squared() > 0.001 and not hit_normal.is_equal_approx(Vector3.UP):
		root_node.look_at(hit_pos + hit_normal, Vector3.UP)
	elif hit_normal.is_equal_approx(Vector3.UP):
		root_node.rotation_degrees = Vector3(-90, 0, 0)

	# 1. Quick point spark light
	var spark_light := OmniLight3D.new()
	spark_light.light_color = Color(1.0, 0.7, 0.3)
	spark_light.light_energy = 2.5
	spark_light.omni_range = 2.2
	root_node.add_child(spark_light)

	# 2. Spark particles
	var sparks := CPUParticles3D.new()
	sparks.emitting = true
	sparks.one_shot = true
	sparks.explosiveness = 1.0
	sparks.amount = 16
	sparks.lifetime = 0.28
	sparks.direction = Vector3(0, 0, 1)
	sparks.spread = 45.0
	sparks.initial_velocity_min = 4.0
	sparks.initial_velocity_max = 9.0
	sparks.gravity = Vector3(0, -9.8, 0)

	var spark_mesh := BoxMesh.new()
	spark_mesh.size = Vector3(0.02, 0.02, 0.06)
	var spark_mat := StandardMaterial3D.new()
	spark_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	spark_mat.albedo_color = Color(1.0, 0.85, 0.4)
	spark_mesh.material = spark_mat
	sparks.mesh = spark_mesh
	root_node.add_child(sparks)

	# 3. Dust puff particles
	var dust := CPUParticles3D.new()
	dust.emitting = true
	dust.one_shot = true
	dust.explosiveness = 0.9
	dust.amount = 10
	dust.lifetime = 0.45
	dust.direction = Vector3(0, 0, 1)
	dust.spread = 35.0
	dust.initial_velocity_min = 1.0
	dust.initial_velocity_max = 2.5
	dust.gravity = Vector3(0, 0.5, 0) # slow rise

	var dust_mesh := SphereMesh.new()
	dust_mesh.radius = 0.08
	dust_mesh.height = 0.16
	var dust_mat := StandardMaterial3D.new()
	dust_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	dust_mat.albedo_color = Color(0.65, 0.65, 0.65, 0.45)
	dust_mesh.material = dust_mat
	dust.mesh = dust_mesh
	root_node.add_child(dust)

	# Auto-clean after particles finish
	var tree := root_node.get_tree()
	if tree:
		tree.create_timer(0.6).timeout.connect(func():
			if is_instance_valid(root_node):
				root_node.queue_free()
		)
	else:
		root_node.queue_free()

static func spawn_slap_impact(parent: Node, hit_pos: Vector3, hit_normal: Vector3) -> void:
	if parent == null:
		return

	var root_node := Node3D.new()
	root_node.name = "SlapImpact"
	parent.add_child(root_node)
	root_node.global_position = hit_pos
	if hit_normal.length_squared() > 0.001 and not hit_normal.is_equal_approx(Vector3.UP):
		root_node.look_at(hit_pos + hit_normal, Vector3.UP)
	elif hit_normal.is_equal_approx(Vector3.UP):
		root_node.rotation_degrees = Vector3(-90, 0, 0)

	# 1. Kinetic flash light
	var slap_light := OmniLight3D.new()
	slap_light.light_color = Color(1.0, 0.95, 0.4)
	slap_light.light_energy = 3.5
	slap_light.omni_range = 3.0
	root_node.add_child(slap_light)

	# 2. Kinetic Shockwave Ring
	var ring_mesh_inst := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 0.02
	torus.outer_radius = 0.08
	ring_mesh_inst.mesh = torus

	var ring_mat := StandardMaterial3D.new()
	ring_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ring_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	ring_mat.albedo_color = Color(1.0, 0.9, 0.3, 0.9)
	ring_mesh_inst.material_override = ring_mat
	root_node.add_child(ring_mesh_inst)

	# Animate expanding ring
	var tween := root_node.create_tween().set_parallel(true)
	tween.tween_property(ring_mesh_inst, "scale", Vector3(5.0, 5.0, 5.0), 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(ring_mat, "albedo_color:a", 0.0, 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)

	# 3. Slap Starburst Particles
	var stars := CPUParticles3D.new()
	stars.emitting = true
	stars.one_shot = true
	stars.explosiveness = 1.0
	stars.amount = 24
	stars.lifetime = 0.35
	stars.direction = Vector3(0, 0, 1)
	stars.spread = 70.0
	stars.initial_velocity_min = 5.0
	stars.initial_velocity_max = 12.0
	stars.gravity = Vector3(0, -6.0, 0)

	var star_box := BoxMesh.new()
	star_box.size = Vector3(0.04, 0.04, 0.04)
	var star_mat := StandardMaterial3D.new()
	star_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	star_mat.albedo_color = Color(1.0, 1.0, 0.2)
	star_box.material = star_mat
	stars.mesh = star_box
	root_node.add_child(stars)

	# Auto-clean
	var tree := root_node.get_tree()
	if tree:
		tree.create_timer(0.5).timeout.connect(func():
			if is_instance_valid(root_node):
				root_node.queue_free()
		)
	else:
		root_node.queue_free()
