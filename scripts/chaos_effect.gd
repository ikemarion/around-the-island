extends Node3D

# The host simulates effects; clients only reconstruct their visible state.
var kind: StringName = &""
var owner_slot: int = 0
var target_slot: int = -1
var remaining: float = 5.0
var replica := false
var spent := false
var transfer_cooldown := 0.7
var direction := Vector3.FORWARD
var tint := Color.WHITE
var end_point := Vector3.ZERO
var decoy_body: CharacterBody3D
var rope: MeshInstance3D
var gust_rings: Array[MeshInstance3D] = []
var hot_potato_mesh: MeshInstance3D
var hot_potato_light: OmniLight3D
var hot_potato_hands: Array[MeshInstance3D] = []
var label: Label3D
var owner_player


func setup(effect_kind: StringName, source, target = null) -> void:
	kind = effect_kind
	owner_player = source
	owner_slot = source.player_index
	target_slot = target.player_index if target != null else -1
	direction = source._get_flat_aim_direction()
	tint = source.body_color
	remaining = 0.55 if kind == &"air_horn_gust" else (6.0 if kind == &"hot_potato" else (4.0 if kind == &"decoy_double" else 5.0))
	global_position = source.global_position
	if kind == &"pocket_wall":
		global_position -= direction * 1.8
		global_position.y = source.global_position.y
		rotation.y = atan2(direction.x, direction.z)
	_build_visuals()
	if is_instance_valid(decoy_body):
		for player in _players():
			decoy_body.add_collision_exception_with(player)
	if kind == &"magnet_mayhem":
		source._release_chair()
		source.magnet_effect = self
	if kind == &"air_horn_gust":
		global_position = source.global_position + Vector3.UP * 0.85 + direction * 0.55
		rotation.y = atan2(direction.x, direction.z)


func _ready() -> void:
	add_to_group("temporary_item")


func _mesh(mesh: Mesh, color: Color, parent: Node, offset := Vector3.ZERO) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.diffuse_mode = BaseMaterial3D.DIFFUSE_TOON
	material.roughness = 0.55
	instance.material_override = material
	parent.add_child(instance)
	instance.position = offset
	return instance


func _build_visuals() -> void:
	label = Label3D.new()
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.font_size = 40
	label.outline_size = 8
	add_child(label)
	label.position.y = 2.2
	match kind:
		&"decoy_double":
			add_to_group("chaos_decoy")
			decoy_body = CharacterBody3D.new()
			decoy_body.collision_layer = 0
			decoy_body.collision_mask = 3 if not replica else 0
			add_child(decoy_body)
			var capsule := CapsuleMesh.new()
			capsule.radius = 0.45
			capsule.height = 1.6
			_mesh(capsule, tint, decoy_body, Vector3.UP * 0.85)
			var shape := CollisionShape3D.new()
			var capsule_shape := CapsuleShape3D.new()
			capsule_shape.radius = 0.45
			capsule_shape.height = 1.6
			shape.shape = capsule_shape
			shape.position.y = 0.85
			decoy_body.add_child(shape)
			label.text = "P%d" % (owner_slot + 1)
		&"pocket_wall":
			var wall := StaticBody3D.new()
			# Static collision is needed by the joining player's movement prediction.
			wall.collision_layer = 1
			wall.collision_mask = 0
			add_child(wall)
			var box := preload("res://scripts/cartoon_geometry.gd").rounded_box(Vector3(2.8, 2.0, 0.3))
			_mesh(box, Color("488e85"), wall, Vector3.UP)
			for row in 3:
				for column in 4:
					var tile := preload("res://scripts/cartoon_geometry.gd").rounded_box(Vector3(0.62, 0.54, 0.035))
					for side in [-1, 1]:
						_mesh(tile, Color("fff0c4") if (row + column) % 2 == 0 else Color("e8b45c"), wall, Vector3(-1.02 + column * 0.68, 0.38 + row * 0.62, side * 0.16))
			var shape := CollisionShape3D.new()
			var box_shape := BoxShape3D.new()
			box_shape.size = Vector3(2.8, 2.0, 0.3)
			shape.shape = box_shape
			shape.position.y = 1.0
			wall.add_child(shape)
		&"magnet_mayhem":
			var ring := TorusMesh.new()
			ring.inner_radius = 0.8
			ring.outer_radius = 1.0
			_mesh(ring, Color("ff5dce"), self, Vector3.UP * 0.3)
		&"air_horn_gust":
			label.hide()
			for index in 3:
				var gust := TorusMesh.new()
				gust.inner_radius = 0.34
				gust.outer_radius = 0.42
				gust.rings = 24
				gust.ring_segments = 8
				var gust_ring := _mesh(gust, Color("d9fff4") if index % 2 == 0 else Color("fff0c4"), self)
				gust_ring.rotation.x = PI / 2.0
				gust_ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
				gust_rings.append(gust_ring)
		&"hot_potato":
			var ball := SphereMesh.new()
			ball.radius = 0.5
			ball.height = 1.0
			ball.radial_segments = 20
			ball.rings = 10
			hot_potato_mesh = _mesh(ball, Color("ff9a38"), self, Vector3(0, 0.72, 0.58))
			hot_potato_mesh.scale = Vector3(0.68, 0.54, 0.5)
			for spot in [Vector3(-0.16, 0.79, 0.83), Vector3(0.15, 0.63, 0.84), Vector3(0.12, 0.87, 0.81)]:
				var dimple := SphereMesh.new()
				dimple.radius = 0.5
				dimple.height = 1.0
				var dimple_mesh := _mesh(dimple, Color("713d35"), self, spot)
				dimple_mesh.scale = Vector3(0.07, 0.05, 0.035)
			for side in [-1.0, 1.0]:
				var hand := SphereMesh.new()
				hand.radius = 0.5
				hand.height = 1.0
				var hand_mesh := _mesh(hand, tint, self, Vector3(side * 0.31, 0.65, 0.59))
				hand_mesh.scale = Vector3(0.23, 0.27, 0.2)
				hot_potato_hands.append(hand_mesh)
			hot_potato_light = OmniLight3D.new()
			hot_potato_light.light_color = Color("ff352d")
			hot_potato_light.light_energy = 0.0
			hot_potato_light.omni_range = 1.5
			hot_potato_light.shadow_enabled = false
			add_child(hot_potato_light)
			hot_potato_light.position = Vector3(0, 0.75, 0.62)
			label.position = Vector3(0, 1.85, 0.1)
		&"bungee_hook":
			var cable := CylinderMesh.new()
			cable.top_radius = 0.045
			cable.bottom_radius = 0.045
			cable.height = 1.0
			rope = _mesh(cable, Color("ffe566"), self)


