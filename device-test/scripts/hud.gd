class_name Hud
extends CanvasLayer
## Interface at the planned bar: 48 dp touch targets, 16 sp body text
## (art.md, tech.md), plus the debug readout and test controls.

var main: Node
var d := 1.0
var root: Control
var readout: Label
var toast: Label
var toast_t := 0.0
var settings_panel: PanelContainer
var report_panel: PanelContainer
var report_text: RichTextLabel
var inv_panel: PanelContainer
var game_bar: Control
var battle_bar: Control
var log_box: RichTextLabel
var battle_info: Label
var aim_btn: Button
var auto_btn: Button
var mode_btn: Button
var test_btn: Button
var cycle_buttons: Dictionary = {}
var portrait_bars: Array[ProgressBar] = []


func dp(v: float) -> int:
	return int(round(v * d))


func setup(p_main: Node) -> void:
	main = p_main
	layer = 10
	d = clampf(DisplayServer.screen_get_dpi() / 160.0, 1.0, 4.0)
	root = Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.theme = _make_theme()
	add_child(root)
	_build_readout()
	_build_top_buttons()
	_build_game_bar()
	_build_battle_bar()
	_build_settings()
	_build_inventory()
	_build_report()
	toast = Label.new()
	toast.set_anchors_preset(Control.PRESET_CENTER_TOP)
	toast.position.y = dp(110)
	toast.add_theme_font_size_override("font_size", dp(16))
	toast.add_theme_constant_override("outline_size", dp(4))
	toast.add_theme_color_override("font_outline_color", Color.BLACK)
	toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	toast.grow_horizontal = Control.GROW_DIRECTION_BOTH
	root.add_child(toast)
	set_battle_mode(false)


func _make_theme() -> Theme:
	var th := Theme.new()
	th.default_font_size = dp(16)
	var panel := StyleBoxFlat.new()
	panel.bg_color = Color(0.09, 0.085, 0.07, 0.92)
	panel.border_color = Color(0.45, 0.38, 0.22)
	panel.set_border_width_all(dp(1.5))
	panel.set_corner_radius_all(dp(4))
	panel.set_content_margin_all(dp(8))
	th.set_stylebox("panel", "PanelContainer", panel)
	for state in ["normal", "hover", "pressed", "focus", "disabled"]:
		var sb := StyleBoxFlat.new()
		sb.bg_color = {"normal": Color(0.22, 0.2, 0.15), "hover": Color(0.3, 0.27, 0.18), "pressed": Color(0.45, 0.38, 0.2), "focus": Color(0.22, 0.2, 0.15), "disabled": Color(0.15, 0.15, 0.15)}[state]
		sb.border_color = Color(0.6, 0.5, 0.28)
		sb.set_border_width_all(dp(1))
		sb.set_corner_radius_all(dp(4))
		sb.set_content_margin_all(dp(6))
		th.set_stylebox(state, "Button", sb)
	th.set_color("font_color", "Button", Color(0.95, 0.88, 0.7))
	th.set_color("font_color", "Label", Color(0.92, 0.88, 0.78))
	th.set_color("default_color", "RichTextLabel", Color(0.85, 0.95, 0.8))
	var bar_bg := StyleBoxFlat.new()
	bar_bg.bg_color = Color(0.2, 0.05, 0.05)
	var bar_fg := StyleBoxFlat.new()
	bar_fg.bg_color = Color(0.3, 0.75, 0.3)
	th.set_stylebox("background", "ProgressBar", bar_bg)
	th.set_stylebox("fill", "ProgressBar", bar_fg)
	return th


func _button(text: String, cb: Callable, parent: Control) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(dp(48), dp(48))
	b.focus_mode = Control.FOCUS_NONE
	b.pressed.connect(cb)
	parent.add_child(b)
	return b


func _build_readout() -> void:
	var p := PanelContainer.new()
	p.position = Vector2(dp(6), dp(6))
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0, 0, 0, 0.6)
	sb.set_content_margin_all(dp(4))
	p.add_theme_stylebox_override("panel", sb)
	readout = Label.new()
	readout.add_theme_font_size_override("font_size", dp(11))
	readout.add_theme_color_override("font_color", Color(0.7, 1.0, 0.7))
	p.add_child(readout)
	root.add_child(p)


