extends Node3D

## Rebuild after adding/moving room modules. Tagged floors determine the scan
## bounds; physics supplies the actual passages and furniture clearance.
@export var map_bounds := Rect2(-27.0, -6.0, 54.0, 12.0)
@export_range(0.25, 1.0) var cell_size := 0.5
@export var agent_radius := 0.5
@export var agent_height := 1.6
@export var floor_height := 0.0

var grid := AStarGrid2D.new()
var walkable_cells: Array[Vector2i] = []
var components: Dictionary = {}
var flee_cells: Array[Vector2i] = []
var _ready_for_routes := false
var _building := false
var _ignored_rids: Array[RID] = []
var _body_shape := CapsuleShape3D.new()
var _has_tagged_floors := false
const INVALID_CELL := Vector2i(-1000000, -1000000)
const NEIGHBORS: Array[Vector2i] = [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]


func _ready() -> void:
	initialize.call_deferred()


func initialize() -> void:
	if _building:
		return
	_building = true
	_ready_for_routes = false
	# Runtime room art/colliders are assembled during their parent's _ready.
	await get_tree().physics_frame
	await get_tree().physics_frame
	_rebuild()
	_building = false


func _rebuild() -> void:
	_derive_floor_bounds()
	_ignored_rids.clear()
	_collect_ignored_bodies(get_tree().current_scene)
	_body_shape.radius = agent_radius
	_body_shape.height = maxf(agent_height, agent_radius * 2.0)
	grid.region = Rect2i(Vector2i.ZERO, Vector2i(ceili(map_bounds.size.x / cell_size), ceili(map_bounds.size.y / cell_size)))
	grid.cell_size = Vector2.ONE * cell_size
	grid.offset = map_bounds.position + Vector2.ONE * cell_size * 0.5
	grid.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	grid.default_compute_heuristic = AStarGrid2D.HEURISTIC_OCTILE
	grid.default_estimate_heuristic = AStarGrid2D.HEURISTIC_OCTILE
	grid.update()
	walkable_cells.clear()
	components.clear()
	flee_cells.clear()
	for y in grid.region.size.y:
		for x in grid.region.size.x:
			var cell := Vector2i(x, y)
			var point := _world_point(cell)
			var clear := _has_floor(point) and _body_fits(point)
			grid.set_point_solid(cell, not clear)
			if clear:
				walkable_cells.append(cell)
	_build_components()
	for cell in walkable_cells:
		# Broad, evenly spaced destinations leave room to turn away from a rival.
		if cell.x % 6 == 0 and cell.y % 6 == 0:
			var open_around := true
			for offset in NEIGHBORS:
				open_around = open_around and _cell_is_open(cell + offset * 2)
			if open_around:
				flee_cells.append(cell)
	if flee_cells.is_empty():
		flee_cells.assign(walkable_cells)
	_ready_for_routes = not walkable_cells.is_empty()


func is_navigation_ready() -> bool:
	return _ready_for_routes


func find_path(from_world: Vector3, to_world: Vector3) -> PackedVector3Array:
	var route := PackedVector3Array()
	if not _ready_for_routes or not from_world.is_finite() or not to_world.is_finite():
		return route
	var start := _nearest_cell(from_world)
	var finish := _nearest_cell(to_world, components.get(start, -1))
	if start == INVALID_CELL or finish == INVALID_CELL:
		return route
	for point in grid.get_point_path(start, finish):
		route.append(Vector3(point.x, floor_height + 0.05, point.y))
	return route


func next_waypoint(from_world: Vector3, to_world: Vector3) -> Vector3:
	var route := find_path(from_world, to_world)
	if route.is_empty():
		return from_world
	# The final approach can follow a moving player without snapping them to a
	# cell center. Sweeping the full body keeps smoothing from clipping corners.
	var flat_goal := Vector3(to_world.x, floor_height + 0.05, to_world.z)
	if from_world.distance_to(flat_goal) < 3.0 and _has_floor(flat_goal) and _body_fits(flat_goal) and _can_travel(from_world, flat_goal):
		return flat_goal
	var next := route[0]
	for index in range(1, route.size()):
		if not _can_travel(from_world, route[index]):
			break
		next = route[index]
		if Vector2(next.x - from_world.x, next.z - from_world.z).length() > 2.2:
			break
	return next


func choose_flee_position(current: Vector3, opponent: Vector3) -> Vector3:
	if not _ready_for_routes:
		return current
	var component: int = components.get(_nearest_cell(current), -1)
	var best := current
	var best_score := -INF
	for cell in flee_cells:
		if components.get(cell, -2) != component:
			continue
		var point := _world_point(cell)
		var travel := current.distance_to(point)
		if travel < 2.5:
			continue
		var score := point.distance_to(opponent) - travel * 0.18
		if score > best_score:
			best_score = score
			best = point
	return best