func _players() -> Array:
	return get_tree().current_scene.players


func _active(slot: int) -> bool:
	return slot >= 0 and slot < _players().size() and get_tree().current_scene.active_slots[slot]


func _physics_process(delta: float) -> void:
	if replica or spent or kind == &"":
		return
	remaining -= delta
	if kind != &"hot_potato" and not _active(owner_slot):
		queue_free()
		return
	var source = _players()[owner_slot]
	match kind:
		&"decoy_double":
			decoy_body.velocity.x = direction.x * 6.2
			decoy_body.velocity.z = direction.z * 6.2
			decoy_body.velocity.y -= 20.0 * delta
			decoy_body.move_and_slide()
			var next_position := decoy_body.global_position
			global_position = next_position
			decoy_body.position = Vector3.ZERO
			if global_position.y < -3.0:
				remaining = 0.0
		&"magnet_mayhem":
			if not _active(target_slot):
				_finish_magnet()
				return
			global_position = _players()[target_slot].global_position
			for chair in get_tree().get_nodes_in_group("shoveable"):
				var offset: Vector3 = global_position + Vector3.UP * 0.7 - chair.global_position
				if offset.length() < 7.5 and offset.length() > 0.8:
					chair.sleeping = false
					chair.apply_central_force(offset.normalized() * 70.0)
		&"hot_potato":
			if not _active(target_slot):
				queue_free()
				return
			var carrier = _players()[target_slot]
			global_position = carrier.global_position
			rotation.y = carrier.body_mesh.rotation.y
			transfer_cooldown -= delta
			if transfer_cooldown <= 0.0:
				for slot in _players().size():
					if slot != target_slot and _active(slot) and global_position.distance_to(_players()[slot].global_position) < 1.25 and get_tree().current_scene.can_touch_players(target_slot, slot):
						target_slot = slot
						transfer_cooldown = 0.7
						global_position = _players()[slot].global_position
						break
		&"bungee_hook":
			if not _active(target_slot):
				queue_free()
				return
			var target = _players()[target_slot]
			global_position = source.global_position + Vector3.UP
			end_point = target.global_position + Vector3.UP
			var offset: Vector3 = end_point - global_position
			var distance := offset.length()
			if distance > 18.0 or source.global_position.y < -2.0 or target.global_position.y < -2.0:
				remaining = 0.0
			elif distance > 3.0:
				var pull := offset.normalized() * minf((distance - 3.0) * 12.0, 45.0) * delta
				source.apply_knockback(pull)
				target.apply_knockback(-pull)
	_update_visuals()
	if remaining <= 0.0:
		if kind == &"magnet_mayhem":
			_finish_magnet()
		elif kind == &"hot_potato":
			_explode()
		else:
			queue_free()