func _build_top_buttons() -> void:
	var box := HBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	box.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	box.position = Vector2(-dp(6), dp(6))
	box.add_theme_constant_override("separation", dp(6))
	mode_btn = _button("Battle", func() -> void: main.toggle_mode(), box)
	_button("Settings", func() -> void: settings_panel.visible = not settings_panel.visible, box)
	test_btn = _button("Run 3-min test", func() -> void: main.start_bench(), box)
	_button("Report", func() -> void: show_report(main.report), box)
	root.add_child(box)


func _build_game_bar() -> void:
	var p := PanelContainer.new()
	p.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	p.grow_vertical = Control.GROW_DIRECTION_BEGIN
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", dp(8))
	p.add_child(h)
	var names := ["Morgan", "Dana", "Tess", "Eli", "Walt", "Pilot"]
	var atlas_tex: Texture2D = load("res://assets/portraits.png")
	for i in names.size():
		var v := VBoxContainer.new()
		v.add_theme_constant_override("separation", dp(2))
		var b := Button.new()
		var at := AtlasTexture.new()
		at.atlas = atlas_tex
		at.region = Rect2(i * 128, 0, 128, 128)
		b.icon = at
		b.expand_icon = true
		b.custom_minimum_size = Vector2(dp(56), dp(56))
		b.focus_mode = Control.FOCUS_NONE
		b.pressed.connect(func() -> void: log_line("%s: \"Still here.\"" % names[i]))
		v.add_child(b)
		var bar := ProgressBar.new()
		bar.show_percentage = false
		bar.custom_minimum_size = Vector2(dp(56), dp(6))
		bar.value = 60 + i * 7
		v.add_child(bar)
		portrait_bars.append(bar)
		h.add_child(v)
	log_box = RichTextLabel.new()
	log_box.bbcode_enabled = true
	log_box.scroll_following = true
	log_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	log_box.custom_minimum_size = Vector2(dp(200), dp(64))
	log_box.add_theme_font_size_override("normal_font_size", dp(14))
	log_box.add_theme_font_size_override("bold_font_size", dp(14))
	h.add_child(log_box)
	var ap := Label.new()
	ap.text = "AP ●●●●●●●●\nDay 64 · 21:40\nRain, 6 °C"
	ap.add_theme_font_size_override("font_size", dp(14))
	h.add_child(ap)
	var g := GridContainer.new()
	g.columns = 2
	_button("Inventory", func() -> void: inv_panel.visible = not inv_panel.visible, g)
	_button("Map", func() -> void: log_line("Map is not part of this test."), g)
	_button("Save", func() -> void: main.do_save(), g)
	_button("Load", func() -> void: main.do_load(), g)
	h.add_child(g)
	game_bar = p
	root.add_child(p)
	log_line("Device test build. Drag to pan, pinch to zoom. Tap [b]Run 3-min test[/b] and keep the phone still.")


func _build_battle_bar() -> void:
	var p := PanelContainer.new()
	p.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	p.grow_vertical = Control.GROW_DIRECTION_BEGIN
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", dp(8))
	p.add_child(h)
	battle_info = Label.new()
	battle_info.custom_minimum_size = Vector2(dp(260), dp(56))
	battle_info.add_theme_font_size_override("font_size", dp(15))
	h.add_child(battle_info)
	var lb := RichTextLabel.new()
	lb.bbcode_enabled = true
	lb.scroll_following = true
	lb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lb.custom_minimum_size = Vector2(dp(200), dp(64))
	lb.add_theme_font_size_override("normal_font_size", dp(14))
	lb.add_theme_font_size_override("bold_font_size", dp(14))
	h.add_child(lb)
	aim_btn = _button("Aim (+2 AP)", func() -> void: main.battle.toggle_aim(), h)
	_button("End turn", func() -> void: main.battle.end_turn(), h)
	auto_btn = _button("Auto: off", func() -> void: main.toggle_auto(), h)
	battle_bar = p
	battle_bar.set_meta("log", lb)
	root.add_child(p)


func _build_settings() -> void:
	settings_panel = PanelContainer.new()
	settings_panel.set_anchors_preset(Control.PRESET_RIGHT_WIDE)
	settings_panel.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	settings_panel.offset_top = dp(62)
	settings_panel.offset_bottom = -dp(90)
	settings_panel.custom_minimum_size = Vector2(dp(230), 0)
	var sc := ScrollContainer.new()
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	settings_panel.add_child(sc)
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(v)
	for key in main.CYCLES.keys():
		var b := _button("", func() -> void: main.cycle_setting(key), v)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		cycle_buttons[key] = b
	_button("60-min soak test", func() -> void: main.start_soak(), v)
	_button("Stop test", func() -> void: main.stop_bench(), v)
	_button("Close", func() -> void: settings_panel.visible = false, v)
	settings_panel.visible = false
	root.add_child(settings_panel)
	refresh_settings()


