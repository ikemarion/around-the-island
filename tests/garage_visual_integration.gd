extends SceneTree
## The garage art can change freely; its gameplay shell and wire IDs cannot.
## Run directly or through tools/run_tests.ps1 -Test garage_visual_integration.

const ROOM = preload("res://scenes/rooms/garage.tscn")
const MAX_MESH_INSTANCES := 600
const MAX_TRIANGLES := 350000
const PROP_SPAWNS := {
	"GarageTire": Vector3(-4.0, 0.55, 1.4),
	"GarageToolbox": Vector3(3.8, 0.55, -1.5),
	"GaragePaintCan": Vector3(-5.4, 0.55, -1.8),
	"GarageToolCart": Vector3(4.9, 0.55, 4.65),
}
const STATIC_BODIES := {
	"Floor": [Vector3(18, 0.2, 12), Vector3(0, -0.1, 0)],
	"NorthWall": [Vector3(18, 0.7, 0.35), Vector3(0, 0.35, -6)],
	"SouthWall": [Vector3(18, 0.7, 0.35), Vector3(0, 0.35, 6)],
	"OuterWall": [Vector3(0.35, 0.7, 12), Vector3(-8.85, 0.35, 0)],
	"Divider0": [Vector3(0.3, 2.3, 1), Vector3(8.85, 1.15, -5.5)],
	"Divider1": [Vector3(0.3, 2.3, 4), Vector3(8.85, 1.15, 0)],
	"Divider2": [Vector3(0.3, 2.3, 1), Vector3(8.85, 1.15, 5.5)],
	"Doorway1/Header": [Vector3(0.42, 0.22, 3.22), Vector3(0, 2.51, 0)],
	"Doorway2/Header": [Vector3(0.42, 0.22, 3.22), Vector3(0, 2.51, 0)],
	"ProjectCar": [Vector3(5.4, 1.65, 2.55), Vector3(0, 0.825, 0)],
	"Workbench": [Vector3(5.5, 1.0, 1.1), Vector3(0, 0.5, -5.15)],
	"ToolBoard": [Vector3(5.6, 1.55, 0.18), Vector3(0, 1.91, -5.65)],
	"GarageShutter": [Vector3(0.15, 2.9, 4.0), Vector3(-8.72, 1.45, 0)],
}
var failures := 0


func _initialize() -> void:
	call_deferred("run")


func check(value: bool, message: String) -> void:
	if not value:
		failures += 1
		push_error(message)


func freeze_props(room: Node) -> void:
	for body in room.find_children("*", "RigidBody3D", true, false):
		body.freeze = true


func check_layout(room: Node3D) -> void:
	var geometry := room.get_node("Geometry")
	var bodies := geometry.find_children("*", "StaticBody3D", true, false)
	check(bodies.size() == STATIC_BODIES.size(), "Garage art added an unreviewed static blocker")
	for body_path in STATIC_BODIES:
		var body := geometry.get_node_or_null(body_path) as StaticBody3D
		check(body != null, "Missing garage gameplay body: " + body_path)
		if body == null:
			continue
		var collision := body.get_node_or_null("CollisionShape3D") as CollisionShape3D
		check(collision != null and collision.shape is BoxShape3D, "Garage body lost its stable box collider: " + body_path)
		if collision != null and collision.shape is BoxShape3D:
			check(collision.shape.size.is_equal_approx(STATIC_BODIES[body_path][0]), "Garage collider size changed: " + body_path)
			check(collision.position.is_zero_approx() and not collision.disabled, "Garage collider became offset/disabled: " + body_path)
		check(body.position.is_equal_approx(STATIC_BODIES[body_path][1]), "Garage obstacle moved: " + body_path)
		check(body.collision_layer == 1, "Garage static collision layer changed: " + body_path)
	check(geometry.find_children("*", "CollisionShape3D", true, false).size() == STATIC_BODIES.size() + PROP_SPAWNS.size(), "Decorative garage art must not add collision shapes")
	var props := geometry.find_children("*", "RigidBody3D", true, false)
	check(props.size() == PROP_SPAWNS.size(), "Garage movable-prop count changed")
	for prop_name in PROP_SPAWNS:
		var prop := geometry.get_node_or_null(prop_name) as RigidBody3D
		check(prop != null, "Garage wire ID changed: " + prop_name)
		if prop == null:
			continue
		check(prop.position.is_equal_approx(PROP_SPAWNS[prop_name]), "Garage prop initial position changed: " + prop_name)
		check(prop.is_in_group("shoveable"), "Garage prop no longer participates in snapshots: " + prop_name)
		check(is_equal_approx(prop.mass, 0.9) and is_equal_approx(prop.linear_damp, 3.2), "Art changed garage prop handling: " + prop_name)
		check(prop.has_node("CartoonProp") and prop.get_node("CartoonProp").get_child_count() > 0, "Garage prop lost themed art: " + prop_name)
		var shape := prop.get_node("CollisionShape3D").shape as BoxShape3D
		check(shape != null and shape.size.is_equal_approx(Vector3.ONE * 0.9), "Garage prop collision changed: " + prop_name)
	var markers := room.get_node("PickupSpawns")
	check(markers.get_child_count() == 4, "Garage must retain all four pickup locations")
	var expected := [Vector3(-5.8, 0, -3.5), Vector3(5.8, 0, -3.5), Vector3(-5.8, 0, 3.5), Vector3(5.8, 0, 3.5)]
	for index in mini(markers.get_child_count(), expected.size()):
		var marker := markers.get_child(index)
		check(marker is Marker3D and marker.position.is_equal_approx(expected[index]), "Garage pickup marker moved or changed type")
	for path in ["Doorway1", "Doorway2"]:
		check(geometry.get_node(path).find_children("*", "Label3D", true, false).is_empty(), "Doorway instruction labels must remain removed")
	for node in room.find_children("*", "Node", true, false):
		check(node.owner == null, "Generated garage preview geometry must remain unsaved: " + str(node.name))