func _finish_magnet() -> void:
	if spent or replica:
		return
	spent = true
	if is_instance_valid(owner_player):
		owner_player.magnet_effect = null
	queue_free()


func _explode() -> void:
	spent = true
	for slot in _players().size():
		if not _active(slot):
			continue
		var player = _players()[slot]
		var away: Vector3 = player.global_position - global_position
		if away.length() < 4.0:
			player.apply_knockback((away.normalized() + Vector3.UP * 0.7).normalized() * 30.0)
	if _active(target_slot):
		_players()[target_slot]._play_sfx("air_horn")
	queue_free()


func _update_visuals() -> void:
	if kind != &"decoy_double" and kind != &"air_horn_gust":
		label.text = "%s %.1fs" % [String(kind).replace("_", " ").to_upper(), maxf(remaining, 0.0)]
	if kind == &"magnet_mayhem" and target_slot >= 0:
		label.text = "P%d MAGNETIZED %.1fs" % [target_slot + 1, maxf(remaining, 0.0)]
	if kind == &"hot_potato":
		_update_hot_potato_visual()
	if not gust_rings.is_empty():
		var progress := clampf(1.0 - remaining / 0.55, 0.0, 1.0)
		for index in gust_rings.size():
			var ring := gust_rings[index]
			var stagger := float(index) * 0.22
			var ring_progress := clampf((progress - stagger) / (1.0 - stagger), 0.0, 1.0)
			ring.position = Vector3(0, 0, 0.25 + float(index) * 0.48 + ring_progress * 2.4)
			ring.scale = Vector3.ONE * (0.5 + ring_progress * (1.15 + float(index) * 0.18))
			ring.transparency = ring_progress
	if is_instance_valid(rope):
		var offset := end_point - global_position
		rope.position = offset * 0.5
		rope.scale.y = maxf(offset.length(), 0.01)
		if offset.length() > 0.01:
			var up := offset.normalized()
			var right := up.cross(Vector3.FORWARD)
			if right.length() < 0.01:
				right = up.cross(Vector3.RIGHT)
			right = right.normalized()
			rope.basis = Basis(right, up * offset.length(), right.cross(up))


func _update_hot_potato_visual() -> void:
	if not is_instance_valid(hot_potato_mesh):
		return
	var heat := clampf(1.0 - remaining / 6.0, 0.0, 1.0)
	var elapsed := 6.0 - remaining
	var pulse := (sin(elapsed * lerpf(3.0, 18.0, heat)) + 1.0) * 0.5
	var potato_color := Color("ff9a38").lerp(Color("c91124"), heat)
	var potato_material := hot_potato_mesh.material_override as StandardMaterial3D
	potato_material.albedo_color = potato_color
	potato_material.emission_enabled = true
	potato_material.emission = Color("ff1018")
	potato_material.emission_energy_multiplier = 0.05 + heat * 0.85 + pulse * heat * 0.75
	hot_potato_mesh.scale = Vector3(0.68, 0.54, 0.5) * (1.0 + pulse * heat * 0.08)
	if is_instance_valid(hot_potato_light):
		hot_potato_light.light_energy = heat * 0.8 + pulse * heat * 1.5
		hot_potato_light.omni_range = 1.5 + heat * 2.6
	if _active(target_slot):
		var hand_color: Color = _players()[target_slot].body_color
		for hand in hot_potato_hands:
			(hand.material_override as StandardMaterial3D).albedo_color = hand_color


func network_state() -> Dictionary:
	return {"effect": kind, "owner": owner_slot, "target": target_slot, "time": remaining, "tint": tint, "end": end_point, "rotation": rotation}


func apply_state(state: Dictionary) -> void:
	replica = true
	owner_slot = state.owner
	target_slot = state.target
	remaining = state.time
	tint = state.tint
	end_point = state.end
	rotation = state.rotation
	if kind == &"":
		kind = state.effect
		_build_visuals()
	_update_visuals()
