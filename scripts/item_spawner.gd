class_name ATIItemSpawner
extends Node3D

const STUN_GUN_PICKUP := preload("res://scenes/stun_gun_pickup.tscn")
const GENERIC_PICKUP := preload("res://scenes/generic_powerup_pickup.tscn")
const ITEM_POOL: Array[StringName] = [
	&"stun_gun",
	&"air_horn",
	&"swap_bell",
	&"invisibility",
	&"rewind_watch",
	&"emergency_door",
	&"decoy_double",
	&"magnet_mayhem",
	&"pocket_wall",
	&"hot_potato",
	&"bungee_hook",
]
const ITEM_NAMES := {
	&"stun_gun": "STUN GUN",
	&"air_horn": "AIR HORN",
	&"swap_bell": "SWAP BELL",
	&"invisibility": "INVISIBILITY",
	&"rewind_watch": "REWIND WATCH",
	&"emergency_door": "EMERGENCY DOOR",
	&"decoy_double": "DECOY DOUBLE",
	&"magnet_mayhem": "MAGNET MAYHEM",
	&"pocket_wall": "POCKET WALL",
	&"hot_potato": "HOT POTATO",
	&"bungee_hook": "BUNGEE HOOK",
}
const ITEM_COLORS := {
	&"stun_gun": Color("ffe56b"),
	&"air_horn": Color("ff8a45"),
	&"swap_bell": Color("57d6ff"),
	&"invisibility": Color("a78bfa"),
	&"rewind_watch": Color("cd78ff"),
	&"emergency_door": Color("62fff0"),
	&"decoy_double": Color("70c9ff"),
	&"magnet_mayhem": Color("ff5dce"),
	&"pocket_wall": Color("55b5ed"),
	&"hot_potato": Color("ff6938"),
	&"bungee_hook": Color("ffe566"),
}

@export var respawn_delay: float = 10.0
@export var spawn_locations: Array[Vector3] = [
	Vector3(-6.5, 0.0, -4.15),
	Vector3(6.5, 0.0, -4.15),
	Vector3(6.5, 0.0, 4.15),
	Vector3(-6.5, 0.0, 4.15),
]

@onready var respawn_timer: Timer = $RespawnTimer
@onready var status_label: Label3D = $Status

# Kept dynamically typed so this reusable spawner also works before Godot has
# refreshed its global class-name cache in a brand-new checkout.
var active_pickup
var last_location_index: int = -1
var remote_item_type: StringName = &""
var authority_enabled := true

func set_authoritative(value: bool) -> void:
	authority_enabled = value
	respawn_timer.stop()
	set_process(value)
	if is_instance_valid(active_pickup):
		active_pickup.queue_free()
	active_pickup = null
	remote_item_type = &""


func _ready() -> void:
	respawn_timer.timeout.connect(_spawn_pickup)
	_spawn_pickup()


func reset_spawner() -> void:
	respawn_timer.stop()
	if is_instance_valid(active_pickup):
		active_pickup.queue_free()
	active_pickup = null
	call_deferred("_spawn_pickup")


func _spawn_pickup() -> void:
	if not authority_enabled:
		return
	if is_instance_valid(active_pickup):
		return
	_move_to_random_location()
	var item_type := _draw_random_item()
	active_pickup = (STUN_GUN_PICKUP if item_type == &"stun_gun" else GENERIC_PICKUP).instantiate()
	add_child(active_pickup)
	active_pickup.configure(item_type, ITEM_COLORS[item_type])
	active_pickup.collected.connect(_on_pickup_collected)
	status_label.text = ITEM_NAMES[item_type]
	status_label.modulate = ITEM_COLORS[item_type]


func _draw_random_item() -> StringName:
	return ITEM_POOL[randi_range(0, ITEM_POOL.size() - 1)]


func _move_to_random_location() -> void:
	if spawn_locations.is_empty():
		return
	var location_index := randi_range(0, spawn_locations.size() - 1)
	if spawn_locations.size() > 1 and location_index == last_location_index:
		location_index = (location_index + randi_range(1, spawn_locations.size() - 1)) % spawn_locations.size()
	last_location_index = location_index
	global_position = spawn_locations[location_index]


func _on_pickup_collected() -> void:
	active_pickup = null
	status_label.text = "NEW ITEM  %.0fs" % respawn_delay
	status_label.modulate = Color(0.55, 0.6, 0.66)
	respawn_timer.start(respawn_delay)


func _process(_delta: float) -> void:
	if respawn_timer.time_left > 0.0:
		status_label.text = "NEW ITEM  %.0fs" % ceilf(respawn_timer.time_left)


func get_network_state() -> Dictionary:
	return {
		"position": global_position,
		"available": is_instance_valid(active_pickup),
		"item_type": active_pickup.item_type if is_instance_valid(active_pickup) else &"",
		"time_left": respawn_timer.time_left,
	}


func apply_network_state(state: Dictionary) -> void:
	global_position = state.position
	var wanted_type: StringName = state.item_type
	if not state.available:
		if is_instance_valid(active_pickup):
			active_pickup.queue_free()
		active_pickup = null
		remote_item_type = &""
		status_label.text = "NEW ITEM  %.0fs" % ceilf(float(state.time_left))
		status_label.modulate = Color(0.55, 0.6, 0.66)
		return
	if is_instance_valid(active_pickup) and remote_item_type == wanted_type:
		return
	if is_instance_valid(active_pickup):
		active_pickup.queue_free()
	active_pickup = (STUN_GUN_PICKUP if wanted_type == &"stun_gun" else GENERIC_PICKUP).instantiate()
	add_child(active_pickup)
	active_pickup.configure(wanted_type, ITEM_COLORS[wanted_type])
	active_pickup.monitoring = false
	remote_item_type = wanted_type
	status_label.text = ITEM_NAMES[wanted_type]
	status_label.modulate = ITEM_COLORS[wanted_type]
