extends SceneTree
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	main.set_physics_process(false)
	var d = main.network_diagnostics
	d.directory = "res://build/network-test/diagnostics"
	d.peer_stats[123] = {"slot":1,"probes_received":7,"last_probe_unix_ms":1000}
	d.record("test_marker")
	main.multiplayer.peer_disconnected.emit(123)
	assert(not d.last_report.is_empty())
	var data = JSON.parse_string(FileAccess.get_file_as_string(d.last_report))
	assert(data.reason == "peer_disconnected" and data.peer == 123)
	assert(data.peer_stats["123"].probes_received == 7)
	assert(not d.peer_stats.has(123))
	assert(data.recent_events.back().event == "peer_disconnected")
	main.multiplayer.server_disconnected.emit()
	data = JSON.parse_string(FileAccess.get_file_as_string(d.last_report))
	assert(data.reason == "server_disconnected")
	for i in 250:
		d.record("bounded_history")
	assert(d.history.size() == 240)
	print("DIAGNOSTIC_REPORT passed: peer/server disconnect exports, retained peer data, bounded history")
	quit()
