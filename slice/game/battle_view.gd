class_name BattleView
extends Node2D
## Draws a Combat core and turns taps into its commands. One tap previews
## (path and AP, or odds), a second commits. The action bar lives in main's
## interface layer and calls the public functions here.

signal changed
signal finished(outcome: String)

var c: Combat
var s: GameState
var ground: TileMapLayer
var sorted: Node2D
var overlay: Node2D
var camera: Camera2D
var nodes: Dictionary = {}     # unit id -> Node2D
var reach: Dictionary = {}
var preview_cell := Vector2i(-1, -1)
var selected_target := ""
var animating := false
var queue: Array = []
var vcam := ViewCam.new()
var rot := 0
var tiles: Dictionary = {}
var props_placed: Array = []   # [{node, cell}]
var log_lines: Array = []
var aimed := false
var floating: Array = []


func setup(state: GameState, combat: Combat) -> void:
	s = state
	c = combat
	ground = TileMapLayer.new()
	ground.tile_set = Gfx.make_tileset()
	add_child(ground)
	var rng := RandomNumberGenerator.new()
	rng.seed = 9
	var row := 2 if c.enc.get("tiles", "") == "concrete" else 1
	for y in c.size.y:
		for x in c.size.x:
			tiles[Vector2i(x, y)] = Vector2i(rng.randi() % 8, row if (x + y) % 5 != 0 else 3)
	_paint_ground()
	overlay = Node2D.new()
	overlay.z_index = 1
	overlay.draw.connect(_draw_overlay)
	add_child(overlay)
	sorted = Node2D.new()
	sorted.y_sort_enabled = true
	sorted.z_index = 2
	add_child(sorted)
	var props: Dictionary = c.enc.get("props", {})
	for kind in props:
		for cell in props[kind]:
			var slot: int = {"car": 0, "crate": 1, "tree": 2, "lamp": 3}[kind] + 4 * (rng.randi() % 8)
			var sp := Sprite2D.new()
			sp.texture = Gfx.canvas_tex("props")
			sp.region_enabled = true
			sp.region_rect = Rect2(slot % 8 * 256, 1024 + slot / 8 * 256, 256, 256)
			sp.offset = Vector2(0, -112)
			sp.position = cpos(Vector2i(int(cell[0]), int(cell[1])))
			sorted.add_child(sp)
			props_placed.append({"node": sp, "cell": Vector2i(int(cell[0]), int(cell[1]))})
	var cm := CanvasModulate.new()
	cm.color = Color(0.35, 0.38, 0.5) if c.night else Color(0.95, 0.93, 0.9)
	add_child(cm)
	for u in c.units:
		var n := Node2D.new()
		n.position = cpos(u["cell"])
		var layered: bool = u["role"] == "hero"
		var names: Array = ["layer_body", "layer_outfit", "layer_item"] if layered else [u["look"]]
		for tn in names:
			var sp := Sprite2D.new()
			sp.texture = Gfx.canvas_tex(tn)
			sp.hframes = 12
			sp.vframes = 8
			sp.offset = Vector2(0, -70)
			sp.frame = (6 if u["team"] == "party" else 2) * 12
			if tn == "layer_body":
				var tone := Heritage.tone(int(s.members["hero"].get("heritage", 0)))
				sp.material = Gfx.skin_material(tone[0], tone[1])
			n.add_child(sp)
		if c.night:
			var l := PointLight2D.new()
			l.texture = Gfx.light_tex()
			l.texture_scale = 2.2
			l.energy = 0.9
			l.color = Color(1, 0.85, 0.7)
			l.position = Vector2(0, -40)
			n.add_child(l)
		sorted.add_child(n)
		nodes[u["id"]] = n
	camera = Camera2D.new()
	vcam.camera = camera
	vcam.apply_zoom()
	camera.position = cpos(c.size / 2)
	add_child(camera)
	camera.make_current()
	_consume_events()
	_refresh()


func set_view(render_scale: float, screen_h: float) -> void:
	vcam.base_zoom = screen_h * render_scale / 1080.0 * 0.85
	vcam.apply_zoom()


func cpos(cell: Vector2i) -> Vector2:
	return ground.map_to_local(ViewCam.rot_cell(cell, rot, c.size.x, c.size.y))


func _paint_ground() -> void:
	ground.clear()
	for cell in tiles:
		ground.set_cell(ViewCam.rot_cell(cell, rot, c.size.x, c.size.y), 0, tiles[cell])


