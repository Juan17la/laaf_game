extends Node
## Autoload "Audio": music, sound effects and character voices. Every sound is synthesized by tools/make_audio.py
## into res://audio/ (music_*.wav, sfx_*.wav, voice_<who>_<0-7>.wav). Buses Master > Music / SFX / Voice are made here.
##   Audio.music("explore", 2.0)    crossfade to a loop ("menu" "explore" "chase" "safe" "melancholy" "boss"); "" stops
##   Audio.threat(true, enemy)      chase music while any source hunts the player; back to the base track after
##   Audio.push_music("boss") / pop_music()   a track over everything else (cinematics, boss bars) and back
##   Audio.sfx("door_open", pos?)   one-shot (variants `name_0..7` picked at random); returns the player (loops: stop it)
##   Audio.voice("Elena", "Hello")  dark Animal-Crossing-style babble, one blip per letter pair, paced to the line
## Headless runs (tests) never touch the audio server: calls only record `music_name` / `last_sfx` / `last_voice`.

const DIR := "res://audio/"
const LOOPS := ["generator", "harvester", "radio_static", "hiss"]
const VOICES := ["alex", "elena", "marcus", "owen", "nora", "julian", "shepherd", "lucia", "tomas", "grady", "silas",
	"tom", "pa", "radio", "patient", "marked", "boss", "moth"]
const ALIAS := {"dispatch": "radio", "marked one": "marked", "lucía": "lucia", "tomás": "tomas"}
const VOWEL_CLIP := {"a": 0, "e": 1, "o": 2, "i": 3, "u": 4, "s": 5, "k": 6, "t": 6, "p": 7}
const MAX_SFX := 28

var music_name := ""  ## what is (or, headless, would be) playing
var last_sfx := ""
var last_voice := ""
var silent := false  ## headless: record, don't play
var _base := ""  ## the track to return to when no one is hunting
var _threats := {}  ## instance id -> true
var _stack: Array[String] = []  ## pushed tracks (cinematics, boss bars), top wins
var _mus: Array[AudioStreamPlayer] = []
var _cur := 0
var _fade_tw: Tween
var _cache := {}
var _live := 0
var _voice_p: AudioStreamPlayer
var _vtext := ""
var _vi := 0
var _vt := 0.0
var _vstep := 0.055
var _vwho := ""
var _vletters := 0
var _vduck := 0.0
var _duck := 0.0
var _last_variant := {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	silent = DisplayServer.get_name() == "headless"
	if silent:
		set_process(false)
		return
	for b in ["Music", "SFX", "Voice"]:
		if AudioServer.get_bus_index(b) < 0:
			AudioServer.add_bus()
			var i := AudioServer.bus_count - 1
			AudioServer.set_bus_name(i, b)
			AudioServer.set_bus_send(i, "Master")
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Music"), -5.0)
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("SFX"), -2.0)
	var rv := AudioEffectReverb.new()
	rv.wet = 0.06
	rv.room_size = 0.5
	AudioServer.add_bus_effect(AudioServer.get_bus_index("SFX"), rv)
	for i in 2:
		var p := AudioStreamPlayer.new()
		p.bus = "Music"
		p.volume_db = -80.0
		add_child(p)
		_mus.append(p)
	_voice_p = AudioStreamPlayer.new()
	_voice_p.bus = "Voice"
	add_child(_voice_p)


# ------------------------------------------------------------------ loading

func _stream(name: String, loop := false) -> AudioStream:
	var key := name + ("#loop" if loop else "")
	if _cache.has(key):
		return _cache[key]
	var path := DIR + name + ".wav"
	var s: AudioStreamWAV = null
	if ResourceLoader.exists(path):
		s = load(path)
	elif FileAccess.file_exists(path):  # not imported yet: the generator's plain 16-bit mono PCM
		var f := FileAccess.open(path, FileAccess.READ)
		var bytes := f.get_buffer(f.get_length())
		s = AudioStreamWAV.new()
		s.format = AudioStreamWAV.FORMAT_16_BITS
		s.mix_rate = bytes.decode_u32(24)
		s.data = bytes.slice(44)
	if s and loop:
		s = s.duplicate()
		s.loop_mode = AudioStreamWAV.LOOP_FORWARD
		s.loop_begin = 0
		s.loop_end = s.data.size() / 2
	_cache[key] = s
	return s


