extends Node
## Stopped Clocks slice: screen router, status bar, dialogue overlay, battle
## bar, saves and play-time telemetry. Rules live in core/; this file only
## shows state and sends commands (tech.md presentation layer).

const VERSION := "slice-4"
const SAVE_PATH := "user://slice_save.json"
const RENDER_SCALE := 0.67

var s: GameState
var container: SubViewportContainer
var vp: SubViewport
var world: Node2D = null
var ui_root: Control
var screen: Control
var status_bar: PanelContainer
var status_label: RichTextLabel
var menu_box: HBoxContainer
var overlay: Control
var toast_label: Label
var toast_t := 0.0
var battle_bar: PanelContainer
var view_bar: VBoxContainer
var bview: BattleView = null
var segment := "title"
var seg_t := 0.0
var dlg: Dialogue = null
var dlg_done: Callable
var screens: Screens
var dialogue_count := 0
var choice_count := 0
var auto_choose := false


func _ready() -> void:
	UI.setup()
	Engine.max_fps = 30
	container = SubViewportContainer.new()
	container.stretch = true
	container.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	add_child(container)
	vp = SubViewport.new()
	vp.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_LINEAR
	vp.handle_input_locally = true
	container.add_child(vp)
	var layer := CanvasLayer.new()
	layer.layer = 10
	add_child(layer)
	ui_root = Control.new()
	ui_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	ui_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui_root.theme = UI.theme
	layer.add_child(ui_root)
	screen = Control.new()
	screen.set_anchors_preset(Control.PRESET_FULL_RECT)
	screen.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui_root.add_child(screen)
	_build_status()
	battle_bar = PanelContainer.new()
	battle_bar.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	battle_bar.grow_vertical = Control.GROW_DIRECTION_BEGIN
	battle_bar.visible = false
	ui_root.add_child(battle_bar)
	# World camera buttons (also: pinch, twist, wheel, drag, Q/R, +/-, Home).
	view_bar = VBoxContainer.new()
	view_bar.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	view_bar.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	view_bar.offset_top = UI.dp(110)
	view_bar.offset_right = -UI.dp(8)
	view_bar.add_theme_constant_override("separation", UI.dp(4))
	view_bar.visible = false
	ui_root.add_child(view_bar)
	for spec in [["Turn\nleft", "turn", -1], ["Turn\nright", "turn", 1], ["+", "zoom", 1.25], ["-", "zoom", 0.8], ["Find\nme", "center", 0]]:
		var b := UI.button(spec[0], func() -> void: _view_cmd(spec[1], spec[2]), view_bar, 64)
		b.add_theme_font_size_override("font_size", UI.dp(14))
		b.modulate.a = 0.85
	overlay = Control.new()
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui_root.add_child(overlay)
	toast_label = Label.new()
	toast_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	toast_label.grow_horizontal = Control.GROW_DIRECTION_BOTH
	toast_label.position.y = UI.dp(70)
	toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	toast_label.add_theme_font_size_override("font_size", UI.dp(18))
	toast_label.add_theme_color_override("font_color", Color(1, 0.97, 0.88))
	toast_label.add_theme_constant_override("outline_size", UI.dp(6))
	toast_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	toast_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui_root.add_child(toast_label)
	get_viewport().size_changed.connect(_on_resize)
	screens = Screens.new(self)
	_on_resize()
	var args := OS.get_cmdline_user_args()
	if "--bot" in args:
		auto_choose = true
	for a in args:
		if a.begins_with("--shot="):
			_shot_later(a.substr(7))
	show_title()


