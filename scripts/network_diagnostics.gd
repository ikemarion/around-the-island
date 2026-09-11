extends Node
## Small application-level probes; snapshot gaps are not transport packet loss.
var game: Node
var log_file: FileAccess
var elapsed := 0.0
var probe_elapsed := 0.0
var worst_frame_ms := 0.0
var rtt_ms := -1
var unanswered_probes := 0
var pending: Dictionary = {}
var serial := 0
var snapshot_count := 0
var last_snapshot_ms := 0
var max_snapshot_gap_ms := 0
var sent_updates := 0
var estimated_payload_bytes := 0
var directory := "user://network-logs"
var history: Array = []
var peer_stats: Dictionary = {}
var last_report := ""
var report_serial := 0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if "--diagnostics-workspace" in OS.get_cmdline_user_args():
		directory = "res://build/network-test/diagnostics"
	DirAccess.make_dir_recursive_absolute(directory)
	var path := directory + "/session-%d-%d.jsonl" % [int(Time.get_unix_time_from_system()),OS.get_process_id()]
	log_file = FileAccess.open(path,FileAccess.WRITE)
	if log_file:
		print("NETWORK_DIAGNOSTICS ",ProjectSettings.globalize_path(path))
	else:
		push_warning("Network log file unavailable; diagnostics will use console output")
	multiplayer.peer_connected.connect(func(id): record("peer_connected",{"peer":id}))
	multiplayer.peer_disconnected.connect(func(id):
		record("peer_disconnected",{"peer":id})
		export_report("peer_disconnected",id)
		peer_stats.erase(id))
	multiplayer.server_disconnected.connect(func():
		record("server_disconnected")
		export_report("server_disconnected"))
	record("started",{"build":game.BUILD_VERSION})

func record(event: String, data: Dictionary = {}) -> void:
	var entry := {"event":event,"unix_ms":int(Time.get_unix_time_from_system()*1000),"mode":str(game.session_mode),"rtt_ms":rtt_ms}
	entry.merge(data)
	history.append(entry)
	if history.size() > 240:
		history.pop_front()
	if log_file:
		log_file.store_line(JSON.stringify(entry))
		log_file.flush()
	else:
		print("NETWORK_DIAGNOSTICS ",JSON.stringify(entry))

func reset_session() -> void:
	# Save before teardown clears mode, RTT and pending probes. Also covers
	# intentional exits; reports do not imply a network fault.
	if game.session_mode in [&"client", &"host"]:
		export_report("session_ended")
	record("session_reset")
	peer_stats.clear()
	pending.clear()
	rtt_ms = -1
	last_snapshot_ms = 0
	unanswered_probes = 0

func sent(value: Variant) -> void:
	sent_updates += 1
	estimated_payload_bytes += var_to_bytes(value).size()

func received_snapshot() -> void:
	var now := Time.get_ticks_msec()
	if last_snapshot_ms > 0:
		max_snapshot_gap_ms = maxi(max_snapshot_gap_ms,now-last_snapshot_ms)
	last_snapshot_ms = now
	snapshot_count += 1

func _process(delta: float) -> void:
	worst_frame_ms = maxf(worst_frame_ms,delta*1000)
	elapsed += delta
	probe_elapsed += delta
	if game.session_mode == &"client" and probe_elapsed >= 1.0:
		probe_elapsed = 0.0
		serial += 1
		pending[serial] = Time.get_ticks_msec()
		_probe.rpc_id(1,serial)
	for key in pending.keys():
		if Time.get_ticks_msec()-int(pending[key]) > 5000:
			pending.erase(key)
			unanswered_probes += 1
	if elapsed >= 5.0:
		record("sample",{"peers":multiplayer.get_peers().size(),"peer_stats":peer_stats.duplicate(true),"max_frame_ms":worst_frame_ms,"snapshots":snapshot_count,"max_snapshot_gap_ms":max_snapshot_gap_ms,"unanswered_probes":unanswered_probes,"obstacle_update_calls":sent_updates,"estimated_obstacle_payload_bytes":estimated_payload_bytes})
		elapsed = 0.0
		worst_frame_ms = 0.0
		snapshot_count = 0
		max_snapshot_gap_ms = 0
		sent_updates = 0
		estimated_payload_bytes = 0

@rpc("any_peer","call_remote","unreliable",2)
func _probe(id: int) -> void:
	if game.session_mode == &"host":
		var peer := multiplayer.get_remote_sender_id()
		var stats: Dictionary = peer_stats.get(peer,{"probes_received":0})
		stats.probes_received += 1
		stats.last_probe_unix_ms = int(Time.get_unix_time_from_system()*1000)
		stats.slot = game.peer_to_slot.get(peer,-1)
		peer_stats[peer] = stats
		_reply.rpc_id(multiplayer.get_remote_sender_id(),id)

func export_report(reason := "manual", peer := 0) -> String:
	var reports := directory + "/reports"
	if DirAccess.make_dir_recursive_absolute(reports) != OK:
		push_warning("Cannot create diagnostic reports folder")
		return ""
	report_serial += 1
	var path := reports + "/ATI-%d-%d-%d.json" % [int(Time.get_unix_time_from_system()),OS.get_process_id(),report_serial]
	var file := FileAccess.open(path,FileAccess.WRITE)
	if not file:
		push_warning("Cannot save diagnostic report")
		return ""
	file.store_string(JSON.stringify({"build":game.BUILD_VERSION,"reason":reason,"peer":peer,"mode":str(game.session_mode),"round_epoch":game.round_epoch,"time_remaining":game.time_remaining,"rtt_ms":rtt_ms,"pending_probes":pending.size(),"unanswered_probes":unanswered_probes,"peer_stats":peer_stats,"recent_events":history,"note":"Local diagnostics only. A disconnect does not identify its cause. Probe misses are not packet-loss percentage. session_ended includes intentional exits. No automatic upload."},"\t"))
	file.close()
	last_report = ProjectSettings.globalize_path(path)
	print("ATI_DIAGNOSTIC_REPORT ",last_report)
	return last_report

func open_reports() -> void:
	if export_report().is_empty():
		game.lobby_status.text = "Could not save diagnostics. Check folder permissions."
		return
	OS.shell_open(ProjectSettings.globalize_path(directory + "/reports"))

@rpc("authority","call_remote","unreliable",2)
func _reply(id: int) -> void:
	if pending.has(id):
		rtt_ms = Time.get_ticks_msec()-int(pending[id])
		pending.erase(id)
