extends SceneTree
## Headless check of the audio autoload's mix (scripts/audio.gd): the Music bus follows the player's Music slider
## (the dialogue duck rides on top of it; it used to be pinned to -5 dB every frame, the slider did nothing), and a
## one-shot sfx that is an .ogg plays and is freed when done (only .wav was expected: the cast crashed the call).
## godot --headless --path . -s tests/audio_test.gd


func _initialize() -> void:
	_run.call_deferred()


func _fail(msg: String) -> void:
	push_error("AUDIO FAIL: " + msg)
	quit(1)


func _run() -> void:
	if AudioServer.get_bus_index("Music") < 0:  # (Audio makes its buses only with sound: not headless)
		AudioServer.add_bus()
		AudioServer.set_bus_name(AudioServer.bus_count - 1, "Music")
	var mus := AudioServer.get_bus_index("Music")
	var audio: Node = load("res://scripts/audio.gd").new()
	root.add_child(audio)
	Settings.reset()
	for level in [0.5, 0.2, 1.0]:
		Settings.values["audio/music"] = level
		for i in 30:
			audio._process(1.0 / 60.0)
		var want := Settings.bus_db("music")
		if absf(AudioServer.get_bus_volume_db(mus) - want) > 0.1:
			return _fail("Music slider at %d%%: the bus is at %.1f dB, not %.1f" % [level * 100,
				AudioServer.get_bus_volume_db(mus), want])
	# an .ogg one-shot: plays, and goes when it's done (not left behind as a looping stream)
	audio.silent = false
	audio._cache["v:ogg_test"] = ["music_menu"]  # (_pick's variant list: an .ogg in place of sfx_*.wav)
	var p: Node = audio.sfx("ogg_test")
	if not p:
		return _fail("an .ogg sfx made no player")
	if not p.finished.is_connected(p.queue_free):
		return _fail("an .ogg one-shot isn't freed when it finishes")
	var ogg := AudioStreamOggVorbis.new()
	var wav := AudioStreamWAV.new()
	if audio._loops(ogg) or audio._loops(wav):
		return _fail("a plain stream counts as looping")
	ogg.loop = true
	wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
	if not audio._loops(ogg) or not audio._loops(wav):
		return _fail("a looping stream counts as a one-shot")
	audio.queue_free()
	await process_frame
	print("AUDIO OK")
	quit(0)
