# res://scripts/StompClient.gd
extends Node
class_name StompClient

signal connected()
signal message_received(destination: String, headers: Dictionary, body: String)
signal disconnected(reason: String)

var _ws := WebSocketPeer.new()
var _connected := false
var _host_header := "localhost"

func connect_to(url: String, host_header: String = "localhost") -> void:
	_host_header = host_header
	var err := _ws.connect_to_url(url) # ej: "ws://localhost:8080/ws/websocket"
	if err != OK:
		emit_signal("disconnected", "connect_error:%s" % err)
		return
	set_process(true)

func _process(_dt):
	_ws.poll()
	var state := _ws.get_ready_state()

	if state == WebSocketPeer.STATE_OPEN:
		if not _connected:
			# Enviar frame STOMP CONNECT al abrir
			_send_frame("CONNECT", {"accept-version":"1.2","host": _host_header}, "")
		# Leer todos los paquetes pendientes
		while _ws.get_available_packet_count() > 0:
			var data: PackedByteArray = _ws.get_packet()
			var text := data.get_string_from_utf8()
			for frame in _split_frames(text):
				_handle_frame(frame)

	elif state == WebSocketPeer.STATE_CLOSED:
		if _connected:
			_connected = false
			emit_signal("disconnected", "socket_closed")
		set_process(false)

func subscribe(dest: String, sub_id: String) -> void:
	_send_frame("SUBSCRIBE", {"id": sub_id, "destination": dest, "ack":"auto"}, "")

func send(destination: String, body: String, headers: Dictionary = {}) -> void:
	var h := {"destination": destination}
	for k in headers.keys(): h[k] = str(headers[k])
	_send_frame("SEND", h, body)

func disconnect_gracefully():
	_send_frame("DISCONNECT", {}, "")
	_ws.close()

func _send_frame(command: String, headers: Dictionary, body: String):
	var sb := "%s\n" % command
	for k in headers.keys():
		sb += "%s:%s\n" % [k, headers[k]]
	sb += "\n"
	if body != "":
		sb += body
	sb += char(0)              # Terminador STOMP
	_ws.send_text(sb)          # Godot 4: send_text() para marcos de texto

func _split_frames(chunk: String) -> Array:
	var out: Array = []
	for p in chunk.split(char(0)):
		if p.strip_edges() != "":
			out.append(p)
	return out

func _parse_frame(raw: String) -> Dictionary:
	var lines := raw.split("\n")
	var command := lines[0].strip_edges()
	var headers := {}
	var i := 1
	while i < lines.size() and lines[i].strip_edges() != "":
		var kv := lines[i].split(":", false, 1)
		if kv.size() == 2: headers[kv[0]] = kv[1]
		i += 1
	var body := "\n".join(lines.slice(i+1, lines.size())) if i + 1 < lines.size() else ""
	return {"command":command, "headers":headers, "body":body}

func _handle_frame(raw: String):
	var f = _parse_frame(raw)
	match f.command:
		"CONNECTED":
			_connected = true
			emit_signal("connected")
		"MESSAGE":
			emit_signal("message_received", f.headers.get("destination",""), f.headers, f.body)
		"ERROR":
			emit_signal("disconnected", "stomp_error")
		_:
			pass
