extends Node

var _player_a := AudioStreamPlayer.new()
var _player_b := AudioStreamPlayer.new()
var _current := _player_a

func _ready():
	add_child(_player_a); add_child(_player_b)
	_player_a.bus = "Music"; _player_b.bus = "Music"
	_player_a.volume_db = -80; _player_b.volume_db = -80

func play_bgm(stream: AudioStream, fade: float = 0.6):
	if stream == null: return
	# asegura loop
	if stream is AudioStreamOggVorbis: stream.loop = true
	if stream is AudioStreamWAV: stream.loop_mode = AudioStreamWAV.LOOP_FORWARD

	var next = _player_b if _current == _player_a else _player_a
	next.stream = stream
	next.play()

	# crossfade
	var tween := create_tween()
	tween.parallel().tween_property(next, "volume_db", 0.0, fade) # sube
	tween.parallel().tween_property(_current, "volume_db", -80.0, fade) # baja
	tween.tween_callback(func():
		_current.stop()
		_current = next
	)