func check_workshop_art(room: Node3D) -> void:
	var geometry := room.get_node("Geometry")
	var roots := ["FloorArt", "GarageBoundaryArt", "Workbench/WorkbenchArt", "ToolBoard/ToolBoardArt", "GarageShutter/GarageDoorArt"]
	for path in roots:
		var art := geometry.get_node_or_null(path)
		check(art != null, "Garage workshop art kit is missing: " + path)
		if art == null:
			continue
		check(art.find_children("*", "MeshInstance3D", true, false).size() > 0, "Garage art kit has no drawable geometry: " + path)
		check(art.find_children("*", "CollisionObject3D", true, false).is_empty(), "Garage art kit must remain visual-only: " + path)
		check(art.find_children("MaterialBatch*", "MeshInstance3D", true, false).size() > 0, "Garage static details lost material batching: " + path)
	# Batch compilation keeps named anchors, making design regressions detectable
	# without freezing the exact triangle count or implementation of each piece.
	var landmarks := [
		"FloorArt/ServiceMat", "FloorArt/ParkingCorner-1_-1",
		"GarageBoundaryArt/EndWallCap", "GarageBoundaryArt/DividerPlaster1",
		"Workbench/WorkbenchArt/ButcherBlockTop", "Workbench/WorkbenchArt/BenchVise/Spindle",
		"Workbench/WorkbenchArt/BenchVise/Jaw-1", "Workbench/WorkbenchArt/BenchVise/Jaw1",
		"Workbench/WorkbenchArt/BrushPot", "Workbench/WorkbenchArt/FoldedShopCloth",
		"ToolBoard/ToolBoardArt/PerforatedPanel", "ToolBoard/ToolBoardArt/AccessoryLedge",
		"GarageShutter/GarageDoorArt/RubberSweep", "GarageShutter/GarageDoorArt/DoorLiftHandle",
		"GarageTire/CartoonProp/SculptedRubber", "GarageTire/CartoonProp/ChevronTread",
		"GarageToolbox/CartoonProp/EnamelBody", "GarageToolbox/CartoonProp/RecessedCarryGrip",
		"GaragePaintCan/CartoonProp/DrippyPaintLabel", "GaragePaintCan/CartoonProp/WireBail",
		"GarageToolCart/CartoonProp/EnamelCabinet", "GarageToolCart/CartoonProp/SidePushGrip",
	]
	for path in landmarks:
		check(geometry.has_node(path), "Missing garage design landmark: " + path)
	for index in 4:
		check(geometry.has_node("Workbench/WorkbenchArt/Cabinet%d" % index), "Workbench lost a cabinet module")
		check(geometry.has_node("GarageShutter/GarageDoorArt/WindowGlass%d" % index), "Garage door lost a glazed window")
	for index in 5:
		check(geometry.has_node("ToolBoard/ToolBoardArt/HangingTool%d" % index), "Pegboard lost a distinct tool")
		check(geometry.has_node("GarageShutter/GarageDoorArt/Section%d" % index), "Garage shutter lost a door section")
	for path in ["Floor/MeshInstance3D", "Workbench/WorkbenchArt/ButcherBlockTop", "ToolBoard/ToolBoardArt/PerforatedPanel"]:
		var part := geometry.get_node_or_null(path) as MeshInstance3D
		check(part != null and part.material_override is ShaderMaterial, "Garage texture language lost its authored material: " + path)
	for prop_name in PROP_SPAWNS:
		var prop := geometry.get_node_or_null(prop_name) as Node3D
		if prop == null:
			continue
		for part in prop.get_node("CartoonProp").find_children("*", "MeshInstance3D", true, false):
			if part.mesh == null:
				continue
			var relative: Transform3D = prop.global_transform.affine_inverse() * part.global_transform
			var bounds: AABB = relative * part.mesh.get_aabb()
			check(bounds.position.x >= -0.52 and bounds.end.x <= 0.52 and bounds.position.y >= -0.52 and bounds.end.y <= 0.52 and bounds.position.z >= -0.52 and bounds.end.z <= 0.52, "Garage movable art is oversized for its grab/collision footprint: " + str(part.get_path()))


