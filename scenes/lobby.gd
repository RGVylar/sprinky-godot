extends Control

@onready var status_lbl = $UI/VBoxContainer/Status
@onready var players_list = $UI/VBoxContainer/Players
@onready var start_btn = $UI/VBoxContainer/Actions/StartBtn
@onready var mode_checkbox = $UI/VBoxContainer/ModeBox/ModeBtn
@onready var refresh_btn = $UI/VBoxContainer/RefreshBtn
@onready var code_lbl = $UI/VBoxContainer/CodeLabel
@onready var qr_image = $UI/VBoxContainer/QRImage

var api : RoomApi

func _ready():
	api = RoomApi.new()
	api.base_url = GameNode.GAME_URL
	code_lbl.text = GameNode.ROOM_CODE
	
	if GameNode.ROOM_QR_CODE != "":
		_show_qr(GameNode.ROOM_QR_CODE)
	else:
		# Opción B: pedir el PNG al backend
		var tex = await api.fetch_qr_image(GameNode.ROOM_CODE)
		if tex: qr_image.texture = tex
	
	start_btn.pressed.connect(_on_start_pressed)
	mode_checkbox.toggled.connect(_on_mode_toggled)
	refresh_btn.pressed.connect(_on_refresh_pressed)

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