func nearest_safe_position(desired: Vector3) -> Vector3:
	if not _ready_for_routes or not desired.is_finite():
		return Vector3(INF, INF, INF)
	var ground := Vector3(desired.x, floor_height + 0.05, desired.z)
	if _has_floor(ground) and _body_fits(ground):
		return ground
	var best := Vector3(INF, INF, INF)
	var best_distance := INF
	for cell in walkable_cells:
		var point := _world_point(cell)
		var distance := point.distance_squared_to(ground)
		if distance < best_distance and _body_fits(point):
			best = point
			best_distance = distance
	return best


func _derive_floor_bounds() -> void:
	var found := false
	for floor_node in get_tree().get_nodes_in_group("house_floor"):
		for child in floor_node.get_children():
			if not child is CollisionShape3D or not child.shape is BoxShape3D:
				continue
			var half: Vector3 = child.shape.size * 0.5
			for x in [-half.x, half.x]:
				for z in [-half.z, half.z]:
					var corner: Vector3 = child.global_transform * Vector3(x, 0.0, z)
					var point := Vector2(corner.x, corner.z)
					if not found:
						map_bounds = Rect2(point, Vector2.ZERO)
						found = true
					else:
						map_bounds = map_bounds.expand(point)
	_has_tagged_floors = found


func _collect_ignored_bodies(node: Node, temporary: bool = false) -> void:
	if node == null:
		return
	temporary = temporary or node.is_in_group("temporary_item")
	if node is CollisionObject3D and (node is CharacterBody3D or node is RigidBody3D or temporary):
		_ignored_rids.append(node.get_rid())
	for child in node.get_children():
		_collect_ignored_bodies(child, temporary)


func _has_floor(point: Vector3) -> bool:
	# Test the footprint as well as its center so exits cannot straddle an edge.
	for offset in [Vector3.ZERO, Vector3.LEFT * agent_radius, Vector3.RIGHT * agent_radius, Vector3.FORWARD * agent_radius, Vector3.BACK * agent_radius]:
		var origin: Vector3 = Vector3(point.x, floor_height + 0.15, point.z) + offset
		var query := PhysicsRayQueryParameters3D.create(origin, origin - Vector3.UP * 0.45, 3, _ignored_rids)
		var hit := get_world_3d().direct_space_state.intersect_ray(query)
		if hit.is_empty() or not hit.collider is StaticBody3D or hit.normal.y < 0.8:
			return false
		if _has_tagged_floors and not hit.collider.is_in_group("house_floor"):
			return false
	return true


func _body_query(point: Vector3) -> PhysicsShapeQueryParameters3D:
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = _body_shape
	query.collision_mask = 3
	query.exclude = _ignored_rids
	query.transform = Transform3D(Basis.IDENTITY, Vector3(point.x, floor_height + agent_height * 0.5 + 0.06, point.z))
	return query


func _body_fits(point: Vector3) -> bool:
	var query := _body_query(point)
	for hit in get_world_3d().direct_space_state.intersect_shape(query, 32):
		if hit.collider is StaticBody3D:
			return false
	return true


func _can_travel(start: Vector3, finish: Vector3) -> bool:
	var query := _body_query(start)
	query.motion = Vector3(finish.x - start.x, 0.0, finish.z - start.z)
	var result := get_world_3d().direct_space_state.cast_motion(query)
	return result[0] >= 0.999


func _world_point(cell: Vector2i) -> Vector3:
	var point := grid.get_point_position(cell)
	return Vector3(point.x, floor_height + 0.05, point.y)


func _cell_is_open(cell: Vector2i) -> bool:
	return grid.is_in_boundsv(cell) and not grid.is_point_solid(cell)


func _nearest_cell(point: Vector3, component: int = -1) -> Vector2i:
	var desired := Vector2(point.x, point.z)
	var rounded := Vector2i(((desired - grid.offset) / cell_size).round())
	if _cell_is_open(rounded) and (component < 0 or components.get(rounded, -2) == component):
		return rounded
	var best := INVALID_CELL
	var best_distance := INF
	for cell in walkable_cells:
		if component >= 0 and components.get(cell, -2) != component:
			continue
		var distance := grid.get_point_position(cell).distance_squared_to(desired)
		if distance < best_distance:
			best_distance = distance
			best = cell
	return best


func _build_components() -> void:
	var component := 0
	for seed_cell in walkable_cells:
		if components.has(seed_cell):
			continue
		var queue: Array[Vector2i] = [seed_cell]
		components[seed_cell] = component
		var index := 0
		while index < queue.size():
			var cell := queue[index]
			index += 1
			for offset in NEIGHBORS:
				var neighbor := cell + offset
				if _cell_is_open(neighbor) and not components.has(neighbor):
					components[neighbor] = component
					queue.append(neighbor)
		component += 1