## Turn the fight map a quarter turn; waits for animations to finish.
func turn_view(dir: int) -> void:
	if animating:
		return
	rot = posmod(rot + dir, 4)
	_paint_ground()
	for pp in props_placed:
		pp["node"].position = cpos(pp["cell"])
	for u in c.units:
		if nodes.has(u["id"]):
			nodes[u["id"]].position = cpos(u["cell"])
	camera.position = cpos(c.size / 2)
	overlay.queue_redraw()


func zoom_view(f: float) -> void:
	vcam.zoom_by(f)


func recenter() -> void:
	camera.position = cpos(c.active()["cell"]) if c.outcome == "" else cpos(c.size / 2)


func _process(delta: float) -> void:
	if c == null:
		return
	var pts: Array = []
	for u in c.units:
		if nodes.has(u["id"]) and u["state"] == "ok":
			pts.append(nodes[u["id"]].position + Vector2(0, -50))
	if preview_cell.x >= 0:
		pts.append(cpos(preview_cell))
	var sprites: Array = []
	for pp in props_placed:
		sprites.append(pp["node"])
	ViewCam.fade_occluders(sprites, pts, delta)


func _refresh() -> void:
	reach = {}
	if c.is_player_turn() and not animating:
		reach = c.reach(c.active())
	for u in c.units:
		var n: Node2D = nodes[u["id"]]
		var gone: bool = u["state"] in ["fled", "dead"]
		n.visible = not gone
		n.modulate = Color(1, 1, 1, 0.45) if u["state"] in ["down", "surrendered", "treated"] else Color(1, 1, 1, 1)
		n.rotation = 1.2 if u["state"] == "down" else 0.0
	overlay.queue_redraw()
	changed.emit()


# ------------------------------------------------------------------ commands
func tap_cell(cell: Vector2i) -> void:
	if animating or not c.is_player_turn():
		return
	for u in c.units:
		if u["cell"] == cell and u["team"] == "foe" and u["state"] == "ok":
			if selected_target == u["id"]:
				do_attack(aimed)
			else:
				selected_target = u["id"]
				preview_cell = Vector2i(-1, -1)
				_refresh()
			return
	selected_target = ""
	if reach.has(cell):
		if preview_cell == cell:
			c.move(cell)
			preview_cell = Vector2i(-1, -1)
			_consume_events()
		else:
			preview_cell = cell
	else:
		preview_cell = Vector2i(-1, -1)
	_refresh()


func do_attack(aim: bool) -> void:
	if selected_target == "" or animating:
		return
	if c.attack(selected_target, aim):
		if c.unit(selected_target)["state"] != "ok":
			selected_target = ""
		_consume_events()


func do_call_out() -> void:
	if not animating:
		c.call_out()
		_consume_events()


func do_breath() -> void:
	if not animating and c.take_breath():
		_consume_events()


func do_end_turn() -> void:
	if animating:
		return
	selected_target = ""
	preview_cell = Vector2i(-1, -1)
	c.end_turn()
	_consume_events()


func do_parley() -> void:
	c.accept_parley()
	_consume_events()


func target_info() -> Dictionary:
	if selected_target == "" or not c.is_player_turn():
		return {}
	var t := c.unit(selected_target)
	var a := c.active()
	return {"name": t["name"], "quick": c.hit_chance(a, t, false), "aimed": c.hit_chance(a, t, true),
		"can_quick": c.can_attack(t, false), "can_aimed": c.can_attack(t, true),
		"melee": int(Combat.WEAPONS[a["weapon"]]["range"]) <= 1, "hp": t["hp"], "strain": t.get("strain", 0)}


# ------------------------------------------------------------------ animation
func _consume_events() -> void:
	queue.append_array(c.events)
	c.events.clear()
	if not animating:
		_next_event()


