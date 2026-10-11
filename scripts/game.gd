extends Node
## Autoload "Game": everything that outlives a scene. Difficulty, the save slots (autosaves at every mission
## step + manual saves from the pause menu), achievements (kept across runs), the run's stats (damage taken,
## time) and the pause menu. The main menu (scripts/main_menu.gd) starts a run through start(); the world's
## directors report in with at_step() and read `pending` (what to start: a step, maybe a save to restore).
## Only story runs (from the menu) autosave and unlock achievements: dev jumps and the headless tests don't.

signal achievement_unlocked(id: String)

const WORLD := "res://maps/hollowmere.tscn"
const MENU := "res://maps/main_menu.tscn"
const SAVE_DIR := "user://saves"
const AUTOSAVES := 6  ## autosave ring size (oldest overwritten)
const ACH_FILE := "user://achievements.cfg"
const DIFFICULTY := [  ## name, damage taken, enemy health, ammo in drops
	{"name": "Easy", "hurt": 0.6, "enemy": 0.75, "ammo": 1.5},
	{"name": "Normal", "hurt": 1.0, "enemy": 1.0, "ammo": 1.0},
	{"name": "Hard", "hurt": 1.5, "enemy": 1.3, "ammo": 0.67},
]
const ACHIEVEMENTS := {
	"ch1": ["The Woodsman", "Finish Chapter 1."],
	"ch2": ["Moth", "Finish Chapter 2."],
	"ch3": ["Pop. 1413", "Finish Chapter 3: the whole story."],
	"evidence": ["Paper Trail", "Collect all 12 pieces of evidence."],
	"keys": ["Three Pieces", "Hold all three parts of the gate key."],
	"untouched": ["Untouched", "Finish the game without taking any damage."],
	"mercy": ["Mercy", "Spare Owen, Nora, Julian and Marcus."],
	"hard": ["Nightmare", "Finish the game on Hard."],
	"arsenal": ["Arsenal", "Carry all six weapons."],
	"old_tom": ["Old Tom", "Catch the legendary catfish."],
	"candles": ["Empty Chairs", "Light a candle for all five families."],
	"cardsharp": ["House Always Loses", "Beat Silas at his own table."],
	"hands_on": ["Hands On", "Put an enemy down with a melee weapon or your fists."],
}

const STEP_MUSIC := {  ## base track per mission step (anything else: "explore"); enemies, bosses and cinematics override
	"intro": "melancholy", "room": "safe", "blackout": "melancholy", "c2_intro": "melancholy",
	"shepherd": "melancholy", "epilogue": "melancholy", "harvester": "boss"}

const STEP_MOOD := {"c2_intro": "overcast", "channel7": "overcast", "zones": "overcast"}  ## the rest: night

var difficulty := 1
var mode := ""  ## "story" (menu run: saves + achievements), "dev" (menu jump), "" (the world run directly)
var pending := {}  ## {"step": String} or a whole save dict (has "flags"), consumed by Chapter1Director
var loading := false  ## a save is being restored (the chapter directors rebuild earlier steps' state)
var run := {"damaged": false, "time": 0.0}
var director: Node  ## the chapter director running the current step
var dev_evidence := false  ## Dev Mode: runs start with all 12 pieces of evidence (Chapter1Director reads it)
var dev_mark := -1.0  ## Dev Mode: runs start with the Mark at this % (< 0: as the story has it)
var _unlocked := {}
var _check_t := 0.0
var _pause: CanvasLayer


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	DirAccess.make_dir_recursive_absolute(SAVE_DIR)
	var cfg := ConfigFile.new()
	if cfg.load(ACH_FILE) == OK:
		for id in cfg.get_section_keys("unlocked") if cfg.has_section("unlocked") else PackedStringArray():
			_unlocked[id] = cfg.get_value("unlocked", id)


# ------------------------------------------------------------------ runs

