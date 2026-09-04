class_name ATINetworkSession
extends Node

signal room_hosted(code: String, detail: String)
signal host_failed(message: String)
signal joined_server
signal join_failed(message: String)
signal remote_player_connected(peer_id: int)
signal remote_player_disconnected(peer_id: int)

const DEFAULT_PORT: int = 27888
const ROOM_PREFIX := "ATI"

var upnp: UPNP
var mapped_port: int = 0
var route_generation := 0
var route_jobs: Array = []
var route_tasks: Array = []


func _ready() -> void:
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)
	tree_exiting.connect(_finish_route_jobs)


func host_room(port: int = DEFAULT_PORT, use_upnp: bool = true, tunnel_address: String = "") -> void:
	close_session()
	var peer := ENetMultiplayerPeer.new()
	var error := peer.create_server(port, 3, 3)
	if error != OK:
		host_failed.emit("Lobby NOT opened: UDP port %d is unavailable (error %d). Another ATI window may already be hosting. Close that host before retrying here; do not join a second window on this PC." % [port, error])
		return
	multiplayer.multiplayer_peer = peer

	if not tunnel_address.is_empty():
		if _decode_room_code(tunnel_address).is_empty():
			close_session()
			host_failed.emit("Invalid tunnel address. Use your own host:port.")
			return
		room_hosted.emit(tunnel_address, "Using your tunnel to this PC. Keep Playit running. Internet reachability is not checked.")
		return
	var address := _best_local_ipv4()
	var detail := "LAN room created."
	var share_code := _encode_room_code(address, port)
	if not use_upnp:
		room_hosted.emit(share_code, detail)
		return
	route_tasks.append({"kind": "discover", "port": port, "generation": route_generation})


func _resolve_route(port: int) -> Dictionary:
	var router := UPNP.new()
	var discovery_error := router.discover(1800, 2, "InternetGatewayDevice")
	if discovery_error == UPNP.UPNP_RESULT_SUCCESS and router.get_gateway() != null and router.get_gateway().is_valid_gateway():
		var external := router.query_external_address()
		if not external.is_empty() and router.add_port_mapping(port, port, "Around the Island", "UDP") == UPNP.UPNP_RESULT_SUCCESS:
			return {"router": router, "port": port, "address": external}
	return {}


func _route_task(task: Dictionary) -> Dictionary:
	if task.kind == "cleanup":
		task.router.delete_port_mapping(task.port, "UDP")
		return {}
	return _resolve_route(task.port)


func _process(_delta: float) -> void:
	# One worker at a time: stale cleanup must finish before a replacement maps
	# the same port. No router calls block the interactive main thread.
	if not route_jobs.is_empty():
		var job: Dictionary = route_jobs[0]
		if job.thread.is_alive():
			return
		var result: Dictionary = job.thread.wait_to_finish()
		route_jobs.clear()
		if job.kind == "discover":
			if job.generation != route_generation:
				if not result.is_empty():
					route_tasks.push_front({"kind": "cleanup", "router": result.router, "port": result.port})
			elif result.is_empty():
				room_hosted.emit(_encode_room_code(_best_local_ipv4(), job.port), "LAN only: automatic port forwarding failed. For internet play, use your own Playit tunnel or manually forward UDP 27888 and share your public IP:port.")
			else:
				upnp = result.router
				mapped_port = result.port
				room_hosted.emit(_encode_room_code(result.address, mapped_port), "Router configured. Allow the game through Windows Firewall if prompted.")
	while route_jobs.is_empty() and not route_tasks.is_empty():
		var task: Dictionary = route_tasks.pop_front()
		if task.kind == "discover" and task.generation != route_generation:
			continue
		var thread := Thread.new()
		if thread.start(_route_task.bind(task)) != OK:
			if task.kind == "discover":
				room_hosted.emit(_encode_room_code(_best_local_ipv4(), task.port), "Router check unavailable. LAN only; use your own tunnel for internet hosting.")
			continue
		task.thread = thread
		route_jobs.append(task)