func _next_event() -> void:
	if queue.is_empty():
		animating = false
		_refresh()
		if c.outcome != "":
			finished.emit(c.outcome)
		return
	animating = true
	var e: Dictionary = queue.pop_front()
	match String(e["type"]):
		"move":
			var n: Node2D = nodes[e["unit"]]
			var tw := create_tween()
			var p: Array = e["path"]
			for i in range(1, p.size()):
				tw.tween_property(n, "position", cpos(p[i]), 0.12)
			tw.tween_callback(_next_event)
		"attack":
			var from: Node2D = nodes[e["from"]]
			var to: Node2D = nodes[e["to"]]
			_flash(from.position, e["ranged"])
			_float(to.position, ("%d!" % e["dmg"] if e["solid"] else str(e["dmg"])) if e["hit"] else "miss", Color(1, 0.3, 0.2) if e["hit"] else Color(0.9, 0.9, 0.9))
			var tw := create_tween()
			tw.tween_property(to, "modulate", Color(2, 0.6, 0.6) if e["hit"] else Color(1, 1, 1), 0.08)
			tw.tween_property(to, "modulate", Color(1, 1, 1), 0.2)
			tw.tween_interval(0.25)
			tw.tween_callback(_next_event)
		"text":
			log_lines.append(String(e["text"]))
			if log_lines.size() > 6:
				log_lines.pop_front()
			changed.emit()
			_next_event()
		_:
			var tw := create_tween()
			tw.tween_interval(0.15)
			tw.tween_callback(_next_event)


func _flash(p: Vector2, ranged: bool) -> void:
	if not ranged:
		return
	var l := PointLight2D.new()
	l.texture = Gfx.light_tex()
	l.color = Color(1, 0.8, 0.4)
	l.energy = 3.0
	l.texture_scale = 3.0
	l.position = p + Vector2(0, -60)
	add_child(l)
	var tw := create_tween()
	tw.tween_property(l, "energy", 0.0, 0.18)
	tw.tween_callback(l.queue_free)


func _float(p: Vector2, txt: String, col: Color) -> void:
	var lb := Label.new()
	lb.text = txt
	lb.add_theme_font_size_override("font_size", 34)
	lb.add_theme_color_override("font_color", col)
	lb.add_theme_constant_override("outline_size", 6)
	lb.add_theme_color_override("font_outline_color", Color.BLACK)
	lb.position = p + Vector2(-20, -200)
	lb.z_index = 10
	add_child(lb)
	var tw := create_tween()
	tw.tween_property(lb, "position:y", lb.position.y - 50, 0.7)
	tw.parallel().tween_property(lb, "modulate:a", 0.0, 0.7)
	tw.tween_callback(lb.queue_free)


# ------------------------------------------------------------------ input
func _unhandled_input(e: InputEvent) -> void:
	if not visible:
		return
	var g := vcam.handle(e)
	if g["turn"] != 0:
		turn_view(g["turn"])
		return
	if g["recenter"]:
		recenter()
		return
	if e is InputEventKey and e.pressed and not e.echo:
		match e.keycode:
			KEY_TAB:
				_cycle_target()
			KEY_F:
				do_attack(false)
			KEY_G:
				do_attack(true)
			KEY_C:
				do_call_out()
			KEY_B:
				do_breath()
			KEY_ENTER, KEY_SPACE:
				do_end_turn()
		return
	if g["tap"] == null:
		return
	var world := get_canvas_transform().affine_inverse() * (g["tap"] as Vector2)
	tap_cell(ViewCam.unrot_cell(ground.local_to_map(ground.to_local(world)), rot, c.size.x, c.size.y))


func _cycle_target() -> void:
	var foes: Array = []
	for u in c.units:
		if u["team"] == "foe" and u["state"] == "ok":
			foes.append(u["id"])
	if foes.is_empty():
		return
	var i := foes.find(selected_target)
	selected_target = foes[(i + 1) % foes.size()]
	_refresh()


func _draw_overlay() -> void:
	for cell in reach:
		_diamond(cell, Color(0.5, 0.9, 1.0, 0.35), false)
	for cell in c.cover:
		_diamond(cell, Color(0.9, 0.7, 0.2, 0.5) if int(c.cover[cell]) == 20 else Color(1.0, 0.45, 0.2, 0.6), false)
	if preview_cell.x >= 0:
		_diamond(preview_cell, Color(1, 0.9, 0.3, 0.95), true)
	if c.outcome == "" and not animating:
		_diamond(c.active()["cell"], Color(0.4, 1.0, 0.4, 0.9), true)
	if selected_target != "":
		var t := c.unit(selected_target)
		if not t.is_empty():
			_diamond(t["cell"], Color(1, 0.3, 0.2, 0.95), true)


func _diamond(cell: Vector2i, col: Color, outline: bool) -> void:
	var p := cpos(cell)
	var pts := PackedVector2Array([p + Vector2(0, -30), p + Vector2(62, 0), p + Vector2(0, 30), p + Vector2(-62, 0)])
	if outline:
		pts.append(p + Vector2(0, -30))
		overlay.draw_polyline(pts, col, 4.0)
	else:
		overlay.draw_colored_polygon(pts, col)
