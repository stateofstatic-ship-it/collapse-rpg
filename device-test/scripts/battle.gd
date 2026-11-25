class_name Battle
extends Node2D
## Turn-based battle screen mock: 4 family members against 5 raiders on a
## 14x14 iso grid. Action points, move range, hit chance, enemy turns,
## muzzle-flash lights and floating numbers. Not balanced; it exists to
## measure the screen, not to be fun.

signal log_line(text: String)
signal state_changed

const N := 14
const AP_MAX := 8
const SHOT_AP := 4
const AIM_AP := 2

var ground: TileMapLayer
var sorted: Node2D
var overlay: Node2D
var camera: Camera2D
var units: Array[Dictionary] = []
var turn_order: Array[int] = []
var turn_i := 0
var aiming := false
var auto_play := false
var busy := false
var round_no := 1
var rng := RandomNumberGenerator.new()
var astar := AStarGrid2D.new()
var reach: Dictionary = {}
var wins := {"party": 0, "raiders": 0}


func build() -> void:
	rng.seed = 7
	ground = TileMapLayer.new()
	ground.tile_set = Gfx.make_tileset()
	add_child(ground)
	for y in N:
		for x in N:
			ground.set_cell(Vector2i(x, y), 0, Vector2i(rng.randi() % 8, 3 if (x + y) % 7 == 0 else 2))
	overlay = Node2D.new()
	overlay.draw.connect(_draw_overlay)
	add_child(overlay)
	sorted = Node2D.new()
	sorted.y_sort_enabled = true
	add_child(sorted)
	var cm := CanvasModulate.new()
	cm.color = Color(0.55, 0.55, 0.65)
	add_child(cm)
	# a few cover props
	for i in 10:
		var c := Vector2i(rng.randi_range(2, N - 3), rng.randi_range(4, N - 5))
		var s := Sprite2D.new()
		s.texture = Gfx.canvas_tex("props")
		s.region_enabled = true
		var slot := 1 + 4 * (i % 8)
		s.region_rect = Rect2(slot % 8 * 256, 1024 + slot / 8 * 256, 256, 256)
		s.offset = Vector2(0, -112)
		s.position = ground.map_to_local(c)
		sorted.add_child(s)
	camera = Camera2D.new()
	camera.position = ground.map_to_local(Vector2i(N / 2, N / 2))
	add_child(camera)
	astar.region = Rect2i(0, 0, N, N)
	astar.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_NEVER
	astar.update()
	reset()


func reset() -> void:
	for u in units:
		u["node"].queue_free()
	units.clear()
	var party := [["Morgan", "layer_body"], ["Dana", "char_medic"], ["Tess", "char_civilian"], ["Walt", "char_elder"]]
	for i in party.size():
		_add_unit(party[i][0], party[i][1], "party", Vector2i(2 + i * 2, N - 2), i == 0)
	for i in 5:
		_add_unit("Raider %d" % (i + 1), "char_raider" if i % 2 == 0 else "char_guard", "raiders", Vector2i(1 + i * 3, 1), false)
	turn_order.clear()
	for i in units.size():
		turn_order.append(i)
	turn_order.shuffle()
	turn_i = 0
	round_no = 1
	_begin_turn()


func _add_unit(n: String, look: String, team: String, c: Vector2i, layered: bool) -> void:
	var node := Node2D.new()
	sorted.add_child(node)
	var names: Array[String] = [look]
	if layered:
		names = ["layer_body", "layer_outfit", "layer_item"]
	for tn in names:
		var s := Sprite2D.new()
		s.texture = Gfx.canvas_tex(tn)
		s.hframes = 12
		s.vframes = 8
		s.offset = Vector2(0, -70)
		if tn == "layer_body":
			s.material = Gfx.skin_material(Color(0.3, 0.18, 0.12), Color(0.85, 0.65, 0.5))
		node.add_child(s)
	node.position = ground.map_to_local(c)
	var u := {"name": n, "team": team, "cell": c, "hp": 20, "hp_max": 20, "ap": AP_MAX, "node": node, "facing": 2 if team == "raiders" else 6}
	units.append(u)
	_set_frame(u, 0)
	astar.set_point_solid(c)


func _set_frame(u: Dictionary, f: int) -> void:
	for s in u["node"].get_children():
		if s is Sprite2D:
			s.frame = int(u["facing"]) * 12 + f


func active() -> Dictionary:
	return units[turn_order[turn_i]]


func _begin_turn() -> void:
	var u := active()
	if u["hp"] <= 0:
		_next_turn()
		return
	u["ap"] = AP_MAX
	aiming = false
	_compute_reach()
	state_changed.emit()
	if u["team"] == "raiders" or auto_play:
		_ai_turn.call_deferred()


