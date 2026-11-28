class_name Explore
extends Node2D
## Local map: diamond tiles, Y-sorted props and people, tap once to preview a
## path or a target and tap again to commit (loops.md touch rule), true
## darkness with a sight light, keyboard parity (arrows/WASD, E, Enter).

signal interact(target: Dictionary)
signal exit_reached(exit: Dictionary)
signal hint(text: String)

const PROP_SLOTS := {"car": 0, "crate": 1, "tree": 2, "lamp": 3}
## Cul-de-sac sheet (tools/make_suburb.py): yard props by slot.
const SUBURB := ["mailbox", "mailbox2", "fence_x", "fence_y", "hedge", "bush", "bins", "hoop",
	"fir", "fir2", "maple", "maple2", "bike", "sale", "busstop", "pumpkin",
	"car_x", "car_y", "truck_x", "truck_y"]
## Map characters for suburb props; a pair means pick one at random.
const SUB_CHARS := {"P": ["fir", "fir2"], "M": ["maple", "maple2"], "m": ["mailbox", "mailbox2"],
	"f": ["fence_x"], "F": ["fence_y"], "b": ["hedge"], "B": ["bush"], "g": ["bins"], "k": ["hoop"],
	"i": ["bike"], "s": ["sale"], "u": ["pumpkin"], "v": ["car_x"], "V": ["car_y"], "w": ["truck_x"], "W": ["truck_y"]}

var s: GameState
var map: Dictionary
var variant: Dictionary
var ground: TileMapLayer
var sorted: Node2D
var overlay: Node2D
var marks: Node2D           # markers over heads, drawn above people and buildings
var camera: Camera2D
var night_mod: CanvasModulate
var sight_light: PointLight2D
var astar := AStarGrid2D.new()
var size := Vector2i(30, 30)
var hero: Node2D
var hero_cell := Vector2i.ZERO
var path: Array[Vector2i] = []
var preview_cell := Vector2i(-1, -1)
var preview_path: Array = []
var pending_target: Dictionary = {}
var targets: Array = []          # [{kind, data, cell, node}]
var visited: Dictionary = {}
var lit := false
var vcam := ViewCam.new()
var rot := 0                     # quarter turns of the view, clockwise
var follow := true               # camera follows the hero until the player pans
var tiles: Dictionary = {}       # cell -> atlas coords, kept so the map can be turned
var buildings: Array = []        # [{node, cell, fw, fh, home}] cell is the footprint's front anchor
var statics: Array = []          # [{node, cell}] trees, lamps, cars, crates
var busy := false
var steps_walked := 0
var anim_t := 0.0


