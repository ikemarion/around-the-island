extends SceneTree

class FakeRouter extends UPNP:
	var events: Array
	func _init(log: Array) -> void:
		events = log
	@warning_ignore("native_method_override")
	func delete_port_mapping(_port: int, _protocol: String = "UDP") -> int:
		events.append("cleanup")
		return 0

class FakeSession extends "res://scripts/network_session.gd":
	var events: Array = []
	func _resolve_route(port: int) -> Dictionary:
		events.append("discover")
		OS.delay_msec(70)
		return {"router": FakeRouter.new(events), "port": port, "address": "203.0.113.1"}

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var session = FakeSession.new()
	root.add_child(session)
	session.route_tasks.append({"kind": "discover", "port": 27996, "generation": session.route_generation})
	session._process(0)
	session.close_session()
	session.route_tasks.append({"kind": "discover", "port": 27996, "generation": session.route_generation})
	for attempt in 100:
		await create_timer(0.01).timeout
		if session.mapped_port == 27996: break
	assert(session.events == ["discover", "cleanup", "discover"])
	assert(session.mapped_port == 27996)
	session.close_session()
	for attempt in 100:
		await create_timer(0.01).timeout
		if session.route_jobs.is_empty() and session.route_tasks.is_empty(): break
	assert(session.events == ["discover", "cleanup", "discover", "cleanup"])
	var advertised: Array = []
	session.room_hosted.connect(func(code, detail): advertised.append([code, detail]))
	session.host_room(27996, false, "my-tunnel.example:23456")
	assert(advertised[-1][0] == "my-tunnel.example:23456")
	session.close_session()
	session.host_room(27996, false)
	assert(advertised[-1][0].begins_with("ATI-") and "LAN" in advertised[-1][1])
	assert(session._decode_room_code("example.com:99999").is_empty())
	session.close_session()
	session.queue_free()
	await process_frame
	print("ROUTING_REGRESSION passed (mocked router; no real mappings)")
	quit()