func start(step: String, run_mode: String, save := {}) -> void:
	## Into the world at `step` (or the save's step): "story" or "dev".
	mode = run_mode
	if run_mode != "dev":
		dev_evidence = false  # dev conveniences only: never in a story run
		dev_mark = -1.0
	pending = save.duplicate(true) if not save.is_empty() else {"step": step}
	loading = not save.is_empty()
	if loading:
		difficulty = int(save.get("difficulty", difficulty))
		run = (save.get("run", run) as Dictionary).duplicate(true)
		run.erase("veil_told")  # (older saves: the Veil's Eye note's once-a-run flag, gone with the eye)
	else:
		run = {"damaged": false, "time": 0.0}
	Enemy.reset_notes()  # "THEY ADAPT" notes are per run: a static outlives the last one
	get_tree().paused = false
	Snd.stop_music(0.5)  # drop pushed tracks / hunt flags from the previous run
	get_tree().change_scene_to_file(WORLD)


func to_menu() -> void:
	get_tree().paused = false
	if _pause:
		_pause.queue_free()
		_pause = null
	director = null
	mode = ""
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	Snd.stop_music(0.5)
	get_tree().change_scene_to_file(MENU)


func take_pending() -> Dictionary:
	var p := pending
	pending = {}
	return p


func settings() -> Dictionary:
	return DIFFICULTY[difficulty]


func at_step(d: Node) -> void:
	## A chapter director is starting a step: it's the one to save from; story runs autosave here.
	director = d
	loading = false
	Snd.music(STEP_MUSIC.get(str(d.step), "explore"), 2.5)
	if d.has_method("mood") and str(d.step) != "epilogue":  # (the epilogue's dawn() is its own look)
		d.mood(STEP_MOOD.get(str(d.step), "night"), 2.0)
	if mode == "story" and str(d.step) != "free":
		save_game(_next_autosave(), "Autosave")


func hurt(amount: float) -> void:
	if amount > 0.0:
		run.damaged = true


# ------------------------------------------------------------------ saves

func snapshot() -> Dictionary:
	## The whole run as it stands: step, flags, inventory, weapons, difficulty, stats.
	var d := director
	var p: Node = d.player
	var w: Weapons = p.weapons
	var chapter := 3 if d is Chapter3Director else (2 if d is Chapter2Director else 1)
	return {"version": 1, "time": Time.get_unix_time_from_system(), "chapter": chapter, "step": str(d.step),
		"difficulty": difficulty, "flags": (d.flags as Dictionary).duplicate(true), "run": run.duplicate(true),
		"label": "Ch.%d · %s" % [chapter, str(d.get("_objective_text")) if str(d.get("_objective_text")) != "" else str(d.step)],
		"player": {"health": p.health, "mark": p.mark, "bottles": p.bottles, "smokes": p.smokes, "teas": p.teas,
			"gas_mask": p.gas_mask, "mask_filter": p.mask_filter, "mark_resist": p.mark_resist},
		"weapons": {"owned": w.owned.duplicate(), "loaded": w.loaded.duplicate(), "reserve": w.reserve.duplicate(),
			"current": w.current}}


func restore_player(p: Node, save: Dictionary) -> void:
	## Inventory and weapons from a save (the step itself restarts from its beginning).
	for k in save.get("player", {}):
		p.set(k, save.player[k])
	var w: Weapons = p.weapons
	var sw: Dictionary = save.get("weapons", {})
	if not sw.is_empty():
		w.owned.assign(sw.owned)
		w.loaded = (sw.loaded as Dictionary).duplicate()
		w.reserve = (sw.reserve as Dictionary).duplicate()
		w.current = int(sw.current)
		w.changed.emit()


func save_game(slot: String, kind := "Save") -> bool:
	if not director or not is_instance_valid(director):
		return false
	var data := snapshot()
	data["kind"] = kind
	var f := FileAccess.open("%s/%s.sav" % [SAVE_DIR, slot], FileAccess.WRITE)
	if not f:
		return false
	f.store_var(data)
	if kind != "Autosave":  # autosaves stay silent: no stimulus for something the player didn't do
		notify("Saved.", "", 1.5)
	return true


func load_save(slot: String) -> Dictionary:
	var f := FileAccess.open("%s/%s.sav" % [SAVE_DIR, slot], FileAccess.READ)
	if not f:
		return {}
	var v: Variant = f.get_var()
	return v if v is Dictionary else {}