func _shot_later(spec: String) -> void:
	# Agent check: --shot=<scene>:<path>, scenes: family, planner, court, tvhwy, battle, worldmap, summary
	var parts := spec.split(":", true, 1)
	await get_tree().create_timer(0.5).timeout
	screens.debug_scene(parts[0])
	if parts[0] != "court" and dlg != null:
		# The week-1 cookout opener sits over every debug scene; drop it quietly.
		UI.clear(overlay)
		overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
		dlg = null
	await get_tree().create_timer(2.5).timeout
	if OS.has_environment("TURN") and world != null and world.has_method("turn_view"):
		var bad := 0
		for k in int(OS.get_environment("TURN")):
			world.turn_view(1)
		await get_tree().process_frame
		if world is Explore:
			var ex: Explore = world
			for cy in range(0, ex.size.y, 3):
				for cx in range(0, ex.size.x, 3):
					var cc := Vector2i(cx, cy)
					var sp: Vector2 = ex.get_canvas_transform() * ex.cell_pos(cc)
					if ex._screen_to_cell(sp) != cc:
						bad += 1
		print("TURNTEST rot=", world.rot, " tap_mismatches=", bad)
		await get_tree().create_timer(1.0).timeout
	if OS.has_environment("GESTURE_TEST") and world is Explore:
		await _gesture_test()
	if OS.has_environment("DRAG_TEST"):
		await _drag_test()
	if OS.has_environment("SHOT_PROBE"):
		for sc in screen.find_children("*", "ScrollContainer", true, false):
			var bar: VScrollBar = sc.get_v_scroll_bar()
			print("PROBE scroll size=", sc.size, " pos=", sc.global_position, " bar max=", bar.max_value, " page=", bar.page, " visible=", bar.visible, " vmode=", sc.vertical_scroll_mode, " filter=", sc.mouse_filter)
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(parts[1])
	get_tree().quit()


func _on_resize() -> void:
	var sz := get_viewport().get_visible_rect().size
	container.position = Vector2.ZERO
	container.scale = Vector2.ONE / RENDER_SCALE
	container.size = sz * RENDER_SCALE
	if world != null and world.has_method("set_view"):
		world.set_view(RENDER_SCALE, sz.y)


# ------------------------------------------------------------------ drag scrolling
## Drag anywhere on a scrolling page (finger, pen or mouse) to scroll it, even when
## the drag starts on a button. A drag past the threshold cancels that button's tap.
var _drag_sc: ScrollContainer = null
var _drag_from := Vector2.ZERO
var _drag_start_scroll := 0
var _drag_active := false
var _drag_buttons: Array = []


func _input(e: InputEvent) -> void:
	if e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT:
		if e.pressed:
			_drag_sc = null
			_drag_active = false
			_drag_buttons = []
			# Topmost scrollable page under the pointer: the overlay first, then the screen.
			for root in [overlay, screen]:
				var found: Array = root.find_children("*", "ScrollContainer", true, false)
				found.reverse()
				for sc in found:
					if sc.is_visible_in_tree() and sc.get_global_rect().has_point(e.position) and sc.get_v_scroll_bar().max_value > sc.size.y + 1.0:
						_drag_sc = sc
						break
				if _drag_sc != null:
					break
			if _drag_sc != null:
				_drag_from = e.position
				_drag_start_scroll = _drag_sc.scroll_vertical
				for b in _drag_sc.find_children("*", "BaseButton", true, false):
					if b.is_visible_in_tree() and b.get_global_rect().has_point(e.position):
						_drag_buttons.append(b)
		else:
			if _drag_active:
				# Swallow the tap: a disabled button ignores this release.
				for b in _drag_buttons:
					if is_instance_valid(b) and not b.disabled:
						b.disabled = true
						(func() -> void:
							if is_instance_valid(b):
								b.disabled = false).call_deferred()
			_drag_sc = null
			_drag_active = false
	elif e is InputEventMouseMotion and _drag_sc != null and is_instance_valid(_drag_sc):
		var dy: float = e.position.y - _drag_from.y
		if not _drag_active and absf(dy) > UI.dp(14):
			_drag_active = true
		if _drag_active:
			var sc := _drag_sc
			var target := int(_drag_start_scroll - dy)
			# Deferred so it lands after any scrolling the container did itself.
			(func() -> void:
				if is_instance_valid(sc):
					sc.scroll_vertical = target).call_deferred()


func _process(delta: float) -> void:
	if s != null and segment != "title":
		s.telemetry[segment] = float(s.telemetry.get(segment, 0.0)) + delta
	if toast_t > 0.0:
		toast_t -= delta
		toast_label.modulate.a = clampf(toast_t, 0.0, 1.0)


func toast(t: String, secs: float = 3.5) -> void:
	toast_label.text = t
	toast_t = secs
	toast_label.modulate.a = 1.0


func set_segment(seg: String) -> void:
	segment = seg