func setup(state: GameState, map_id: String, variant_id: String, override: Dictionary = {}) -> void:
	s = state
	map = Rules.db("maps/" + map_id)
	variant = override if not override.is_empty() else map["variants"][variant_id]
	size = Vector2i(int(map["size"][0]), int(map["size"][1]))
	ground = TileMapLayer.new()
	ground.tile_set = Gfx.make_tileset()
	add_child(ground)
	overlay = Node2D.new()
	overlay.z_index = 1
	overlay.draw.connect(_draw_overlay)
	add_child(overlay)
	sorted = Node2D.new()
	sorted.y_sort_enabled = true
	sorted.z_index = 2
	add_child(sorted)
	marks = Node2D.new()
	marks.z_index = 3
	marks.draw.connect(_draw_marks)
	add_child(marks)
	night_mod = CanvasModulate.new()
	add_child(night_mod)
	camera = Camera2D.new()
	vcam.camera = camera
	vcam.apply_zoom()
	add_child(camera)
	camera.make_current()
	astar.region = Rect2i(Vector2i.ZERO, size)
	astar.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	astar.update()
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(map_id)
	var rows: Array = map["rows"]
	var bi := 0
	for y in size.y:
		var row: String = rows[y]
		for x in size.x:
			var ch := row[x]
			var c := Vector2i(x, y)
			var tile_row := {".": 0, "T": 0, "H": 0, "=": 1, "c": 1, "-": 2, "l": 2, ",": 3, "x": 2, "d": 2, "p": 2, "o": 3}.get(ch, 0)
			tiles[c] = Vector2i(rng.randi() % 8, tile_row)
			match ch:
				"H":
					var bsp := _prop(Rect2(bi % 4 * 512, 0, 512, 1024), Vector2(0, -488), Vector2.ZERO)
					buildings.append({"node": bsp, "cell": c})
					bi += 1
					for dy in range(-4, 1):
						for dx in range(-4, 1):
							var b := c + Vector2i(dx, dy)
							if astar.is_in_boundsv(b):
								astar.set_point_solid(b)
				"T", "l", "c", "x":
					var kind: String = {"T": "tree", "l": "lamp", "c": "car", "x": "crate"}[ch]
					statics.append({"node": _small_prop(kind, c, rng), "cell": c})
					astar.set_point_solid(c)
				_:
					if SUB_CHARS.has(ch):
						var opts: Array = SUB_CHARS[ch]
						var k2: String = opts[rng.randi() % opts.size()]
						statics.append({"node": _sub_prop(k2, c), "cell": c, "kind": k2})
						astar.set_point_solid(c)
	for h in map.get("homes", []):
		var hc := Vector2i(int(h["cell"][0]), int(h["cell"][1]))
		var long_x: bool = String(h.get("long", "x")) == "x"
		var look := int(h.get("look", 0))
		var hsp := Sprite2D.new()
		hsp.texture = Gfx.canvas_tex("suburb")
		hsp.region_enabled = true
		hsp.region_rect = Rect2(look % 3 * 640, look / 3 * 512, 640, 512)
		sorted.add_child(hsp)
		var fw := 5 if long_x else 4
		var fh := 4 if long_x else 5
		buildings.append({"node": hsp, "cell": hc, "fw": fw, "fh": fh, "home": true, "long_x": long_x})
		for dy in range(-(fh - 1), 1):
			for dx in range(-(fw - 1), 1):
				var b := hc + Vector2i(dx, dy)
				if astar.is_in_boundsv(b):
					astar.set_point_solid(b)
	_paint_ground()
	_place_buildings()
	hero_cell = Vector2i(int(variant["spawn"][0]), int(variant["spawn"][1]))
	hero = _person("layer_body", hero_cell, s.members["hero"], true)
	_place_targets()
	lit = Devices.working_count(s, "led_lantern") > 0 or Devices.working_count(s, "oil_lantern") > 0
	sight_light = PointLight2D.new()
	sight_light.texture = Gfx.light_tex()
	sight_light.color = Color(1.0, 0.85, 0.65)
	sight_light.energy = 1.5
	sight_light.position = Vector2(0, -40)
	hero.add_child(sight_light)
	apply_light()
	camera.position = hero.position


func apply_light() -> void:
	var night: bool = bool(variant.get("night", false)) and s.watch >= 2 or (s.phase == "act1" and s.watch >= 2)
	if not bool(variant.get("night", false)):
		night = false
	var forced: bool = bool(variant.get("force_night", false))
	if forced:
		night = true
	night_mod.color = Color(0.05, 0.055, 0.09) if night else Color(1, 1, 1)
	sight_light.enabled = night
	var sight := Act1.sight(s, lit and night) if night else 99
	if forced:
		sight = 6 if lit else (3 if "light_discipline" in s.perks else 2)
	sight_light.texture_scale = maxf(0.6, sight * 0.42)
	for t in targets:
		var vis: bool = not night or Combat.dist(t["cell"], hero_cell) <= sight + 1
		if t["node"] != null:
			t["node"].visible = vis
	_redraw()


func sight_now() -> int:
	if night_mod.color.r >= 0.5:
		return 99
	if bool(variant.get("force_night", false)):
		return 6 if lit else 2
	return Act1.sight(s, lit)


## Remove one target (a found person, a finished task) and free its cell.
func remove_target(id: String) -> void:
	for t in targets.duplicate():
		if String(t["data"].get("id", "")) == id:
			if t["node"] != null:
				astar.set_point_solid(t["cell"], false)
				t["node"].queue_free()
			targets.erase(t)
	_redraw()


func _prop(region: Rect2, offset: Vector2, pos: Vector2) -> Sprite2D:
	var sp := Sprite2D.new()
	sp.texture = Gfx.canvas_tex("props")
	sp.region_enabled = true
	sp.region_rect = region
	sp.offset = offset
	sp.position = pos
	sorted.add_child(sp)
	return sp


## A yard prop from the cul-de-sac sheet. Fences pick the slot that matches
## their direction on screen, which swaps when the map is turned.
func _sub_prop(kind: String, c: Vector2i) -> Sprite2D:
	var sp := Sprite2D.new()
	sp.texture = Gfx.canvas_tex("suburb")
	sp.region_enabled = true
	sp.offset = Vector2(0, -112)
	sp.position = cell_pos(c)
	_sub_region(sp, kind)
	sorted.add_child(sp)
	return sp


