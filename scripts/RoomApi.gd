extends Node
class_name RoomApi

var base_url := ""
var room_code := ""
var player_token := ""

func _method_enum(m: String) -> int:
	match m:
		"GET":  return HTTPClient.METHOD_GET
		"POST": return HTTPClient.METHOD_POST
		_:      return HTTPClient.METHOD_GET

func _request_json(method: String, path: String, payload: Variant = null, extra_headers: Dictionary = {}) -> Dictionary:
	var url: String = "%s%s" % [base_url, path]
	var headers := PackedStringArray(["Content-Type: application/json"])
	for k in extra_headers.keys():
		headers.append("%s: %s" % [k, str(extra_headers[k])])

	var body := "" if payload == null else JSON.stringify(payload)

	var http := HTTPRequest.new()
	add_child(http)
	await get_tree().process_frame  # asegura que está en el árbol

	var err := http.request(url, headers, _method_enum(method), body)
	print("request err:", err)
	if err != OK:
		push_error("HTTPRequest.request error: %s for %s %s" % [err, method, url])
		http.queue_free()
		return {"ok": false, "error": "request_error_start"}

	var res = await http.request_completed
	# res = [result, response_code, headers, body]
	var result_status: int = res[0]
	var code: int = res[1]
	var raw_body: PackedByteArray = res[3]
	var txt := raw_body.get_string_from_utf8()

	http.queue_free()

	if result_status != HTTPRequest.RESULT_SUCCESS:
		return {"ok": false, "code": code, "error": "request_failed", "raw": txt}

	var data: Dictionary = {}
	if txt != "":
		var pr = JSON.parse_string(txt)
		if typeof(pr) == TYPE_DICTIONARY:
			data = pr

	return {"ok": code >= 200 and code < 300, "code": code, "data": data}


func get_room():       return await _request_json("GET",  "/rooms/%s" % room_code)
func join(nick):
	var r = await _request_json("POST", "/rooms/%s/join" % room_code, {"nickname": nick})
	if r.ok and r.data.has("playerToken"):
		player_token = r.data.playerToken
	return r
func start():          return await _request_json("POST", "/rooms/%s/start"  % room_code, null, {"X-Player-Token": player_token})
func answer(t):        return await _request_json("POST", "/rooms/%s/answer" % room_code, {"answer": t}, {"X-Player-Token": player_token})
func vote(pid):        return await _request_json("POST", "/rooms/%s/vote"   % room_code, {"playerId": pid}, {"X-Player-Token": player_token})
func set_mode(m):      return await _request_json("POST", "/rooms/%s/mode"   % room_code, {"mode": m}, {"X-Player-Token": player_token})


func create_room():
	print("create_room")
	var r = await _request_json("POST", "/rooms")
	
	print("r:")
	print(r)
	if not r.ok:
		print("not r")
		r = await _request_json("POST", "/rooms")
	print("r:")
	print(r)
	return r
	
func fetch_qr_image(code: String) -> Texture2D:
	var http := HTTPRequest.new()
	add_child(http)
	var url = "%s/rooms/%s/qr" % [base_url, code]
	var err := http.request(url)
	var _res = await http.request_completed
	remove_child(http)

	if err != OK or http.get_response_code() != 200:
		return null
	var png: PackedByteArray = http.get_body()
	var img := Image.new()
	if img.load_png_from_buffer(png) != OK:
		return null
	return ImageTexture.create_from_image(img)
	
	
