extends SceneTree


func _initialize() -> void:
	var session = load("res://scripts/network_session.gd").new()
	root.add_child(session)
	var code: String = session._encode_room_code("203.0.113.42", 27888)
	var decoded: Dictionary = session._decode_room_code(code)
	if decoded.get("address") != "203.0.113.42" or decoded.get("port") != 27888:
		push_error("Room code did not round-trip: %s -> %s" % [code, decoded])
		quit(1)
		return
	if not session._decode_room_code("ATI-BAD-CODE").is_empty():
		push_error("Invalid room code was accepted")
		quit(1)
		return
	session.queue_free()
	quit(0)