func visual_signature(node: Node) -> Array:
	# Godot assigns global instance numbers to duplicate sibling names. Compare
	# their stable child index/class instead, keeping explicit names where stable.
	var rows: Array = []
	for child in node.get_children():
		# Runtime shoveable._ready adds an empty hidden prompt at a different
		# moment than editor rebuild; it is not part of generated room art.
		if child is Label3D and child.text.is_empty() and not child.visible:
			continue
		var title := str(child.name)
		if title.begins_with("@") or (title.begins_with("_MeshInstance3D_") and title.trim_prefix("_MeshInstance3D_").is_valid_int()):
			title = child.get_class()
		var row: Array = [title, child.get_class()]
		if child is Node3D:
			row.append(child.transform)
		if child is MeshInstance3D:
			row.append(child.visible)
			if child.mesh != null:
				row.append(child.mesh.get_aabb())
				for surface_index in child.mesh.get_surface_count():
					var arrays: Array = child.mesh.surface_get_arrays(surface_index)
					row.append(hash(arrays[Mesh.ARRAY_VERTEX]))
					row.append(hash(arrays[Mesh.ARRAY_NORMAL]))
					row.append(hash(arrays[Mesh.ARRAY_TEX_UV]))
					row.append(hash(arrays[Mesh.ARRAY_INDEX]))
			var material: Material = child.material_override
			if material is StandardMaterial3D:
				row.append([material.albedo_color, material.roughness, material.metallic, material.emission_enabled, material.emission])
			elif material is ShaderMaterial and material.shader != null:
				row.append(material.shader.code)
				for uniform in material.shader.get_shader_uniform_list():
					var value: Variant = material.get_shader_parameter(uniform.name)
					# File-backed textures use their stable path, not the unique
					# resource instance assigned on this particular build.
					row.append([uniform.name, value.resource_path if value is Resource else value])
		row.append(visual_signature(child))
		rows.append(row)
	return rows


func check_visual_budget(room: Node3D) -> void:
	var meshes := room.find_children("*", "MeshInstance3D", true, false)
	var triangles := 0
	var visible_meshes := 0
	for part in meshes:
		if part.mesh == null:
			check(not part.visible, "Visible garage mesh has no geometry: " + str(part.get_path()))
			continue
		check(part.transform.is_finite() and part.mesh.get_aabb().position.is_finite() and part.mesh.get_aabb().size.is_finite(), "Garage mesh contains non-finite geometry")
		if part.visible:
			visible_meshes += 1
		for surface_index in part.mesh.get_surface_count():
			var arrays: Array = part.mesh.surface_get_arrays(surface_index)
			var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
			var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			triangles += (indices.size() if not indices.is_empty() else vertices.size()) / 3
	check(visible_meshes <= MAX_MESH_INSTANCES, "Garage exceeded its drawable-node guardrail: " + str(visible_meshes))
	check(triangles <= MAX_TRIANGLES, "Garage exceeded its geometric guardrail: " + str(triangles))
	print("GARAGE_VISUAL_BUDGET meshes=", visible_meshes, " triangles=", triangles)


func signature_difference(left: Array, right: Array, at: String = "root") -> String:
	if left.size() != right.size():
		return at + ": different item counts " + str(left.size()) + "/" + str(right.size())
	for index in left.size():
		if left[index] == right[index]:
			continue
		var location := at + "/" + str(index)
		if left[index] is Array and right[index] is Array:
			return signature_difference(left[index], right[index], location)
		return location + ": " + str(left[index]) + " vs " + str(right[index])
	return ""