func _next_turn() -> void:
	var alive := {"party": 0, "raiders": 0}
	for u in units:
		if u["hp"] > 0:
			alive[u["team"]] += 1
	if alive["party"] == 0 or alive["raiders"] == 0:
		var winner := "party" if alive["party"] > 0 else "raiders"
		wins[winner] += 1
		log_line.emit("[b]%s win the fight.[/b] New fight." % ("Family" if winner == "party" else "Raiders"))
		reset()
		return
	turn_i += 1
	if turn_i >= turn_order.size():
		turn_i = 0
		round_no += 1
	_begin_turn()


func end_turn() -> void:
	if busy:
		return
	_next_turn()


func _compute_reach() -> void:
	reach.clear()
	var u := active()
	var start: Vector2i = u["cell"]
	var frontier := [start]
	reach[start] = 0
	while not frontier.is_empty():
		var c: Vector2i = frontier.pop_front()
		var d: int = reach[c]
		if d >= int(u["ap"]):
			continue
		for o in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var n: Vector2i = c + o
			if astar.is_in_boundsv(n) and not astar.is_point_solid(n) and not reach.has(n):
				reach[n] = d + 1
				frontier.append(n)
	overlay.queue_redraw()


func _draw_overlay() -> void:
	if units.is_empty():
		return
	var u := active()
	var col := Color(0.3, 0.8, 1.0, 0.22) if u["team"] == "party" else Color(1, 0.3, 0.2, 0.15)
	for c in reach.keys():
		var p := ground.map_to_local(c)
		overlay.draw_colored_polygon(PackedVector2Array([p + Vector2(0, -30), p + Vector2(62, 0), p + Vector2(0, 30), p + Vector2(-62, 0)]), col)
	var p0 := ground.map_to_local(u["cell"])
	overlay.draw_polyline(PackedVector2Array([p0 + Vector2(0, -30), p0 + Vector2(62, 0), p0 + Vector2(0, 30), p0 + Vector2(-62, 0), p0 + Vector2(0, -30)]), Color(1, 0.9, 0.3), 4.0)


func hit_chance(a: Dictionary, b: Dictionary) -> int:
	var d := (a["cell"] as Vector2i - b["cell"] as Vector2i).length()
	var c := 85 - int(d * 5.0) + (20 if aiming else 0)
	return clampi(c, 5, 95)


func unit_at(c: Vector2i) -> int:
	for i in units.size():
		if units[i]["cell"] == c and units[i]["hp"] > 0:
			return i
	return -1


func _unhandled_input(e: InputEvent) -> void:
	var pressed: bool = (e is InputEventScreenTouch and e.pressed) or (e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT)
	if not pressed or busy or units.is_empty():
		return
	var u := active()
	if u["team"] != "party" or auto_play:
		return
	var wp := get_canvas_transform().affine_inverse() * (e.position as Vector2)
	var c := ground.local_to_map(wp)
	var t := unit_at(c)
	if t >= 0 and units[t]["team"] == "raiders":
		shoot(u, units[t])
	elif reach.has(c) and c != u["cell"]:
		move_to(u, c)
	get_viewport().set_input_as_handled()


func toggle_aim() -> void:
	aiming = not aiming
	state_changed.emit()


func move_to(u: Dictionary, c: Vector2i) -> void:
	astar.set_point_solid(u["cell"], false)
	var path := astar.get_id_path(u["cell"], c)
	astar.set_point_solid(u["cell"], true)
	if path.size() < 2:
		return
	path.remove_at(0)
	busy = true
	astar.set_point_solid(u["cell"], false)
	var tw := create_tween()
	var f := 0
	for step in path:
		if int(u["ap"]) <= 0:
			break
		u["ap"] -= 1
		var from_p: Vector2 = ground.map_to_local(u["cell"])
		var to_p := ground.map_to_local(step)
		var v := (to_p - from_p).normalized()
		u["facing"] = posmod(int(round(atan2(v.y * 2.0, v.x) / (PI / 4.0))), 8)
		var face: int = u["facing"]
		tw.tween_callback(func() -> void:
			u["facing"] = face
			f = (f + 3) % 12
			_set_frame(u, f))
		tw.tween_property(u["node"], "position", to_p, 0.16)
		u["cell"] = step
	astar.set_point_solid(u["cell"], true)
	await tw.finished
	_set_frame(u, 0)
	busy = false
	_compute_reach()
	state_changed.emit()