func _finish_route_jobs() -> void:
	# Shutdown can wait for the one outstanding router request to release resources.
	for job in route_jobs:
		var result: Dictionary = job.thread.wait_to_finish()
		if job.kind == "discover" and not result.is_empty():
			result.router.delete_port_mapping(result.port, "UDP")
	route_jobs.clear()
	for task in route_tasks:
		if task.kind == "cleanup":
			task.router.delete_port_mapping(task.port, "UDP")
	route_tasks.clear()
	if upnp != null and mapped_port > 0:
		upnp.delete_port_mapping(mapped_port, "UDP")
	mapped_port = 0



func join_room(code_or_address: String) -> void:
	close_session()
	var connection := _decode_room_code(code_or_address.strip_edges())
	if connection.is_empty():
		join_failed.emit("That room code is not valid. You can also enter IP:PORT.")
		return
	var peer := ENetMultiplayerPeer.new()
	var error := peer.create_client(connection.address, connection.port, 3)
	if error != OK:
		join_failed.emit("Could not start the connection (error %d)." % error)
		return
	multiplayer.multiplayer_peer = peer


func close_session() -> void:
	route_generation += 1
	_remove_port_mapping()
	if multiplayer.multiplayer_peer != null:
		multiplayer.multiplayer_peer.close()
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()


func _encode_room_code(address: String, port: int) -> String:
	var parts := address.split(".")
	if parts.size() != 4:
		return "%s:%d" % [address, port]
	var bytes := PackedByteArray()
	for part in parts:
		var value := int(part)
		if value < 0 or value > 255:
			return "%s:%d" % [address, port]
		bytes.append(value)
	bytes.append((port >> 8) & 0xff)
	bytes.append(port & 0xff)
	var checksum := 0xA7
	for value in bytes:
		checksum = checksum ^ value
	bytes.append(checksum)
	var encoded := bytes.hex_encode().to_upper()
	return "%s-%s-%s-%s" % [ROOM_PREFIX, encoded.substr(0, 4), encoded.substr(4, 4), encoded.substr(8, 6)]


func _decode_room_code(value: String) -> Dictionary:
	if value.contains(":") and not value.begins_with(ROOM_PREFIX + "-"):
		var direct := value.split(":")
		if direct.size() == 2 and not direct[0].is_empty() and direct[1].is_valid_int() and int(direct[1]) > 0 and int(direct[1]) <= 65535:
			return {"address": direct[0], "port": int(direct[1])}
		return {}
	var compact := value.to_upper().replace(ROOM_PREFIX + "-", "").replace("-", "")
	if compact.length() != 14:
		return {}
	var bytes := compact.hex_decode()
	if bytes.size() != 7:
		return {}
	var checksum := 0xA7
	for index in 6:
		checksum = checksum ^ bytes[index]
	if checksum != bytes[6]:
		return {}
	var address := "%d.%d.%d.%d" % [bytes[0], bytes[1], bytes[2], bytes[3]]
	var port := (int(bytes[4]) << 8) | int(bytes[5])
	return {"address": address, "port": port}


func _best_local_ipv4() -> String:
	for address in IP.get_local_addresses():
		if address.contains(":") or address.begins_with("127.") or address.begins_with("169.254."):
			continue
		return address
	return "127.0.0.1"


func _remove_port_mapping() -> void:
	if upnp != null and mapped_port > 0:
		route_tasks.append({"kind": "cleanup", "router": upnp, "port": mapped_port})
	mapped_port = 0
	upnp = null


func _on_peer_connected(peer_id: int) -> void:
	remote_player_connected.emit(peer_id)


func _on_peer_disconnected(peer_id: int) -> void:
	remote_player_disconnected.emit(peer_id)


func _on_connected_to_server() -> void:
	joined_server.emit()


func _on_connection_failed() -> void:
	join_failed.emit("Could not join. Ask the host to open Host lobby and keep Playit running. The lobby may also be full. Retry after a seat is available.")


func _on_server_disconnected() -> void:
	join_failed.emit("The host closed the room.")