# ------------------------------------------------------------------ status bar
func _build_status() -> void:
	status_bar = PanelContainer.new()
	status_bar.set_anchors_preset(Control.PRESET_TOP_WIDE)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.12, 0.1, 0.08, 0.88)
	sb.set_content_margin_all(UI.dp(6))
	status_bar.add_theme_stylebox_override("panel", sb)
	var h := UI.hbox(status_bar)
	status_label = UI.rich("", h, 15)
	status_label.add_theme_color_override("default_color", Color(0.95, 0.9, 0.78))
	status_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	menu_box = UI.hbox(h, 6)
	UI.button("Ledger", func() -> void: screens.show_ledger(), menu_box, 80)
	UI.button("Family", func() -> void: screens.show_family_sheet(), menu_box, 80)
	UI.button("Journal", func() -> void: screens.show_journal(), menu_box, 80)
	UI.button("Save", func() -> void: save_game(); toast("Saved."), menu_box, 70)
	status_bar.visible = false
	ui_root.add_child(status_bar)


func refresh_status() -> void:
	if s == null:
		return
	status_bar.visible = true
	var hb := s.strain_band("hero")
	var band_name: String = ["Steady", "Frayed", "Shaken", "Unmoored"][hb]
	var t := ""
	if s.phase == "act0" or s.phase == "family":
		t = "[b]Week %d[/b] %s · %d blocks left · $%d (card $%d) · Profile %d %s · Buy-in %d %s · %s %s" % [
			s.week, Screens.week_dates(s.week), Act0.blocks_left(s), s.money, s.card, s.profile, Act0.profile_tier(s.profile),
			s.buyin_avg(), Act0.buyin_tier(s.buyin_avg()), s.members["hero"]["name"], band_name]
	else:
		t = "[b]Day %d · %s[/b] · moon %s · food %d · water %d · heat %d · inhalers %d · Profile %d %s · %s %s (%d)" % [
			s.day, Act1.WATCH_NAMES[s.watch], Act1.moon(s.day), s.led("food"), s.led("water") + s.led("heater_water"), s.led("heat"),
			s.led("inhalers"), s.profile, Act0.profile_tier(s.profile), s.members["hero"]["name"], band_name, int(s.members["hero"]["strain"])]
	status_label.text = t


# ------------------------------------------------------------------ world hosting
func clear_world() -> void:
	if world != null:
		world.queue_free()
		world = null
	bview = null
	battle_bar.visible = false
	view_bar.visible = false


func host_world(n: Node2D) -> void:
	clear_world()
	world = n
	vp.add_child(n)
	view_bar.visible = n.has_method("turn_view")
	_on_resize()


func _view_cmd(kind: String, arg: Variant) -> void:
	if world == null or not world.has_method("turn_view"):
		return
	match kind:
		"turn":
			world.turn_view(int(arg))
		"zoom":
			world.zoom_view(float(arg))
		"center":
			world.recenter()


func clear_screen() -> void:
	UI.clear(screen)


# ------------------------------------------------------------------ dialogue
func run_dialogue(id: String, on_done: Callable, extra: Dictionary = {}) -> void:
	dlg = Dialogue.new(s, id)
	dlg.extra = extra
	dlg_done = on_done
	dialogue_count += 1
	_pending_events = []
	_pending_events.append_array(dlg._flush())
	_show_dialogue()


var _pending_events: Array = []


func _show_dialogue() -> void:
	UI.clear(overlay)
	if dlg == null:
		return
	if dlg.done():
		_close_dialogue()
		return
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	var shade := ColorRect.new()
	shade.color = Color(0, 0, 0, 0.35)
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(shade)
	var m := MarginContainer.new()
	m.set_anchors_preset(Control.PRESET_FULL_RECT)
	var sz := get_viewport().get_visible_rect().size
	var side := maxi(UI.dp(12), int((sz.x - UI.dp(900)) / 2))
	m.add_theme_constant_override("margin_left", side)
	m.add_theme_constant_override("margin_right", side)
	m.add_theme_constant_override("margin_top", UI.dp(60))
	m.add_theme_constant_override("margin_bottom", UI.dp(12))
	overlay.add_child(m)
	var p := UI.panel(m)
	p.size_flags_vertical = Control.SIZE_SHRINK_END
	var v := UI.vbox(p, 10)
	UI.label(dlg.speaker(), v, 20, UI.ACCENT)
	var sc := UI.scroll(v)
	sc.custom_minimum_size.y = mini(UI.dp(360), int(sz.y * 0.42))
	var body := UI.rich(dlg.text(), sc, 17)
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var opts := dlg.options()
	var first: Button = null
	for o in opts:
		var tx: String = o["text"]
		if o["label"] != "":
			tx += "\n" + String(o["label"])
		var b := UI.button(tx, _choose.bind(int(o["index"])), v)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.disabled = not o["enabled"]
		if first == null and not b.disabled:
			first = b
	if first != null:
		first.grab_focus.call_deferred()
	refresh_status()
	if auto_choose:
		_bot_pick.call_deferred(opts)