func _pick(name: String) -> AudioStream:
	var vs: Array = _cache.get("v:" + name, [])
	if vs.is_empty() and not _cache.has("v:" + name):
		for i in 8:
			if ResourceLoader.exists("%ssfx_%s_%d.wav" % [DIR, name, i]) or FileAccess.file_exists("%ssfx_%s_%d.wav" % [DIR, name, i]):
				vs.append("sfx_%s_%d" % [name, i])
		if vs.is_empty():
			vs.append("sfx_" + name)
		_cache["v:" + name] = vs
	var k := randi() % vs.size()
	if vs.size() > 1 and k == _last_variant.get(name, -1):
		k = (k + 1) % vs.size()
	_last_variant[name] = k
	return _stream(vs[k], name in LOOPS)


# ------------------------------------------------------------------ music

func music(name: String, fade := 1.5) -> void:
	## Sets the base track. An active hunt overrides it with the chase music, a boss track and a pushed one override both.
	_base = name
	_apply(fade)


func stop_music(fade := 1.5) -> void:
	_base = ""
	_threats.clear()
	_stack.clear()
	_apply(fade)


func push_music(name: String, fade := 1.5) -> void:
	## Cinematics and boss fights: a track on top of whatever is going on; pop_music() puts things back.
	_stack.append("boss" if _target() == "boss" and name != "boss" else name)
	_apply(fade)


func pop_music(fade := 2.0) -> void:
	if not _stack.is_empty():
		_stack.pop_back()
	_apply(fade)


func threat(on: bool, source: Object) -> void:
	## An enemy started / stopped hunting the player. Chase music while any does.
	var id := source.get_instance_id()
	var was := not _threats.is_empty()
	if on:
		_threats[id] = true
	else:
		_threats.erase(id)
	if was != not _threats.is_empty():
		_apply(0.6 if on else 3.0)


func _target() -> String:
	if not _stack.is_empty():
		return _stack[-1]
	if _base == "boss":
		return "boss"
	return "chase" if not _threats.is_empty() else _base


func _apply(fade: float) -> void:
	_play(_target(), fade)


func _play(name: String, fade: float) -> void:
	if name == music_name:
		return
	music_name = name
	if silent:
		return
	var old := _mus[_cur]
	_cur = 1 - _cur
	var nw := _mus[_cur]
	if _fade_tw:
		_fade_tw.kill()
	_fade_tw = create_tween().set_parallel()
	_fade_tw.tween_property(old, "volume_db", -80.0, fade)
	_fade_tw.tween_callback(old.stop).set_delay(fade + 0.05)
	var s := _stream("music_" + name, true) if name != "" else null
	if s:
		nw.stream = s
		nw.volume_db = -80.0
		nw.play()
		_fade_tw.tween_property(nw, "volume_db", 0.0, fade)


func duck(db: float, hold := 2.0) -> void:
	## Dip the music under a stinger / big moment.
	_duck = db
	get_tree().create_timer(hold).timeout.connect(func() -> void: _duck = 0.0)


# ------------------------------------------------------------------ sfx

func sfx(name: String, at: Variant = null, volume_db := 0.0, pitch := 1.0, bus := "SFX") -> Node:
	## One-shot (or loop, see LOOPS). `at`: Vector3 / Node3D for positional sound, null for flat. Returns the player.
	## `bus`: "SFX", or "Voice" for things that are heard rather than happen (the Mark's whispers).
	last_sfx = name
	if silent or _live >= MAX_SFX:
		return null
	var s := _pick(name)
	if not s:
		return null
	var p: Node
	if at is Node3D and is_instance_valid(at):
		at = (at as Node3D).global_position
	var root := get_tree().current_scene
	if at is Vector3 and root:
		var p3 := AudioStreamPlayer3D.new()
		p3.bus = bus
		p3.unit_size = 7.0
		p3.max_distance = 55.0
		p3.volume_db = volume_db
		p3.pitch_scale = pitch
		p3.stream = s
		root.add_child(p3)
		p3.global_position = at
		p3.play()
		p = p3
	else:
		var p2 := AudioStreamPlayer.new()
		p2.bus = bus
		p2.volume_db = volume_db
		p2.pitch_scale = pitch
		p2.stream = s
		add_child(p2)
		p2.play()
		p = p2
	_live += 1
	p.tree_exited.connect(func() -> void: _live -= 1)
	if not (s as AudioStreamWAV).loop_mode == AudioStreamWAV.LOOP_FORWARD:
		p.finished.connect(p.queue_free)
	return p


func attach(parent: Node3D, name: String, volume_db := 0.0) -> Node:
	## A looping positional sound that follows `parent` and goes with it (engines, gas, a generator).
	last_sfx = name
	var s := _pick(name) if not silent else null
	if not s:
		return null
	var p := AudioStreamPlayer3D.new()
	p.bus = "SFX"
	p.unit_size = 6.0
	p.max_distance = 45.0
	p.volume_db = volume_db
	p.stream = s
	parent.add_child(p)
	p.play()
	return p