func _sub_region(sp: Sprite2D, kind: String) -> void:
	var k := kind
	if rot % 2 == 1 and kind.ends_with("_x"):
		k = kind.trim_suffix("_x") + "_y"
	elif rot % 2 == 1 and kind.ends_with("_y"):
		k = kind.trim_suffix("_y") + "_x"
	var j := SUBURB.find(k)
	sp.region_rect = Rect2(j % 8 * 256, 1024 + j / 8 * 256, 256, 256)


func _small_prop(kind: String, c: Vector2i, rng: RandomNumberGenerator) -> Sprite2D:
	if kind in SUBURB:
		return _sub_prop(kind, c)
	var slot: int = PROP_SLOTS[kind] + 4 * (rng.randi() % 8)
	return _prop(Rect2(slot % 8 * 256, 1024 + slot / 8 * 256, 256, 256), Vector2(0, -112), cell_pos(c))


func _person(look: String, c: Vector2i, member: Dictionary, layered: bool, scale_v: float = 1.0) -> Node2D:
	var n := Node2D.new()
	n.position = cell_pos(c)
	n.scale = Vector2.ONE * scale_v
	var names: Array = ["layer_body", "layer_outfit", "layer_item"] if layered else [look]
	for tn in names:
		var sp := Sprite2D.new()
		sp.texture = Gfx.canvas_tex(tn)
		sp.hframes = 12
		sp.vframes = 8
		sp.offset = Vector2(0, -70)
		sp.frame = 2 * 12
		if tn == "layer_body":
			var tone := Heritage.tone(int(member.get("heritage", 0)))
			sp.material = Gfx.skin_material(tone[0], tone[1])
		n.add_child(sp)
	sorted.add_child(n)
	return n


func _place_targets() -> void:
	targets.clear()
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	for npc in variant.get("npcs", []):
		if npc.has("cond") and not Rules.check(s, npc["cond"]):
			continue
		var c := Vector2i(int(npc["cell"][0]), int(npc["cell"][1]))
		var member: Dictionary = s.members.get(npc.get("role", ""), {})
		var node := _person(npc["look"], c, member, false, float(npc.get("scale", 1.0)))
		astar.set_point_solid(c)
		targets.append({"kind": "npc", "data": npc, "cell": c, "node": node})
	for ob in variant.get("objects", []):
		if ob.has("cond") and not Rules.check(s, ob["cond"]):
			continue
		var c := Vector2i(int(ob["cell"][0]), int(ob["cell"][1]))
		var node: Node2D = null
		if ob.get("prop", "none") != "none":
			node = _small_prop(ob["prop"], c, rng)
			astar.set_point_solid(c)
		targets.append({"kind": "object", "data": ob, "cell": c, "node": node})
	for ex in variant.get("exits", []):
		var c := Vector2i(int(ex["cell"][0]), int(ex["cell"][1]))
		targets.append({"kind": "exit", "data": ex, "cell": c, "node": null})


func refresh_targets() -> void:
	for t in targets:
		if t["node"] != null and t["kind"] == "npc":
			astar.set_point_solid(t["cell"], false)
			t["node"].queue_free()
		elif t["node"] != null:
			astar.set_point_solid(t["cell"], false)
			t["node"].queue_free()
	_place_targets()
	apply_light()


func cell_pos(c: Vector2i) -> Vector2:
	return ground.map_to_local(ViewCam.rot_cell(c, rot, size.x, size.y))


func _paint_ground() -> void:
	ground.clear()
	for c in tiles:
		ground.set_cell(ViewCam.rot_cell(c, rot, size.x, size.y), 0, tiles[c])


## A building covers the 5x5 cells behind its anchor; after a turn, its sprite
## sits on whichever footprint cell is now nearest the viewer.
func _place_buildings() -> void:
	for b in buildings:
		var best := Vector2i.ZERO
		var bs := -999999
		for dy in range(-(int(b.get("fh", 5)) - 1), 1):
			for dx in range(-(int(b.get("fw", 5)) - 1), 1):
				var d := ViewCam.rot_cell(b["cell"] + Vector2i(dx, dy), rot, size.x, size.y)
				if d.x + d.y > bs:
					bs = d.x + d.y
					best = d
		b["node"].position = ground.map_to_local(best)
		if b.get("home", false):
			# The house art is long along screen-x; mirror it when the long side
			# runs the other way on screen (a 4 x 5 lot, or a quarter turn).
			var flip: bool = (not b["long_x"]) != (rot % 2 == 1)
			b["node"].flip_h = flip
			b["node"].offset = Vector2(32 if flip else -32, -204)


