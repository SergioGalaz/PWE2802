extends Node
## Efectos de sonido y música. La música cambia con un fundido entre el día y la noche.

const SFX := ["arpon", "golpe", "pesca", "chapuzon", "reanimar", "muere_ente", "cuerno", "revisorio", "clic"]
const MUSIC_DB := -10.0
const SILENT_DB := -40.0
const VOICES := 10

var streams := {}
var voices: Array[AudioStreamPlayer] = []
var next_voice := 0
var music_players: Array[AudioStreamPlayer] = []
var current_music := ""
var music_enabled := true


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for n in SFX:
		streams[n] = load("res://assets/audio/%s.wav" % n)
	for i in VOICES:
		var p := AudioStreamPlayer.new()
		add_child(p)
		voices.append(p)
	for i in 2:
		var p := AudioStreamPlayer.new()
		p.volume_db = SILENT_DB
		add_child(p)
		music_players.append(p)


## Reproduce un efecto con una pequeña variación de tono para que no suene repetido.
func play(sound: String, volume_db := 0.0, pitch_jitter := 0.08) -> void:
	var stream: AudioStream = streams.get(sound)
	if stream == null:
		return
	var p := voices[next_voice]
	next_voice = (next_voice + 1) % VOICES
	p.stream = stream
	p.volume_db = volume_db
	p.pitch_scale = 1.0 + randf_range(-pitch_jitter, pitch_jitter)
	p.play()


func music(track: String) -> void:
	if track == current_music:
		return
	current_music = track
	var old := music_players[0]
	var new := music_players[1]
	music_players.reverse()
	new.stream = load("res://assets/audio/%s.wav" % track)
	new.volume_db = SILENT_DB
	new.play()
	var tween := create_tween().set_parallel(true)
	tween.tween_property(new, "volume_db", MUSIC_DB if music_enabled else SILENT_DB, 2.0)
	tween.tween_property(old, "volume_db", SILENT_DB, 2.0)
	tween.chain().tween_callback(old.stop)


func set_music_enabled(enabled: bool) -> void:
	music_enabled = enabled
	music_players[0].volume_db = MUSIC_DB if enabled else SILENT_DB