func _bot_pick(opts: Array) -> void:
	for o in opts:
		if o["enabled"]:
			_choose(int(o["index"]))
			return


func _choose(index: int) -> void:
	if dlg == null:
		return
	choice_count += 1
	_pending_events.append_array(dlg.choose(index))
	_show_dialogue()


func _close_dialogue() -> void:
	UI.clear(overlay)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dlg = null
	var cb := dlg_done
	var evs := _pending_events
	_pending_events = []
	save_game()
	run_events(evs, cb)


## Process presentation events in order, then call cb.
func run_events(evs: Array, cb: Callable) -> void:
	if evs.is_empty():
		refresh_status()
		if cb.is_valid():
			cb.call()
		return
	var e: Array = evs.pop_front()
	var rest := func() -> void: run_events(evs, cb)
	match String(e[0]):
		"battle":
			start_battle(String(e[1]), rest)
		"garage":
			screens.show_garage(rest)
		"gear":
			screens.show_gear(rest)
		"flash_report":
			screens.show_flash_report(rest)
		"end_act":
			screens.show_summary()
		_:
			rest.call()


# ------------------------------------------------------------------ battle
var _battle_done: Callable


func start_battle(enc_id: String, on_done: Callable) -> void:
	_battle_done = on_done
	var prev_seg := segment
	var c := Combat.new(s, enc_id)
	var bv := BattleView.new()
	host_world(bv)
	bview = bv
	bv.setup(s, c)
	bv.set_view(RENDER_SCALE, get_viewport().get_visible_rect().size.y)
	bv.changed.connect(_refresh_battle_bar)
	bv.finished.connect(func(outcome: String) -> void: _battle_over(c, outcome, prev_seg))
	battle_bar.visible = true
	clear_screen()
	_refresh_battle_bar()
	toast("Fight: %s. Tap a tile to see the move, tap again to go. Tap a foe for odds." % c.enc["name"], 5.0)
	if auto_choose:
		_bot_battle.call_deferred()


func _bot_battle() -> void:
	while bview != null and bview.c.outcome == "":
		await get_tree().create_timer(0.05).timeout
		if bview == null:
			return
		if bview.animating or not bview.c.is_player_turn():
			continue
		var c := bview.c
		var a := c.active()
		var best := ""
		var bh := 0
		for u in c.units:
			if u["team"] == "foe" and u["state"] == "ok" and c.can_attack(u, false) and c.hit_chance(a, u, false) > bh:
				bh = c.hit_chance(a, u, false)
				best = u["id"]
		if best != "":
			bview.selected_target = best
			bview.do_attack(false)
		elif a["role"] == "hero" and int(a["ap"]) >= 2 and int(s.flags.get("callouts_this_fight", 0)) == 0:
			bview.do_call_out()
		else:
			var moved := false
			var r := c.reach(a)
			var goal := Vector2i(-1, -1)
			for u in c.units:
				if u["team"] == "foe" and u["state"] == "ok":
					goal = u["cell"]
			if goal.x >= 0 and not r.is_empty():
				var bc := Vector2i(-1, -1)
				var bd := 999
				for cell in r:
					var dd := Combat.dist(cell, goal)
					if dd < bd:
						bd = dd
						bc = cell
				if bc.x >= 0 and bd < Combat.dist(a["cell"], goal):
					c.move(bc)
					bview._consume_events()
					moved = true
			if not moved:
				bview.do_end_turn()