## Turn the map a quarter turn (dir +1 clockwise, -1 counter-clockwise).
func turn_view(dir: int) -> void:
	if busy:
		return
	rot = posmod(rot + dir, 4)
	_paint_ground()
	_place_buildings()
	for st in statics:
		st["node"].position = cell_pos(st["cell"])
		if st.has("kind"):
			_sub_region(st["node"], st["kind"])
	for t in targets:
		if t["node"] != null:
			t["node"].position = cell_pos(t["cell"])
			if String(t["data"].get("prop", "")) in SUBURB:
				_sub_region(t["node"], String(t["data"]["prop"]))
	hero.position = cell_pos(hero_cell)
	follow = true
	camera.position = hero.position
	_redraw()


func zoom_view(f: float) -> void:
	vcam.zoom_by(f)


func recenter() -> void:
	follow = true


func set_view(render_scale: float, screen_h: float) -> void:
	vcam.base_zoom = screen_h * render_scale / 1080.0 * 0.9
	vcam.apply_zoom()


# ------------------------------------------------------------------ input
func _target_at(c: Vector2i) -> Dictionary:
	for t in targets:
		if t["cell"] == c and (t["node"] == null or t["node"].visible):
			return t
	return {}


func tap_cell(c: Vector2i) -> void:
	if busy or not astar.is_in_boundsv(c):
		return
	var t := _target_at(c)
	if not t.is_empty():
		var nm: String = s.fill(String(t["data"].get("name", t["data"].get("label", ""))))
		if pending_target == t:
			_go_to_target(t)
		else:
			pending_target = t
			preview_path = []
			hint.emit("%s. Tap again to %s." % [nm, "go there" if t["kind"] == "exit" else ("talk" if t["kind"] == "npc" else "look")])
		_redraw()
		return
	pending_target = {}
	if astar.is_point_solid(c):
		return
	if c == preview_cell:
		_walk(preview_path)
		preview_cell = Vector2i(-1, -1)
		preview_path = []
	else:
		var p := astar.get_id_path(hero_cell, c)
		if p.size() < 2:
			return
		preview_cell = c
		preview_path = p
		var noise := "walk, noise 3 tiles"
		hint.emit("%d steps (%s). Tap again to go." % [p.size() - 1, noise])
	_redraw()


func _go_to_target(t: Dictionary) -> void:
	pending_target = {}
	var c: Vector2i = t["cell"]
	if Combat.dist(c, hero_cell) <= 1:
		_arrive(t)
		return
	var best: Array = []
	for dx in [-1, 0, 1]:
		for dy in [-1, 0, 1]:
			var n: Vector2i = c + Vector2i(dx, dy)
			if (dx == 0 and dy == 0) or not astar.is_in_boundsv(n) or astar.is_point_solid(n):
				continue
			var p := astar.get_id_path(hero_cell, n)
			if (p.size() > 0 and (best.is_empty() or p.size() < best.size())) or n == hero_cell:
				best = p if n != hero_cell else [hero_cell]
	if t["kind"] == "exit" and not astar.is_point_solid(c):
		best = astar.get_id_path(hero_cell, c)
	if best.is_empty():
		hint.emit("You can't reach that from here.")
		return
	_walk(best, t)


func _walk(p: Array, then: Dictionary = {}) -> void:
	if p.size() <= 1:
		if not then.is_empty():
			_arrive(then)
		return
	busy = true
	follow = true
	var tw := create_tween()
	for i in range(1, p.size()):
		var c: Vector2i = p[i]
		tw.tween_callback(_face.bind(c))
		tw.tween_property(hero, "position", cell_pos(c), 0.16)
		tw.tween_callback(_step_done.bind(c))
	tw.tween_callback(func() -> void:
		busy = false
		if not then.is_empty():
			_arrive(then))


func _face(c: Vector2i) -> void:
	var v := cell_pos(c) - hero.position
	var a := atan2(v.y * 2.0, v.x)
	var f := posmod(int(round(a / (PI / 4.0))), 8)
	for sp in hero.get_children():
		if sp is Sprite2D:
			sp.frame = f * 12 + int(anim_t) % 12


func _step_done(c: Vector2i) -> void:
	hero_cell = c
	steps_walked += 1
	apply_light()
	for t in targets:
		if t["kind"] == "exit" and t["cell"] == c:
			exit_reached.emit(t["data"])


func _arrive(t: Dictionary) -> void:
	if t["kind"] == "exit":
		exit_reached.emit(t["data"])
	else:
		visited[t["data"]["id"]] = true
		interact.emit(t["data"])


