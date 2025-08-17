extends Control

@onready var create_btn: Button = $UI/VBoxContainer/CreateBtn
@onready var exit_btn: Button   = $UI/VBoxContainer/ExitBtn
@onready var status_lbl: Label  = $UI/VBoxContainer/Status

var api: RoomApi
const BASE_URL := "http://192.168.1.136:8080"

func _ready():
	Music.play_bgm(preload("res://assets/music/menu/menu.ogg"), 0.6)
	api = RoomApi.new()
	add_child(api)   
	api.base_url = BASE_URL
	_quick_ping()  # opcional
	create_btn.pressed.connect(_on_create_pressed)
	exit_btn.pressed.connect(func(): get_tree().quit())

func _on_create_pressed():
	create_btn.disabled = true
	status_lbl.text = "Creando sala…"

	var r = await api._request_json("POST", "/rooms")
	if not r.ok:
		status_lbl.text = "No se pudo crear la sala (HTTP %s)" % str(r.code)
		create_btn.disabled = false
		return
	
	var code := str(r.data.code)
	var qrCode := str(r.data.qrCode)
	print("Code -> ", code)
	if code == "":
		status_lbl.text = "Respuesta sin código."
		create_btn.disabled = false
		return

	GameNode.GAME_URL = str(BASE_URL + "/rooms/lobby/" + code)
	print(qrCode)
	GameNode.ROOM_CODE = code
	GameNode.ROOM_QR_CODE = qrCode
	# si quieres guardar el token del host:
	api.player_token = str(r.data.get("hostToken",""))

	status_lbl.text = "Sala %s creada. Abriendo lobby…" % code
	get_tree().change_scene_to_file("res://scenes/Lobby.tscn")

func _quick_ping() -> void:
	var r = await api._request_json("GET", "/ping")
	print("PING -> ", r)