func _refresh_battle_bar() -> void:
	UI.clear(battle_bar)
	if bview == null:
		return
	var c := bview.c
	var v := UI.vbox(battle_bar, 6)
	var top := UI.hbox(v)
	var a := c.active()
	var who := "%s · AP %d/%d · Health %d/%d" % [a["name"], a["ap"], a["ap_max"], a["hp"], a["hp_max"]] if c.is_player_turn() else "Their turn..."
	if a["team"] == "party" and a["role"] != "":
		who += " · Strain %d" % int(s.members[a["role"]]["strain"])
	who += " · %s · rounds %d · Round %d" % [Combat.WEAPONS[a["weapon"]]["name"] if a["team"] == "party" else "", s.led("rounds"), c.round_no]
	UI.label(who, top, 16)
	var log_l := UI.label("\n".join(bview.log_lines.slice(-3)), v, 14, Color(0.3, 0.25, 0.2))
	log_l.custom_minimum_size.y = UI.dp(40)
	var row := UI.hbox(v, 6)
	var ti := bview.target_info()
	if c.outcome == "" and c.is_player_turn():
		if not ti.is_empty():
			if ti["melee"]:
				var b := UI.button("Strike %s: %d%% (2 AP)" % [ti["name"], ti["quick"]], func() -> void: bview.do_attack(false), row, 150)
				b.disabled = not ti["can_quick"]
			else:
				var b1 := UI.button("Quick shot %s: %d%% (3 AP)" % [ti["name"], ti["quick"]], func() -> void: bview.do_attack(false), row, 150)
				b1.disabled = not ti["can_quick"]
				var b2 := UI.button("Aimed: %d%% (5 AP)" % ti["aimed"], func() -> void: bview.do_attack(true), row, 120)
				b2.disabled = not ti["can_aimed"]
		else:
			UI.label("Tap a foe to see the odds.", row, 15)
		if a["role"] == "hero":
			var dc := c.call_out_dc()
			var b3 := UI.button("Call Out (2 AP)\n%s" % Rules.gate_label(s, "negotiation", dc), func() -> void: bview.do_call_out(), row, 160)
			b3.disabled = int(a["ap"]) < 2 or s.strain_band("hero") >= 2
		var b4 := UI.button("Take a Breath (2 AP)", func() -> void: bview.do_breath(), row, 110)
		b4.disabled = int(a["ap"]) < 2 or c.breath_used.has(a["id"])
		UI.button("End turn", func() -> void: bview.do_end_turn(), row, 100)
	if c.parley_offered and c.outcome == "":
		UI.button("Accept Parley: let them go", func() -> void: bview.do_parley(), row, 160)


func _battle_over(c: Combat, outcome: String, prev_seg: String) -> void:
	battle_bar.visible = false
	segment = prev_seg
	var enc := c.enc
	var effects: Array = enc.get(outcome if outcome != "parley" else "parley", enc.get("win", []))
	if outcome == "lose":
		effects = enc.get("lose", [])
	screens.show_aftermath(c, outcome, func() -> void:
		Rules.apply(s, effects)
		c.write_back()
		save_game()
		if enc.has("after") and outcome != "lose":
			run_dialogue(enc["after"], _battle_done)
		elif _battle_done.is_valid():
			_battle_done.call())


# ------------------------------------------------------------------ saves
func save_game() -> void:
	if s == null:
		return
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f == null:
		return
	var d := s.to_dict()
	d["resume"] = screens.resume_point
	f.store_string(JSON.stringify(d))


func load_game() -> bool:
	if not FileAccess.file_exists(SAVE_PATH):
		return false
	var txt := FileAccess.get_file_as_string(SAVE_PATH)
	var parsed: Variant = JSON.parse_string(txt)
	if not parsed is Dictionary:
		return false
	s = GameState.from_dict(parsed)
	screens.resume_point = String(parsed.get("resume", ""))
	return true


# ------------------------------------------------------------------ flow
func show_title() -> void:
	clear_world()
	clear_screen()
	status_bar.visible = false
	segment = "title"
	var body := UI.page(screen, "")
	UI.label("COLLAPSE", body, 40, UI.ACCENT)
	UI.label("Stopped Clocks: vertical slice (%s)" % VERSION, body, 22)
	UI.rich("A gray-box build of the first 150 design minutes, condensed: the family screen, the Long Autumn's eight weeks, Day Zero, and Act 1 of Stopped Clocks (M1 Gather and M2 The Week After). Art and sound are placeholders. The game logs your real play time per segment and shows it at the end, so the plan's minute budgets can be checked against a person.", body, 16)
	UI.button("New game", func() -> void:
		s = GameState.new(int(Time.get_unix_time_from_system()) % 100000)
		screens.show_family_screen(), body, 240)
	if FileAccess.file_exists(SAVE_PATH):
		UI.button("Continue", func() -> void:
			if load_game():
				screens.resume()
			else:
				toast("That save could not be read."), body, 240)
	UI.label("Touch: tap once to preview, tap again to commit. Keyboard: arrows or WASD to move, E to use, Enter to choose. In fights: Tab target, F quick shot, G aimed, C Call Out, B breath, Enter end turn.", body, 14, Color(0.35, 0.3, 0.25))


