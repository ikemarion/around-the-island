extends RefCounted
## Small, validated cosmetic catalog. Runtime loads keep actor/effect dependencies acyclic.
const IDS := [&"sockling", &"looper"]
const PATHS := {&"sockling": "res://scripts/sockling_art.gd", &"looper": "res://scripts/looper_art.gd"}
const SOCKLING_COLORS := [Color("65abc3"), Color("d88578"), Color("72a18b"), Color("ba8e50")]
const LOOPER_COLORS := [Color("88749e"), Color("9980a7"), Color("79729e"), Color("a5809e")]

static func valid(id: StringName) -> bool:
	return id in IDS

static func sanitize(id: StringName) -> StringName:
	return id if valid(id) else &"sockling"

static func display_name(id: StringName) -> String:
	return "Looper" if id == &"looper" else "Sockling"

static func color_for(id: StringName, slot: int) -> Color:
	return (LOOPER_COLORS if id == &"looper" else SOCKLING_COLORS)[clampi(slot, 0, 3)]

static func create(id: StringName, actor = null, tint := Color(-1, -1, -1, -1)) -> Node3D:
	var safe_id := sanitize(id)
	var model = load(PATHS[safe_id]).new()
	model.actor = actor
	model.preview_color = color_for(safe_id, actor.player_index if is_instance_valid(actor) else 0) if tint.a < 0.0 else tint
	return model
