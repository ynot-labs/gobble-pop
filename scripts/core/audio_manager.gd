extends Node

## ASMR AudioManager with Pentatonic Combo Pitch-Climb + OGG/Procedural Fallback

const PENTATONIC_SEMITONES: Array[float] = [0.0, 2.0, 4.0, 7.0, 9.0, 12.0, 14.0, 16.0, 19.0]

var user_muted: bool = false
var ad_muted: bool = false
var bg_muted: bool = false

var _combo_step: int = 0
var _combo_reset_timer: float = 0.0
var _sfx_cache: Dictionary = {}
var _bgm_player: AudioStreamPlayer
var _sfx_pool: Array[AudioStreamPlayer] = []
var _pool_index: int = 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_bgm_player = AudioStreamPlayer.new()
	_bgm_player.volume_db = -10.0
	add_child(_bgm_player)

	for i in range(10):
		var p := AudioStreamPlayer.new()
		p.volume_db = -4.0
		add_child(p)
		_sfx_pool.append(p)

	PlatformBridge.visibility_changed.connect(_on_visibility_changed)
	_preload_audio_assets()
	call_deferred("_sync_from_game_manager")


func _sync_from_game_manager() -> void:
	if is_instance_valid(GameManager):
		if not GameManager.settings_changed.is_connected(_apply_mute_state):
			GameManager.settings_changed.connect(_apply_mute_state)
	_apply_mute_state()


func _process(delta: float) -> void:
	if _combo_reset_timer > 0.0:
		_combo_reset_timer -= delta
		if _combo_reset_timer <= 0.0:
			_combo_step = 0


func _preload_audio_assets() -> void:
	var files := {
		"pop_small": "res://assets/audio/sfx_01_pop.mp3",
		"pop_mid": "res://assets/audio/sfx_02_plop.mp3",
		"pop_boss": "res://assets/audio/sfx_03_gulp.mp3",
		"level_up": "res://assets/audio/sfx_04_level_up.mp3",
		"ice": "res://assets/audio/sfx_05_ice.mp3",
		"magnet": "res://assets/audio/sfx_06_magnet.mp3",
		"fever": "res://assets/audio/sfx_07_fever.mp3",
		"sticky": "res://assets/audio/sfx_08_sticky.mp3",
		"tick": "res://assets/audio/sfx_09_tick.mp3",
		"goal_done": "res://assets/audio/sfx_10_goal_done.mp3",
		"win": "res://assets/audio/sfx_11_win.mp3",
		"fail": "res://assets/audio/sfx_12_fail.mp3",
		"rv_blast": "res://assets/audio/sfx_13_rv_blast.mp3",
		"bgm": "res://assets/audio/bgm_01_marimba.mp3",
	}
	for key in files:
		if ResourceLoader.exists(files[key]):
			var st = load(files[key])
			if key == "bgm" and st is AudioStreamMP3:
				st.loop = true
			_sfx_cache[key] = st

	# Procedural fallback tones for M1 greybox before Phase 3 OGG synthesis
	if not _sfx_cache.has("pop_small"):
		_sfx_cache["pop_small"] = _make_pop_wav(523.25, 0.12, 1.45)
	if not _sfx_cache.has("pop_mid"):
		_sfx_cache["pop_mid"] = _make_pop_wav(349.23, 0.18, 1.25)
	if not _sfx_cache.has("pop_boss"):
		_sfx_cache["pop_boss"] = _make_pop_wav(196.0, 0.30, 0.85)
	if not _sfx_cache.has("level_up"):
		_sfx_cache["level_up"] = _make_arpeggio_wav([523.25, 659.25, 783.99, 1046.5], 0.09)
	if not _sfx_cache.has("ice"):
		_sfx_cache["ice"] = _make_pop_wav(1174.66, 0.24, 1.15)
	if not _sfx_cache.has("magnet"):
		_sfx_cache["magnet"] = _make_pop_wav(440.0, 0.26, 1.35)
	if not _sfx_cache.has("fever"):
		_sfx_cache["fever"] = _make_arpeggio_wav([587.33, 783.99, 987.77, 1174.66], 0.08)
	if not _sfx_cache.has("sticky"):
		_sfx_cache["sticky"] = _make_pop_wav(220.0, 0.20, 0.65)
	if not _sfx_cache.has("tick"):
		_sfx_cache["tick"] = _make_pop_wav(880.0, 0.08, 0.95)
	if not _sfx_cache.has("goal_done"):
		_sfx_cache["goal_done"] = _make_arpeggio_wav([783.99, 1046.5], 0.10)
	if not _sfx_cache.has("win"):
		_sfx_cache["win"] = _make_arpeggio_wav([523.25, 659.25, 783.99, 1046.5, 1318.5], 0.11)
	if not _sfx_cache.has("fail"):
		_sfx_cache["fail"] = _make_arpeggio_wav([440.0, 392.0, 329.63], 0.16)
	if not _sfx_cache.has("rv_blast"):
		_sfx_cache["rv_blast"] = _make_arpeggio_wav([392.0, 523.25, 659.25, 1046.5], 0.08)
	if not _sfx_cache.has("ui_click"):
		_sfx_cache["ui_click"] = _make_pop_wav(680.0, 0.06, 1.25)
	if not _sfx_cache.has("star_pop"):
		_sfx_cache["star_pop"] = _make_arpeggio_wav([783.99, 1046.5], 0.07)
	if not _sfx_cache.has("coin_get"):
		_sfx_cache["coin_get"] = _make_arpeggio_wav([987.77, 1318.5], 0.06)
	if not _sfx_cache.has("chest_open"):
		_sfx_cache["chest_open"] = _make_arpeggio_wav([523.25, 659.25, 783.99, 1046.5, 1567.98], 0.08)


