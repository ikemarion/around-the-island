extends Node
## Bounded, stop-and-wait report transfer. No arbitrary client filenames/paths.
const CHUNK := 800
const MAX_REPORT := 262144
const SESSION_LIMIT := 2097152
const INBOX_LIMIT := 52428800
var game: Node
var queue: Array[String] = []
var payload := PackedByteArray()
var digest := ""
var offset := 0
var timer := 0.0
var incoming: Dictionary = {}
var budgets: Dictionary = {}
var bytes_sent := 0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	multiplayer.peer_disconnected.connect(func(id): incoming.erase(id); budgets.erase(id))

func reset() -> void:
	queue.clear()
	payload.clear()
	incoming.clear()
	budgets.clear()
	digest = ""
	offset = 0
	bytes_sent = 0

func begin() -> void:
	reset()
	var path: String = game.network_diagnostics.directory + "/reports"
	var dir := DirAccess.open(path)
	if dir == null: return
	var files := dir.get_files()
	files.sort()
	for name in files:
		if name.begins_with("ATI-") and name.ends_with(".json"):
			queue.append(path.path_join(name))
	_load_next()

func _hash(data: PackedByteArray) -> String:
	var h := HashingContext.new()
	h.start(HashingContext.HASH_SHA256)
	h.update(data)
	return h.finish().hex_encode()

func _load_next() -> void:
	payload.clear()
	digest = ""
	offset = 0
	while not queue.is_empty():
		var file := FileAccess.open(queue[0],FileAccess.READ)
		if file == null or file.get_length() > MAX_REPORT:
			queue.pop_front()
			continue
		var data := file.get_buffer(file.get_length())
		file.close()
		var id := _hash(data)
		var marker: String = game.network_diagnostics.directory + "/sent/" + id
		if FileAccess.file_exists(marker) or data.is_empty():
			queue.pop_front()
			continue
		if bytes_sent + data.size() > SESSION_LIMIT: return
		payload = data
		digest = id
		timer = 0.0
		return

func _process(delta: float) -> void:
	if game.session_mode != &"client" or game.local_slot < 0 or payload.is_empty(): return
	timer -= delta
	if timer > 0: return
	# One small outstanding datagram. Retries do not build a reliable queue.
	timer = 0.25
	_chunk.rpc_id(1,digest,payload.size(),offset,payload.slice(offset,mini(offset+CHUNK,payload.size())))

@rpc("any_peer","call_remote","unreliable",2)
func _chunk(id: String, total: int, at: int, data: PackedByteArray) -> void:
	var sender := multiplayer.get_remote_sender_id()
	if not multiplayer.is_server() or not game.peer_to_slot.has(sender): return
	var next: int = accept_chunk(sender,id,total,at,data)
	if next >= 0: _ack.rpc_id(sender,id,next,next == total)

func accept_chunk(sender: int, id: String, total: int, at: int, data: PackedByteArray) -> int:
	if id.length()!=64 or not id.is_valid_hex_number() or total <= 0 or total > MAX_REPORT or at < 0 or data.is_empty() or data.size()>CHUNK or at+data.size()>total: return -1
	var budget: Dictionary = budgets.get(sender,{"bytes":0,"last":-1000})
	var now := Time.get_ticks_msec()
	if now-int(budget.last)<50 or int(budget.bytes)+data.size()>SESSION_LIMIT: return -1
	budget.last = now
	budget.bytes += data.size()
	budgets[sender] = budget
	var folder: String = game.network_diagnostics.directory + "/received"
	var target := folder.path_join(id+".json")
	if FileAccess.file_exists(target): return total
	var state: Dictionary = incoming.get(sender,{"id":id,"total":total,"data":PackedByteArray()})
	if state.id != id or state.total != total: return -1
	if at != state.data.size(): return state.data.size()
	state.data.append_array(data)
	incoming[sender] = state
	if state.data.size() < total: return state.data.size()
	if _hash(state.data) != id:
		incoming.erase(sender)
		return -1
	var parsed = JSON.parse_string(state.data.get_string_from_utf8())
	if not parsed is Dictionary or not parsed.has("recent_events") or not parsed.has("build"):
		incoming.erase(sender)
		return -1
	if DirAccess.make_dir_recursive_absolute(folder) != OK: return -1
	var used := 0
	for name in DirAccess.get_files_at(folder):
		var existing := FileAccess.open(folder.path_join(name),FileAccess.READ)
		if existing: used += existing.get_length()
	if used+total > INBOX_LIMIT: return -1
	var output := FileAccess.open(target,FileAccess.WRITE)
	if output == null: return -1
	output.store_buffer(state.data)
	output.flush()
	var ok := output.get_error() == OK
	output.close()
	if not ok: return -1
	incoming.erase(sender)
	game.network_diagnostics.record("client_report_received",{"peer":sender,"sha256":id,"bytes":total})
	return total

@rpc("authority","call_remote","unreliable",2)
func _ack(id: String, next: int, complete: bool) -> void:
	if game.session_mode != &"client" or id != digest or next < offset or next > payload.size(): return
	if complete and next == payload.size():
		var folder: String = game.network_diagnostics.directory + "/sent"
		if DirAccess.make_dir_recursive_absolute(folder) == OK:
			var file := FileAccess.open(folder.path_join(digest),FileAccess.WRITE)
			if file: file.store_string("Received by configured ATI host")
		bytes_sent += payload.size()
		queue.pop_front()
		_load_next()
	else:
		offset = next
		timer = 0.25
