extends Node
## Autoload "Sfx": sound effects and music. Sounds are listed in data/config/audio.json;
## match events are mapped to sounds there too. Sound and music can be switched off in Settings.

var _streams: Dictionary = {}
var _defs: Dictionary = {}
var _pool: Array[AudioStreamPlayer] = []
var _next: int = 0
var _music: AudioStreamPlayer
var _music_wanted: bool = false


func _ready() -> void:
	process_mode = PROCESS_MODE_ALWAYS
	var sounds: Dictionary = Config.get_value("audio", "sounds", {})
	for sound_name in sounds:
		var def: Dictionary = sounds[sound_name]
		var stream: AudioStream = load(str(def.get("file", "")))
		if stream == null:
			push_warning("Sfx: cannot load sound '%s'" % sound_name)
			continue
		_streams[sound_name] = stream
		_defs[sound_name] = def
	for i in range(int(Config.get_value("audio", "pool_size", 8))):
		var player := AudioStreamPlayer.new()
		add_child(player)
		_pool.append(player)
	_music = AudioStreamPlayer.new()
	_music.volume_db = float(Config.get_value("audio", "music_volume_db", -12.0))
	_music.stream = _load_music()
	add_child(_music)


## Plays a sound; strength (e.g. ball speed) makes weak events softer, relative to full_at.
func play(sound_name: String, strength: float = -1.0) -> void:
	if not Settings.sound_on or not _streams.has(sound_name):
		return
	var def: Dictionary = _defs[sound_name]
	var player := _pool[_next]
	_next = (_next + 1) % _pool.size()
	player.stream = _streams[sound_name]
	var jitter := float(def.get("pitch_jitter", 0.0))
	player.pitch_scale = 1.0 + randf_range(-jitter, jitter)
	var loudness := 1.0
	if strength >= 0.0:
		loudness = clampf(strength / maxf(0.01, float(def.get("full_at", 1.0))),
			float(Config.get_value("audio", "min_volume", 0.15)), 1.0)
	player.volume_db = float(def.get("volume_db", 0.0)) + linear_to_db(loudness)
	player.play()


## Plays the sound mapped to a match event kind (audio.json -> event_sounds).
func play_event(kind: String, strength: float) -> void:
	if kind == "ground" and strength < float(Config.get_value("audio", "min_ground_bounce_speed", 2.0)):
		return
	var mapping: Dictionary = Config.get_value("audio", "event_sounds", {})
	if mapping.has(kind):
		play(str(mapping[kind]), strength)


## Menus want music; the match only if music_in_match. Respects the Settings switch.
func want_music(on: bool) -> void:
	_music_wanted = on
	refresh_music()


func refresh_music() -> void:
	var should_play := _music_wanted and Settings.music_on and _music.stream != null
	if should_play and not _music.playing:
		_music.play()
	elif not should_play and _music.playing:
		_music.stop()


func _load_music() -> AudioStream:
	var path := str(Config.get_value("audio", "music_file", ""))
	if path.is_empty():
		return null
	var stream: AudioStream = load(path)
	if stream is AudioStreamWAV:
		var wav := stream as AudioStreamWAV
		wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
		wav.loop_begin = 0
		wav.loop_end = int(wav.get_length() * wav.mix_rate)
	return stream