func stop(player: Node) -> void:
	if player and is_instance_valid(player):
		player.queue_free()


const CAPTIONS := [  ## sound captions in the story ("BONG.", "Click.", "Kshhh…"): [keyword, sfx, dB, pitch, seconds for a loop]
	["bong", "bell", 0.0, 1.0, 0.0], ["clang", "bell", -6.0, 1.6, 0.0], ["clunk", "thud", 0.0, 0.9, 0.0],
	["click", "pick_set", 0.0, 1.0, 0.0], ["tsss", "hiss", -4.0, 1.0, 1.4], ["kshhh", "radio_tune", -6.0, 1.0, 1.3],
	["bell rings", "bell", 0.0, 1.0, 0.0], ["doors bang", "door_slam", 0.0, 1.0, 0.0],
	["music box", "musicbox", 0.0, 0.8, 0.0], ["pencil ticks", "pick_set", -4.0, 0.9, 0.0],
	["gate grinds", "scrape", -2.0, 1.0, 0.0], ["car stalls", "scrape", -3.0, 0.7, 0.0], ["valve", "scrape", -4.0, 1.3, 0.0],
	["scissors slip", "pick_snap", -2.0, 0.8, 0.0], ["footsteps", "step_concrete", -2.0, 0.8, 0.0],
	["cage swings", "door_open", -2.0, 0.8, 0.0], ["skulls scatter", "glass", -4.0, 0.5, 0.0],
	["lantern gutters", "hiss", -10.0, 1.4, 0.7], ["rolls out of his hand", "thud", -2.0, 1.0, 0.0],
	["drops the body", "thud", 2.0, 0.6, 0.0], ["fans shudder", "generator", -4.0, 0.8, 2.0]]


func caption(text: String) -> void:
	## A narration line / banner that names a sound plays it.
	var t := text.to_lower()
	for c in CAPTIONS:
		if t.contains(c[0]):
			var p := sfx(c[1], null, c[2], c[3])
			if p and float(c[4]) > 0.0:
				get_tree().create_timer(c[4]).timeout.connect(stop.bind(p))
			return


func stinger(name: String, duck_db := -10.0) -> void:
	## "reveal" / "dread" / "boss": a hit with the music dipping under it.
	sfx("stinger_" + name)
	duck(duck_db, 3.0)


# ------------------------------------------------------------------ voices

func voice(who: String, text: String, time := -1.0) -> void:
	## Babble for one subtitle line. `time` (the line's on-screen time) paces it; without it ~18 letters/s.
	stop_voice()
	var key: String = ALIAS.get(who.to_lower(), who.to_lower())
	last_voice = key
	if silent or text == "" or not key in VOICES:
		return
	_vwho = key
	_vtext = text.to_lower()
	_vi = 0
	_vt = 0.0
	_vletters = 0
	_vstep = 0.055 if time <= 0.0 else clampf(time * 0.8 / maxf(text.length(), 1.0), 0.035, 0.08)
	set_process(true)


func stop_voice() -> void:
	_vtext = ""
	if _voice_p:
		_voice_p.stop()


func _process(delta: float) -> void:
	var mus := AudioServer.get_bus_index("Music")
	var target := _duck - (4.0 if _vtext != "" else 0.0)
	_vduck = lerpf(_vduck, target, minf(delta * 4.0, 1.0))
	AudioServer.set_bus_volume_db(mus, -5.0 + _vduck)
	if _vtext == "":
		return
	_vt -= delta
	while _vt <= 0.0 and _vi < _vtext.length():
		var c := _vtext[_vi]
		_vi += 1
		if c in ".!?":
			_vt += _vstep * 5.0
		elif c in ",;:—-…":
			_vt += _vstep * 3.0
		elif c == " ":
			_vt += _vstep * 0.6
		elif c.unicode_at(0) > 96 and c.unicode_at(0) < 123 or c.unicode_at(0) > 191:
			_vletters += 1
			_vt += _vstep
			if _vletters % 2 == 0:
				_blip(c)
	if _vi >= _vtext.length() and _vt <= -0.3:
		_vtext = ""


func _blip(c: String) -> void:
	var clip: int = VOWEL_CLIP.get(c, (c.unicode_at(0) + _vi) % 3 + 5)
	if c in "áàä":
		clip = 0
	elif c in "éè":
		clip = 1
	elif c in "íì":
		clip = 3
	elif c in "óò":
		clip = 2
	var s := _stream("voice_%s_%d" % [_vwho, clip])
	if not s:
		return
	_voice_p.stream = s
	var up := 1.12 if _vtext.ends_with("?") and _vi > _vtext.length() - 8 else 1.0
	_voice_p.pitch_scale = randf_range(0.93, 1.07) * up
	_voice_p.play()