func saves() -> Array:
	## [[slot, save], ...] newest first.
	var out := []
	for file in DirAccess.get_files_at(SAVE_DIR):
		if file.ends_with(".sav"):
			var s := load_save(file.get_basename())
			if not s.is_empty():
				out.append([file.get_basename(), s])
	out.sort_custom(func(a: Array, b: Array) -> bool: return float(a[1].time) > float(b[1].time))
	return out


func _next_autosave() -> String:
	var oldest := "auto_0"
	var t := INF
	for i in AUTOSAVES:
		var s := load_save("auto_%d" % i)
		if s.is_empty():
			return "auto_%d" % i
		if float(s.time) < t:
			t = float(s.time)
			oldest = "auto_%d" % i
	return oldest


func manual_slot() -> String:
	var n := 0
	while FileAccess.file_exists("%s/manual_%d.sav" % [SAVE_DIR, n]):
		n += 1
	return "manual_%d" % n


# ------------------------------------------------------------------ achievements

func unlocked(id: String) -> bool:
	return _unlocked.has(id)


func unlock(id: String) -> void:
	if mode != "story" or _unlocked.has(id) or not ACHIEVEMENTS.has(id):
		return
	_unlocked[id] = Time.get_unix_time_from_system()
	var cfg := ConfigFile.new()
	cfg.load(ACH_FILE)
	cfg.set_value("unlocked", id, _unlocked[id])
	cfg.save(ACH_FILE)
	notify(ACHIEVEMENTS[id][0], "Achievement", 3.5)
	achievement_unlocked.emit(id)


func _process(delta: float) -> void:
	if not director or not is_instance_valid(director):
		return
	if not get_tree().paused:
		run.time += delta
	_check_t -= delta
	if _check_t > 0.0:
		return
	_check_t = 1.0
	var f: Dictionary = director.flags
	if (f.get("evidence", []) as Array).size() >= 12:
		unlock("evidence")
	if int(f.get("key_parts", 0)) >= 3:
		unlock("keys")
	if f.get("catfish", false):
		unlock("old_tom")
	if int(f.get("candles", 0)) >= 5:
		unlock("candles")
	if f.get("silas_rumor", false):
		unlock("cardsharp")
	var p: Node = director.player
	if p and (p.weapons.owned as Array).size() >= 6:
		unlock("arsenal")
	var ch := int(f.get("chapter", 0))
	if director is Chapter2Director or ch >= 1:
		unlock("ch1")
	if ch >= 2:
		unlock("ch2")
	if ch >= 3:
		unlock("ch3")
		if not run.damaged:
			unlock("untouched")
		if difficulty == 2:
			unlock("hard")
		if ["owen", "nora", "julian", "marcus"].all(func(m: String) -> bool: return f.get(m, "") == "spared"):
			unlock("mercy")


# ------------------------------------------------------------------ notes + pause menu

func notify(text: String, title := "", time := 4.0) -> void:
	## A paper note on the HUD (tips, achievements, saves).
	var p := get_tree().get_first_node_in_group("player")
	if p and p.get("hud") and p.hud.has_method("note"):
		p.hud.note(text, title, time)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause") and director and is_instance_valid(director):
		get_viewport().set_input_as_handled()
		if _pause:
			resume()
		else:
			_open_pause()


func resume() -> void:
	if _pause:
		_pause.queue_free()
		_pause = null
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _open_pause() -> void:
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_pause = CanvasLayer.new()
	_pause.layer = 50
	_pause.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_pause)
	var ui := MenuUI.panel(_pause, "PAUSED", "%s · %s" % [settings().name, _clock(run.time)])
	var p: Node = director.get("player")
	if p:  # the exact Mark (the HUD only flashes its rises)
		var mark := MenuUI.label("MARK  %.1f%%" % float(p.mark), 11, Feel.MARK_NOTICE_RED, true)
		mark.name = "Mark"
		ui.add_child(mark)
	MenuUI.button(ui, "Resume", resume)
	var can_save := mode != "" and director and bool(director.player.controls_enabled)
	var save := MenuUI.button(ui, "Save game", func() -> void:
		save_game(manual_slot(), "Manual save")
		resume())
	save.disabled = not can_save
	MenuUI.button(ui, "Main menu", to_menu)
	MenuUI.focus(ui)


static func _clock(t: float) -> String:
	return "%d:%02d:%02d" % [int(t / 3600.0), int(t / 60.0) % 60, int(t) % 60]
