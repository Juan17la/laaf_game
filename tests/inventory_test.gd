extends SceneTree
## Headless check of the inventory (scripts/inventory.gd, opened by scripts/game.gd):
##   Tab / I / the pad's Back open it over the paused game (the pause layer, the tree paused); the same keys, Esc and a
##   right click close it and the game goes on; M opens it on the Map tab; it won't open without control (a
##   cinematic, a minigame) or with Alex dead
##   it reads the live state: weapons with their rounds, bottles / smokes / teas, the gas mask's filter, tokens, key
##   parts, keepsakes, evidence x / 12, after picking things up and after a save is loaded into a fresh world
##   equipping from it puts the weapon (or the fists) in hand; drinking tea from it is the H key's drink (Mark -15%,
##   not with a clear Mark)
## godot --headless --path . -s tests/inventory_test.gd

const SLOT := "inventory_test_slot"

var g: Node


func _initialize() -> void:
	_run.call_deferred()


func _fail(msg: String) -> void:
	push_error("INVENTORY FAIL: " + msg)
	if g:
		g.resume()
	DirAccess.remove_absolute("user://saves/%s.sav" % SLOT)
	quit(1)


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _world(step: String) -> Node:
	var world: Node = load("res://maps/hollowmere.tscn").instantiate()
	world.get_node("Chapter1").start_step = step
	root.add_child(world)
	return world


func _action(name: String) -> void:
	for pressed in [true, false]:
		var e := InputEventAction.new()
		e.action = name
		e.pressed = pressed
		Input.parse_input_event(e)
		await process_frame


func _inv() -> InventoryMenu:
	var layer: Node = g.get("_pause")
	if not layer or not is_instance_valid(layer):
		return null
	for c in layer.get_children():
		if c is InventoryMenu:
			return c
	return null


func _names(inv: InventoryMenu, tab: String) -> Array:
	return inv.entries(tab).map(func(e: Dictionary) -> String: return e.id)


func _row(inv: InventoryMenu, tab: String, id: String) -> Dictionary:
	for e in inv.entries(tab):
		if e.id == id:
			return e
	return {}