func refresh_settings() -> void:
	for key in cycle_buttons.keys():
		cycle_buttons[key].text = "%s: %s" % [main.LABELS[key], main.fmt_setting(key)]


func _build_inventory() -> void:
	inv_panel = PanelContainer.new()
	inv_panel.set_anchors_preset(Control.PRESET_CENTER)
	inv_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	inv_panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	var v := VBoxContainer.new()
	inv_panel.add_child(v)
	var title := Label.new()
	title.text = "Household stores (mock, 40 slots)"
	v.add_child(title)
	var g := GridContainer.new()
	g.columns = 10
	var items := ["Water 4L", "Rice", "Beans", "Ibuprofen", "Inhaler", "Batteries", "Lantern", "Tarp", "Axe", "Radio"]
	for i in 40:
		var b := Button.new()
		b.custom_minimum_size = Vector2(dp(56), dp(48))
		b.text = items[i % items.size()] if i < 26 else ""
		b.add_theme_font_size_override("font_size", dp(11))
		b.clip_text = true
		b.focus_mode = Control.FOCUS_NONE
		g.add_child(b)
	v.add_child(g)
	_button("Close", func() -> void: inv_panel.visible = false, v)
	inv_panel.visible = false
	root.add_child(inv_panel)


func _build_report() -> void:
	report_panel = PanelContainer.new()
	report_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	report_panel.offset_left = dp(40)
	report_panel.offset_right = -dp(40)
	report_panel.offset_top = dp(20)
	report_panel.offset_bottom = -dp(20)
	var v := VBoxContainer.new()
	report_panel.add_child(v)
	report_text = RichTextLabel.new()
	report_text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	report_text.add_theme_font_size_override("normal_font_size", dp(12))
	report_text.selection_enabled = true
	v.add_child(report_text)
	var h := HBoxContainer.new()
	_button("Copy report", func() -> void:
		DisplayServer.clipboard_set(main.report)
		show_toast("Report copied. Paste it into the project thread."), h)
	_button("Close", func() -> void: report_panel.visible = false, h)
	v.add_child(h)
	report_panel.visible = false
	root.add_child(report_panel)


func show_report(text: String) -> void:
	report_text.text = text if text != "" else "No test run yet. Tap Run 3-min test."
	report_panel.visible = true


func set_battle_mode(on: bool) -> void:
	game_bar.visible = not on
	battle_bar.visible = on
	mode_btn.text = "World" if on else "Battle"
	inv_panel.visible = false


func log_line(t: String) -> void:
	log_box.append_text(t + "\n")
	if battle_bar != null and battle_bar.visible:
		(battle_bar.get_meta("log") as RichTextLabel).append_text(t + "\n")


func battle_log(t: String) -> void:
	(battle_bar.get_meta("log") as RichTextLabel).append_text(t + "\n")


func update_battle(b: Node) -> void:
	if b == null or b.units.is_empty():
		return
	var u: Dictionary = b.active()
	var txt := "Round %d · %s's turn\nHP %d/%d   AP %d/%d" % [b.round_no, u["name"], u["hp"], u["hp_max"], u["ap"], b.AP_MAX]
	if u["team"] == "party" and not b.auto_play:
		txt += "\nTap a tile to move, a raider to shoot"
	battle_info.text = txt
	aim_btn.text = "Aim: ON" if b.aiming else "Aim (+2 AP)"
	auto_btn.text = "Auto: on" if b.auto_play else "Auto: off"


func show_toast(t: String, secs := 4.0) -> void:
	toast.text = t
	toast_t = secs


func _process(delta: float) -> void:
	readout.text = main.metrics.overlay_text() + main.bench_status()
	if toast_t > 0:
		toast_t -= delta
		if toast_t <= 0:
			toast.text = ""
	for i in portrait_bars.size():
		portrait_bars[i].value = 55 + 35 * (0.5 + 0.5 * sin(Time.get_ticks_msec() / 2000.0 + i))
