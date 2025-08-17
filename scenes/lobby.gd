extends Control

@onready var status_lbl = $UI/VBoxContainer/Status
@onready var players_list = $UI/VBoxContainer/Players
@onready var start_btn = $UI/VBoxContainer/Actions/StartBtn
@onready var mode_checkbox = $UI/VBoxContainer/ModeBox/ModeBtn
@onready var refresh_btn = $UI/VBoxContainer/RefreshBtn
@onready var code_lbl = $UI/VBoxContainer/CodeLabel
@onready var qr_image = $UI/VBoxContainer/QRImage

var api : RoomApi
var ws := WebSocketPeer.new()
var stomp_connected := false
var stomp_subscribed := false
var stomp_sub_id := ""

const WS_URL := "ws://localhost:8080/ws"

func _ready():
	api = RoomApi.new()
	api.base_url = GameNode.GAME_URL
	code_lbl.text = GameNode.ROOM_CODE
	
	if GameNode.ROOM_QR_CODE != "":
		_show_qr(GameNode.ROOM_QR_CODE)
	else:
		var tex = await api.fetch_qr_image(GameNode.ROOM_CODE)
		if tex:
			qr_image.texture = tex
	
	start_btn.pressed.connect(_on_start_pressed)
	mode_checkbox.toggled.connect(_on_mode_toggled)
	refresh_btn.pressed.connect(_on_refresh_pressed)
	
	var err = ws.connect_to_url(WS_URL)
	if err != OK:
		push_error("WS connect error: %s" % err)

func _on_start_pressed():
	var res = await api.start()
	status_lbl.text = "Partida iniciada" if res.ok else "Error al iniciar"

func _on_mode_toggled(button_pressed: bool):
	var mode = "auto" if button_pressed else "manual"
	var res = await api.set_mode(mode)
	status_lbl.text = "Modo cambiado" if res.ok else "Error al cambiar modo"

func _on_refresh_pressed():
	var res = await api.get_room()
	if res.ok:
		players_list.clear()
		for p in res.data.players:
			players_list.add_item(p.nickname)
	else:
		status_lbl.text = "Error al refrescar"
		
func _show_qr(b64: String):
	var img := Image.new()
	var bytes := Marshalls.base64_to_raw(b64)
	if img.load_png_from_buffer(bytes) == OK:
		qr_image.texture = ImageTexture.create_from_image(img)
		
func _process(_dt):
	ws.poll()
	if ws.get_ready_state() != WebSocketPeer.STATE_OPEN:
		return

	if not stomp_connected:
		_stomp_send_bin("CONNECT", {
			"accept-version":"1.2",
			"host":"localhost"
		}, "")

	while ws.get_available_packet_count() > 0:
		var ba: PackedByteArray = ws.get_packet()
		# Procesa TODOS los frames separados por NUL (0x00)
		var start := 0
		for i in ba.size():
			if ba[i] == 0:
				var slice := ba.slice(start, i - start)
				if slice.size() > 0:
					var frame := slice.get_string_from_utf8()
					_stomp_handle(frame)
				start = i + 1
		# Si queda cola sin NUL, la ignoramos (STOMP debe terminar siempre con NUL)

func _stomp_send_bin(cmd:String, headers:Dictionary, body:String):
	var s := cmd + "\n"
	for k in headers.keys():
		s += "%s:%s\n" % [k, str(headers[k])]
	s += "\n" + body
	var bytes := s.to_utf8_buffer()
	bytes.append(0)               # terminador NUL
	ws.send(bytes)                # <-- binario SIEMPRE  

func _stomp_send(cmd:String, headers:Dictionary, body:String):
	var frame := cmd + "\n"
	for k in headers.keys():
		frame += "%s:%s\n" % [k, str(headers[k])]
	frame += "\n"
	frame += body
	frame += "\u0000"
	ws.send_text(frame)

func _stomp_handle(frame:String):
	var parts := frame.split("\n\n", false, 2)
	var header_block := parts[0]
	var body = ""
	if parts.size() > 1:
		body = parts[1]

	if header_block.begins_with("CONNECTED"):
		stomp_connected = true
		if not stomp_subscribed:
			_stomp_send_bin("SUBSCRIBE", {
				"id": "room-" + GameNode.ROOM_CODE,
				"destination": "/topic/rooms/%s" % GameNode.ROOM_CODE,
				"ack": "auto"
			}, "")
			stomp_subscribed = true
		return

	if header_block.begins_with("MESSAGE"):
		_handle_message(body)
		return

	if header_block.begins_with("ERROR"):
		push_error("STOMP ERROR:\n" + frame)

			
func _handle_message(msg:String):
	var data = JSON.parse_string(msg)
	if typeof(data) == TYPE_DICTIONARY and data.has("players"):
		players_list.clear()
		for p in data.players:
			players_list.add_item(str(p.get("nick", p.get("nickname","?"))))

func _on_connected(protocol: String):
	print("WS conectado")
	# suscribirse al topic de la sala
	ws.send_text("SUBSCRIBE /topic/rooms/%s" % GameNode.ROOM_CODE)

func _on_data_received():
	var msg = ws.get_peer(1).get_packet().get_string_from_utf8()
	print("Evento recibido:", msg)
	# parsear JSON y actualizar lista de jugadores