func run() -> void:
	var room := ROOM.instantiate() as Node3D
	root.add_child(room)
	freeze_props(room)
	check_layout(room)
	check_workshop_art(room)
	check_visual_budget(room)
	var original := visual_signature(room)
	var second := ROOM.instantiate() as Node3D
	root.add_child(second)
	freeze_props(second)
	check(original == visual_signature(second), "Garage differs between independent loads; art must be deterministic: " + signature_difference(original, visual_signature(second)))
	second.queue_free()
	await process_frame
	room._rebuild_preview()
	freeze_props(room)
	check(original == visual_signature(room), "Editor rebuild changed garage geometry or duplicated generated children: " + signature_difference(original, visual_signature(room)))
	check_layout(room)
	check_workshop_art(room)
	room.queue_free()
	await process_frame
	# A module must also render correctly if a later house layout places its
	# entrance on the opposite side or rotates/moves the whole room instance.
	var annex = ROOM.instantiate()
	annex.entrance_side = "west"
	annex.room_id = "Annex"
	annex.position = Vector3(42, 0, -18)
	annex.rotation.y = PI / 2.0
	root.add_child(annex)
	freeze_props(annex)
	var annex_geometry := annex.get_node("Geometry")
	check(annex_geometry.get_node("Doorway1").position.is_equal_approx(Vector3(-8.85, 0, -3.5)), "Mirrored garage entrance did not move with module configuration")
	check(annex_geometry.get_node("GarageShutter").position.is_equal_approx(Vector3(8.72, 1.45, 0)), "Mirrored garage shutter moved into the wrong wall")
	check(is_equal_approx(annex_geometry.get_node("GarageShutter/GarageDoorArt").rotation.y, -PI / 2.0), "Mirrored garage door art faces outside the arena")
	for prop_name in PROP_SPAWNS:
		check(annex_geometry.has_node(str(prop_name).replace("Garage", "Annex")), "Garage module ignored its unique network-ID prefix")
	for marker in annex.get_node("PickupSpawns").get_children():
		check(marker.global_position.is_equal_approx(annex.to_global(marker.position)), "Rotated garage pickup marker lost its local-space placement")
	annex.queue_free()
	await process_frame

	var main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	current_scene = main
	main._start_solo()
	main.set_process(false)
	main.set_physics_process(false)
	main.camera.set_process(false)
	main.camera.set_physics_process(false)
	for player in main.players:
		player.set_physics_process(false)
	for prop in main._sorted_obstacles():
		prop.freeze = true
	var garage := main.get_node("Arena/Rooms/Garage") as Node3D
	check_layout(garage)
	check_workshop_art(garage)
	var props_by_name: Dictionary = {}
	for prop in main._sorted_obstacles():
		check(not props_by_name.has(str(prop.name)), "Duplicate prop wire ID in expanded house: " + str(prop.name))
		props_by_name[str(prop.name)] = prop
	check(props_by_name.size() == 12, "Visual-only update changed the twelve replicated house obstacles")
	main.session_mode = &"client"
	main.world_sequences.clear()
	for prop_name in PROP_SPAWNS:
		if not props_by_name.has(prop_name):
			check(false, "Garage obstacle missing from network registry: " + prop_name)
			continue
		var prop: Node3D = props_by_name[prop_name]
		var target := prop.global_transform
		target.origin += Vector3(0.2, 0.4, 0.1)
		main._receive_obstacle_state({"name": prop_name, "transform": target, "linear": Vector3.ZERO, "angular": Vector3.ZERO, "holder": -1}, main.round_epoch, 1)
		check(prop.global_transform.is_equal_approx(target), "Garage snapshot no longer resolves wire ID: " + prop_name)
	main._start_solo()
	main.set_process(false)
	main.set_physics_process(false)
	for prop in main._sorted_obstacles():
		prop.freeze = true
	main.reset_round()
	for prop_name in PROP_SPAWNS:
		if props_by_name.has(prop_name):
			var prop: Node3D = props_by_name[prop_name]
			check(main.obstacle_spawn_transforms.has(prop) and prop.global_transform.is_equal_approx(main.obstacle_spawn_transforms[prop]), "Garage art broke round reset: " + prop_name)
	main._prepare_session()
	main.queue_free()
	await process_frame
	print("GARAGE_VISUAL_INTEGRATION failures=", failures)
	quit(1 if failures else 0)
