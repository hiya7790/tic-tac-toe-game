extends Node

signal connected
signal disconnected
signal room_created(room_id, player_side)
signal room_joined(room_id, player_side)
signal game_start(starting_player, board)
signal game_restart(starting_player, board)
signal state_update(board, last_move)
signal player_disconnected
signal error_received(message)

var _client: WebSocketClient = WebSocketClient.new()
var _connected: bool = false

func _ready() -> void:
	_client.connect("connection_established", self, "_on_connected")
	_client.connect("connection_closed", self, "_on_closed")
	_client.connect("connection_error", self, "_on_error")
	_client.connect("data_received", self, "_on_data_received")

func _process(_delta: float) -> void:
	if _client.get_connection_status() != WebSocketClient.CONNECTION_DISCONNECTED:
		_client.poll()

func connect_to_server(url: String) -> void:
	if _client.get_connection_status() != WebSocketClient.CONNECTION_DISCONNECTED:
		return
	var err = _client.connect_to_url(url)
	if err != OK:
		print("Network error: ", err)

func create_room() -> void:
	_send({"action": "create_room"})

func join_room(room_id: String) -> void:
	_send({"action": "join_room", "room_id": room_id})

func make_move(row: int, col: int) -> void:
	_send({"action": "make_move", "row": row, "col": col})

func restart_game() -> void:
	_send({"action": "restart"})

func _send(data: Dictionary) -> void:
	if _client.get_connection_status() == WebSocketClient.CONNECTION_CONNECTED:
		_client.get_peer(1).put_packet(to_json(data).to_utf8())

func _on_connected(protocol: String) -> void:
	_connected = true
	emit_signal("connected")
	print("Connected to server")

func _on_closed(was_clean_close: bool) -> void:
	_connected = false
	emit_signal("disconnected")
	print("Disconnected from server")

func _on_error() -> void:
	_connected = false
	emit_signal("disconnected")
	print("Connection error")

func _on_data_received() -> void:
	var packet = _client.get_peer(1).get_packet().get_string_from_utf8()
	var result = JSON.parse(packet)
	if result.error == OK:
		var msg = result.result
		if typeof(msg) != TYPE_DICTIONARY:
			return
		
		if msg.has("error"):
			emit_signal("error_received", msg["error"])
			return
			
		var type = msg.get("type", "")
		match type:
			"room_created":
				emit_signal("room_created", msg["room_id"], msg["player"])
			"room_joined":
				emit_signal("room_joined", msg["room_id"], msg["player"])
			"game_start":
				emit_signal("game_start", msg["starting_player"], msg["board"])
			"state_update":
				emit_signal("state_update", msg["board"], msg.get("last_move", {}))
			"game_restart":
				emit_signal("game_restart", msg["starting_player"], msg["board"])
			"player_disconnected":
				emit_signal("player_disconnected")