func shoot(a: Dictionary, b: Dictionary) -> void:
	var cost := SHOT_AP + (AIM_AP if aiming else 0)
	if int(a["ap"]) < cost:
		log_line.emit("%s lacks AP (%d needed)." % [a["name"], cost])
		return
	busy = true
	a["ap"] -= cost
	var chance := hit_chance(a, b)
	var v: Vector2 = (b["node"].position - a["node"].position).normalized()
	a["facing"] = posmod(int(round(atan2(v.y * 2.0, v.x) / (PI / 4.0))), 8)
	_set_frame(a, 0)
	var flash := PointLight2D.new()
	flash.texture = Gfx.light_tex()
	flash.color = Color(1, 0.8, 0.4)
	flash.energy = 3.0
	flash.texture_scale = 3.0
	flash.position = a["node"].position + Vector2(0, -60)
	add_child(flash)
	var roll := rng.randi_range(1, 100)
	var hit := roll <= chance
	var dmg := rng.randi_range(3, 8) if hit else 0
	if hit:
		b["hp"] = max(0, int(b["hp"]) - dmg)
	_float_text(b["node"].position + Vector2(0, -120), str(dmg) if hit else "miss", Color(1, 0.3, 0.2) if hit else Color(0.8, 0.8, 0.8))
	log_line.emit("%s shoots %s (%d%%): %s" % [a["name"], b["name"], chance, ("hit for %d" % dmg) if hit else "miss"])
	var tw := create_tween()
	tw.tween_property(flash, "energy", 0.0, 0.25)
	await tw.finished
	flash.queue_free()
	if int(b["hp"]) <= 0:
		b["node"].modulate = Color(0.4, 0.3, 0.3, 0.6)
		b["node"].rotation = 0.0
		astar.set_point_solid(b["cell"], false)
		log_line.emit("%s is down." % b["name"])
	aiming = false
	busy = false
	_compute_reach()
	state_changed.emit()


func _float_text(p: Vector2, text: String, col: Color) -> void:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 40)
	l.add_theme_color_override("font_color", col)
	l.add_theme_constant_override("outline_size", 8)
	l.add_theme_color_override("font_outline_color", Color.BLACK)
	l.position = p - Vector2(30, 0)
	l.z_index = 20
	add_child(l)
	var tw := create_tween()
	tw.tween_property(l, "position", l.position + Vector2(0, -60), 0.8)
	tw.parallel().tween_property(l, "modulate:a", 0.0, 0.8)
	tw.tween_callback(l.queue_free)


func _ai_turn() -> void:
	await get_tree().create_timer(0.25).timeout
	if not is_inside_tree():
		return
	var u := active()
	var guard := 0
	while int(u["ap"]) >= 1 and guard < 6:
		guard += 1
		var foe := -1
		var best := 1e9
		for i in units.size():
			if units[i]["team"] != u["team"] and int(units[i]["hp"]) > 0:
				var d := (units[i]["cell"] as Vector2i - u["cell"] as Vector2i).length()
				if d < best:
					best = d
					foe = i
		if foe < 0:
			break
		if best <= 7.0 and int(u["ap"]) >= SHOT_AP:
			await shoot(u, units[foe])
		elif int(u["ap"]) >= 1:
			var target: Vector2i = units[foe]["cell"]
			var dest: Vector2i = u["cell"]
			var dbest := 1e9
			for c in reach.keys():
				var dd := (c as Vector2i - target).length()
				if dd < dbest and dd >= 2.0:
					dbest = dd
					dest = c
			if dest == u["cell"]:
				break
			await move_to(u, dest)
		else:
			break
		if not is_inside_tree():
			return
	await get_tree().create_timer(0.15).timeout
	if is_inside_tree():
		_next_turn()


func set_view(render_scale: float, screen_h: float) -> void:
	camera.zoom = Vector2.ONE * screen_h * render_scale / 1080.0 * 0.95


func to_save() -> Dictionary:
	var us: Array = []
	for u in units:
		us.append({"name": u["name"], "team": u["team"], "cell": [u["cell"].x, u["cell"].y], "hp": u["hp"], "ap": u["ap"], "facing": u["facing"]})
	return {"units": us, "turn_order": turn_order, "turn_i": turn_i, "round": round_no, "rng_state": rng.state}


func from_save(d: Dictionary) -> void:
	if busy:
		return
	var us: Array = d["units"]
	for i in mini(us.size(), units.size()):
		var u := units[i]
		astar.set_point_solid(u["cell"], false)
		u["cell"] = Vector2i(us[i]["cell"][0], us[i]["cell"][1])
		u["hp"] = int(us[i]["hp"])
		u["ap"] = int(us[i]["ap"])
		u["facing"] = int(us[i]["facing"])
		u["node"].position = ground.map_to_local(u["cell"])
		u["node"].modulate = Color.WHITE if u["hp"] > 0 else Color(0.4, 0.3, 0.3, 0.6)
		if u["hp"] > 0:
			astar.set_point_solid(u["cell"], true)
		_set_frame(u, 0)
	turn_order.assign(d["turn_order"])
	turn_i = int(d["turn_i"])
	round_no = int(d["round"])
	rng.state = int(d["rng_state"])
	_compute_reach()
	state_changed.emit()
