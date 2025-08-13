extends Node
class_name Game

signal state_changed

var BASE_URL := "http://localhost:8080"
var ROOM_CODE := "8BLT"
var GAME_URL = BASE_URL
var ROOM_QR_CODE

var current_state := "LOBBY"
var deadline_epoch_ms := 0
var prompt_text := ""
var players := []
var answers := {}

var api
var stomp

func _ready():
	# nada; lo inicializamos desde la escena principal
	pass

func setup(base_url: String, room_code: String):
	BASE_URL = base_url
	ROOM_CODE = room_code
	api = load("res://scripts/RoomApi.gd").new()
	add_child(api)
	api.base_url = BASE_URL
	api.room_code = ROOM_CODE

	stomp = load("res://scripts/StompClient.gd").new()
	add_child(stomp)
	# ws://localhost:8080/ws/websocket — ajusta si usas https
	var ws_url = BASE_URL.replace("http","ws") + "/ws/websocket"
	stomp.connect_to(ws_url, "sprinky")
	stomp.connected.connect(func():
		stomp.subscribe("/topic/rooms/%s" % ROOM_CODE, "room-sub")
	)
	stomp.message_received.connect(func(_dest,_headers, body):
		on_state_update(body)
	)

func on_state_update(json_text: String):
	var data = JSON.parse_string(json_text)
	if typeof(data) != TYPE_DICTIONARY: return
	current_state = data.get("state", current_state)
	deadline_epoch_ms = int(data.get("deadlineEpochMs", 0))
	prompt_text = data.get("promptText","")
	players = data.get("players",[])
	answers = data.get("answers", {})
	
	emit_signal("state_changed")

func initial_refresh() -> void:
	var r = await api.get_room()
	if r.ok:
		on_state_update(JSON.stringify(r.data))