func _run() -> void:
	g = G.game()
	if not g:
		g = load("res://scripts/game.gd").new()
		g.name = "Game"
		root.add_child(g)
	var world := _world("free")
	await _frames(60)
	var ch1: Chapter1Director = world.get_node("Chapter1")
	var player: CharacterBody3D = world.get_node("Player")
	g.director = ch1  # (the dev "free" step doesn't report in to Game: a story step would, Game.at_step)
	var w: Weapons = player.weapons
	w.owned.clear()  # (free hands out the revolver and the flare gun: start empty-handed instead)
	for id in w.loaded:
		w.loaded[id] = 0
		w.reserve[id] = 0
	w.current = 0

	# open / close: Tab (the inventory action), Esc, a right click; paused while it's up
	await _action("inventory")
	var inv := _inv()
	if not inv or not paused:
		return _fail("the inventory action didn't open it over a paused game (menu %s, paused %s)" % [inv, paused])
	if inv.tab != 0:
		return _fail("it should open on Weapons, not tab %d" % inv.tab)
	await _frames(2)
	await _action("inventory")
	if _inv() or paused:
		return _fail("pressing it again didn't close it and unpause")
	await _action("map")
	inv = _inv()
	if not inv or InventoryMenu.TABS[inv.tab][0] != "map":
		return _fail("M didn't open it on the Map tab")
	await _frames(2)
	await _action("ui_cancel")
	if _inv() or paused:
		return _fail("Esc didn't close it")
	await _action("inventory")
	inv = _inv()
	await _frames(2)
	var rc := InputEventMouseButton.new()
	rc.button_index = MOUSE_BUTTON_RIGHT
	rc.position = Vector2(20, 20)
	for pressed in [true, false]:
		rc.pressed = pressed
		inv._gui_input(rc)
	await _frames(2)
	if _inv() or paused:
		return _fail("a right click didn't close it")
	# never without control
	player.controls_enabled = false
	await _action("inventory")
	if _inv():
		return _fail("it opened during a cinematic / minigame (no control)")
	player.controls_enabled = true
	player.dead = true
	await _action("inventory")
	if _inv():
		return _fail("it opened with Alex dead")
	player.dead = false

	# what was picked up shows, with its numbers
	w.give("revolver", 20)
	w.give("bow", 5)
	player.bottles = 2
	player.smokes = 1
	player.teas = 1
	player.gas_mask = true
	player.mask_filter = 0.4
	ch1.flags.tokens = 35
	ch1.flags.key_part = true
	ch1.flags.lantern = true
	ch1.flags.evidence = [1, 11]
	await _action("inventory")
	inv = _inv()
	if _names(inv, "weapons") != ["", "revolver", "bow"]:
		return _fail("weapons rows %s" % [_names(inv, "weapons")])
	var rev := _row(inv, "weapons", "revolver")
	if rev.loaded != 6 or rev.reserve != 14:
		return _fail("revolver rounds %d · %d, not 6 · 14" % [rev.loaded, rev.reserve])
	for id in ["bottle", "smoke", "tea", "mask", "headlamp", "tokens"]:
		if _row(inv, "items", id).is_empty():
			return _fail("items lack %s: %s" % [id, _names(inv, "items")])
	if _row(inv, "items", "bottle").sub != "×2" or _row(inv, "items", "tokens").sub != "35":
		return _fail("item counts: bottles '%s' tokens '%s'" % [_row(inv, "items", "bottle").sub, _row(inv, "items", "tokens").sub])
	if _row(inv, "items", "mask").filter != 40:
		return _fail("the gas mask's filter reads %d%%, not 40%%" % _row(inv, "items", "mask").filter)
	if inv.key_parts() != 1 or _row(inv, "keys", "lantern").is_empty() or not _row(inv, "keys", "chapel_key").is_empty():
		return _fail("key items %s (parts %d)" % [_names(inv, "keys"), inv.key_parts()])
	if inv.evidence() != [1, 11]:
		return _fail("evidence %s" % [inv.evidence()])

	# equip from it: the bow, then the fists
	inv.select("weapons", 2)
	if not inv.use() or w.gun() != "bow":
		return _fail("equipping the bow from the inventory: holding '%s'" % w.gun())
	inv.select("weapons", 0)
	if not inv.use() or w.gun() != "":
		return _fail("equipping the fists from the inventory: holding '%s'" % w.gun())
	# tea: the hotkey's rules (not with a clear Mark), then Mark -15%
	player.mark = 0.0
	inv.select("items", _names(inv, "items").find("tea"))
	if inv.use() or player.teas != 1:
		return _fail("tea was drunk with a clear Mark")
	player.mark = 40.0
	if not inv.use() or player.teas != 0 or absf(player.mark - (40.0 - Feel.MARK_TEA)) > 0.01:
		return _fail("drinking tea from the inventory: teas %d, Mark %.1f" % [player.teas, player.mark])
	if not _row(inv, "items", "tea").is_empty():
		return _fail("the tea row stays with none left")
	inv.close()
	await _frames(2)

	# save → load into a fresh world: the same rows
	w.swap(w.owned.find("revolver"))
	if not g.save_game(SLOT, "Test"):
		return _fail("save_game failed")
	var s: Dictionary = g.load_save(SLOT)
	DirAccess.remove_absolute("user://saves/%s.sav" % SLOT)
	world.queue_free()
	await _frames(5)
	g.pending = s.duplicate(true)
	g.loading = true
	world = _world("intro")
	await _frames(60)
	player = world.get_node("Player")
	g.director = world.get_node("Chapter1")
	player.controls_enabled = true
	await _action("inventory")
	inv = _inv()
	if not inv:
		return _fail("no inventory after loading")
	if _names(inv, "weapons") != ["", "revolver", "bow"] or _row(inv, "weapons", "revolver").reserve != 14:
		return _fail("loaded weapons %s" % [_names(inv, "weapons")])
	if inv.entries("weapons")[inv._sel[0]].id != "revolver":
		return _fail("it doesn't open on the weapon in hand after loading")
	if _row(inv, "items", "bottle").sub != "×2" or not _row(inv, "items", "tea").is_empty() \
			or _row(inv, "items", "tokens").sub != "35":
		return _fail("loaded items %s" % [inv.entries("items")])
	if inv.evidence() != [1, 11] or inv.key_parts() != 1 or _row(inv, "keys", "lantern").is_empty():
		return _fail("loaded key items / evidence: %s %s" % [_names(inv, "keys"), inv.evidence()])
	# every tab draws (in either language) without errors
	for t in InventoryMenu.TABS.size():
		inv.set_tab(t)
		await _frames(2)
	inv.close()
	await _frames(2)
	world.queue_free()
	await _frames(3)
	print("INVENTORY OK")
	quit(0)