func start_bgm() -> void:
	if _sfx_cache.has("bgm") and not _bgm_player.playing:
		_bgm_player.stream = _sfx_cache["bgm"]
		_bgm_player.play()
	_apply_mute_state()


func play_swallow(tier: int) -> void:
	_combo_reset_timer = 1.15
	var semi: float = PENTATONIC_SEMITONES[mini(_combo_step, PENTATONIC_SEMITONES.size() - 1)]
	_combo_step += 1
	var pitch := pow(2.0, semi / 12.0)

	if tier <= 1:
		play_sfx("pop_small", pitch)
	elif tier <= 3:
		play_sfx("pop_mid", clampf(pitch * 0.95, 0.85, 1.5))
	else:
		play_sfx("pop_boss", 1.0)


func play_sfx(key: String, pitch: float = 1.0) -> void:
	if _is_silenced() or not _sfx_cache.has(key):
		return
	if is_instance_valid(GameManager) and not GameManager.sfx_enabled:
		return
	var p := _sfx_pool[_pool_index]
	_pool_index = (_pool_index + 1) % _sfx_pool.size()
	p.stream = _sfx_cache[key]
	p.pitch_scale = pitch
	p.play()


func toggle_user_mute() -> bool:
	user_muted = not user_muted
	_apply_mute_state()
	return user_muted


func set_ad_muted(muted: bool) -> void:
	ad_muted = muted
	_apply_mute_state()


func _on_visibility_changed(is_visible: bool) -> void:
	bg_muted = not is_visible
	_apply_mute_state()


func _is_silenced() -> bool:
	return user_muted or ad_muted or bg_muted


func _apply_mute_state() -> void:
	AudioServer.set_bus_mute(0, _is_silenced())
	var bgm_on := true
	if is_instance_valid(GameManager):
		bgm_on = GameManager.bgm_enabled
	if _bgm_player:
		_bgm_player.volume_db = -10.0 if (bgm_on and not _is_silenced()) else -80.0


func _make_pop_wav(base_freq: float, dur: float, sweep_ratio: float) -> AudioStreamWAV:
	var rate := 22050
	var count := int(rate * dur)
	var data := PackedByteArray()
	data.resize(count * 2)
	var phase := 0.0
	for i in range(count):
		var t := float(i) / float(count)
		var freq := lerpf(base_freq, base_freq * sweep_ratio, t)
		phase += TAU * freq / float(rate)
		var env := sin(PI * minf(t / 0.12, 1.0)) * exp(-t * 6.5)
		var sample := int(clampf(sin(phase) * env * 0.65, -1.0, 1.0) * 32767.0)
		data.encode_s16(i * 2, sample)
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = rate
	wav.data = data
	return wav


func _make_arpeggio_wav(freqs: Array, note_dur: float) -> AudioStreamWAV:
	var rate := 22050
	var note_samples := int(rate * note_dur)
	var total := note_samples * freqs.size()
	var data := PackedByteArray()
	data.resize(total * 2)
	for n in range(freqs.size()):
		var f: float = freqs[n]
		for i in range(note_samples):
			var t := float(i) / float(note_samples)
			var env := minf(t * 15.0, 1.0) * exp(-t * 4.5)
			var s := (sin(TAU * f * float(i) / float(rate)) + 0.3 * sin(TAU * f * 2.0 * float(i) / float(rate))) * env * 0.55
			data.encode_s16((n * note_samples + i) * 2, int(clampf(s, -1.0, 1.0) * 32767.0))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = rate
	wav.data = data
	return wav