## Agent check (DRAG_TEST=1 with --shot=family): drag from a button up 300 px.
func _drag_test() -> void:
	var sc: ScrollContainer = screen.find_children("*", "ScrollContainer", true, false)[0]
	var fired := [false]
	var btn: Button = null
	for b in sc.find_children("*", "Button", true, false):
		if b.is_visible_in_tree() and sc.get_global_rect().encloses(b.get_global_rect()) and b.text == "Roll" and b.get_global_rect().get_center().y > 500:
			btn = b
			break
	btn.pressed.connect(func() -> void: fired[0] = true)
	var p := btn.get_global_rect().get_center()
	var names_before: String = btn.get_parent().get_child(0).text if btn.get_parent().get_child(0) is LineEdit else ""
	for step in [["down", p], ["move", p + Vector2(0, -10)], ["move", p + Vector2(0, -150)], ["move", p + Vector2(0, -300)], ["up", p + Vector2(0, -300)]]:
		var ev: InputEvent
		if step[0] == "move":
			ev = InputEventMouseMotion.new()
			ev.button_mask = MOUSE_BUTTON_MASK_LEFT
		else:
			ev = InputEventMouseButton.new()
			ev.button_index = MOUSE_BUTTON_LEFT
			ev.pressed = step[0] == "down"
		ev.position = step[1]
		ev.global_position = step[1]
		Input.parse_input_event(ev)
		await get_tree().process_frame
		await get_tree().process_frame
	print("DRAGTEST scroll=", sc.scroll_vertical, " button_fired=", fired[0], " disabled_after=", btn.disabled)
	# A plain tap still works.
	fired[0] = false
	var q := btn.get_global_rect().get_center()
	for down in [true, false]:
		var ev2 := InputEventMouseButton.new()
		ev2.button_index = MOUSE_BUTTON_LEFT
		ev2.pressed = down
		ev2.position = q
		ev2.global_position = q
		Input.parse_input_event(ev2)
		await get_tree().process_frame
		await get_tree().process_frame
	print("DRAGTEST tap_fired=", fired[0], " name_before=", names_before)


func _touch(idx: int, p: Vector2, down: bool) -> void:
	var e := InputEventScreenTouch.new()
	e.index = idx
	e.position = p
	e.pressed = down
	Input.parse_input_event(e)


func _drag(idx: int, p: Vector2, rel: Vector2) -> void:
	var e := InputEventScreenDrag.new()
	e.index = idx
	e.position = p
	e.relative = rel
	Input.parse_input_event(e)


## Agent check (GESTURE_TEST=1 with --shot=court): pinch, twist, pan, tap.
func _gesture_test() -> void:
	UI.clear(overlay)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dlg = null
	var ex: Explore = world
	var c := Vector2(640, 420)
	var z0 := ex.vcam.user_zoom
	_touch(0, c - Vector2(100, 0), true)
	_touch(1, c + Vector2(100, 0), true)
	await get_tree().process_frame
	_drag(1, c + Vector2(200, 0), Vector2(100, 0))
	await get_tree().process_frame
	print("GESTURE pinch zoom ", z0, " -> ", ex.vcam.user_zoom)
	var r0 := ex.rot
	for k in 6:
		var a := deg_to_rad(10.0 * (k + 1))
		_drag(1, c + Vector2(cos(a), sin(a)) * 200.0, Vector2.ZERO)
		await get_tree().process_frame
	print("GESTURE twist rot ", r0, " -> ", ex.rot)
	_touch(1, c, false)
	_touch(0, c, false)
	await get_tree().process_frame
	var cam0 := ex.camera.position
	_touch(0, c, true)
	for k in 5:
		_drag(0, c + Vector2(20 * (k + 1), 0), Vector2(20, 0))
		await get_tree().process_frame
	_touch(0, c + Vector2(100, 0), false)
	await get_tree().process_frame
	print("GESTURE pan camera moved ", cam0.distance_to(ex.camera.position), " preview=", ex.preview_cell)
	_touch(0, c + Vector2(0, 60), true)
	await get_tree().process_frame
	_touch(0, c + Vector2(0, 60), false)
	await get_tree().process_frame
	print("GESTURE tap preview=", ex.preview_cell, " target=", not ex.pending_target.is_empty())