func _process(delta: float) -> void:
	anim_t = fmod(anim_t + delta * 12.0, 12.0)
	if hero != null:
		if follow:
			camera.position = camera.position.lerp(hero.position, minf(1.0, delta * 6.0))
		var pts: Array = [hero.position + Vector2(0, -60)]
		if preview_cell.x >= 0:
			pts.append(cell_pos(preview_cell))
		if not pending_target.is_empty():
			pts.append(cell_pos(pending_target["cell"]) + Vector2(0, -40))
		for tg in targets:
			if tg["data"].get("task", false) and (tg["node"] == null or tg["node"].visible):
				pts.append(cell_pos(tg["cell"]) + Vector2(0, -40))
		var sprites: Array = []
		for b in buildings:
			sprites.append(b["node"])
		for st in statics:
			sprites.append(st["node"])
		ViewCam.fade_occluders(sprites, pts, delta)


func _unhandled_input(e: InputEvent) -> void:
	if not visible:
		return
	var g := vcam.handle(e)
	if g["tap"] != null:
		tap_cell(_screen_to_cell(g["tap"]))
		return
	if g["turn"] != 0:
		turn_view(g["turn"])
		return
	if g["panned"]:
		follow = false
		return
	if g["recenter"]:
		recenter()
		return
	if e is InputEventKey and e.pressed and not e.echo and not busy:
		var dir := Vector2i.ZERO
		match e.keycode:
			KEY_UP, KEY_W:
				dir = Vector2i(0, -1)
			KEY_DOWN, KEY_S:
				dir = Vector2i(0, 1)
			KEY_LEFT, KEY_A:
				dir = Vector2i(-1, 0)
			KEY_RIGHT, KEY_D:
				dir = Vector2i(1, 0)
			KEY_E, KEY_ENTER, KEY_SPACE:
				_interact_nearest()
				return
		if dir != Vector2i.ZERO:
			dir = ViewCam.unrot_dir(dir, rot)
			var n := hero_cell + dir
			if astar.is_in_boundsv(n) and not astar.is_point_solid(n):
				_walk([hero_cell, n])
			else:
				var t := _target_at(n)
				if not t.is_empty():
					_arrive(t)


func _interact_nearest() -> void:
	var best: Dictionary = {}
	var bd := 99
	for t in targets:
		var dd := Combat.dist(t["cell"], hero_cell)
		if dd < bd and (t["node"] == null or t["node"].visible):
			bd = dd
			best = t
	if best.is_empty():
		return
	if bd <= 1:
		_arrive(best)
	else:
		_go_to_target(best)


func _screen_to_cell(p: Vector2) -> Vector2i:
	var world := get_canvas_transform().affine_inverse() * p
	return ViewCam.unrot_cell(ground.local_to_map(ground.to_local(world)), rot, size.x, size.y)


func _draw_overlay() -> void:
	for i in range(1, preview_path.size()):
		var c: Vector2i = preview_path[i]
		overlay.draw_circle(cell_pos(c), 10, Color(1, 0.9, 0.5, 0.8))
	if preview_cell.x >= 0:
		_diamond(preview_cell, Color(1, 0.85, 0.3, 0.9))
	if not pending_target.is_empty():
		_diamond(pending_target["cell"], Color(0.4, 0.9, 1.0, 0.9))
	for t in targets:
		if t["kind"] == "exit":
			_diamond(t["cell"], Color(0.6, 1.0, 0.6, 0.7))


func _redraw() -> void:
	overlay.queue_redraw()
	if marks != null:
		marks.queue_redraw()


func _draw_marks() -> void:
	for t in targets:
		if t["kind"] == "exit" or not (t["node"] == null or t["node"].visible):
			continue
		if t["data"].get("task", false):
			var tp := cell_pos(t["cell"]) + Vector2(0, -160 if t["kind"] == "npc" else -60)
			marks.draw_circle(tp, 18, Color(0.9, 0.35, 0.1, 0.95))
			marks.draw_rect(Rect2(tp + Vector2(-3, -12), Vector2(6, 14)), Color(1, 1, 1))
			marks.draw_circle(tp + Vector2(0, 9), 3, Color(1, 1, 1))
		elif not visited.has(t["data"].get("id", "")) and (t["data"].has("dialogue") or t["data"].has("event")):
			marks.draw_circle(cell_pos(t["cell"]) + Vector2(0, -150 if t["kind"] == "npc" else -40), 9, Color(1, 0.8, 0.2, 0.95))


func _diamond(c: Vector2i, col: Color) -> void:
	var p := cell_pos(c)
	var pts := PackedVector2Array([p + Vector2(0, -32), p + Vector2(64, 0), p + Vector2(0, 32), p + Vector2(-64, 0), p + Vector2(0, -32)])
	overlay.draw_polyline(pts, col, 3.0)
