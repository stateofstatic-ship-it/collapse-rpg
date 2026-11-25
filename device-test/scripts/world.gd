class_name World
extends Node2D
## The exploration stress scene: a 64x64 diamond tile map, about 300 props,
## N walking characters, N normal-mapped lights, night grade and rain.

const MAP := 64
const CENTER := Vector2i(32, 32)
const WANDER := 7
const LOOKS: Array[String] = ["char_survivor", "char_guard", "char_raider", "char_medic", "char_trader", "char_civilian", "char_worker", "char_elder"]

var ground: TileMapLayer
var sorted: Node2D
var walkers_node: Node2D
var lights_node: Node2D
var camera: Camera2D
var night: CanvasModulate
var rain: CPUParticles2D
var astar := AStarGrid2D.new()
var lamp_heads: Array[Vector2] = []
var flicker: Array = []
var user_zoom := 1.0
var base_zoom := 1.0
var t := 0.0
var touches: Dictionary = {}
var pinch_start := 0.0
var pinch_zoom := 1.0
var map_seed := 20261125


func build() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = map_seed
	ground = TileMapLayer.new()
	ground.tile_set = Gfx.make_tileset()
	add_child(ground)
	sorted = Node2D.new()
	sorted.y_sort_enabled = true
	add_child(sorted)
	walkers_node = Node2D.new()
	walkers_node.y_sort_enabled = true
	sorted.add_child(walkers_node)
	lights_node = Node2D.new()
	add_child(lights_node)
	night = CanvasModulate.new()
	night.color = Color(0.16, 0.18, 0.27)
	add_child(night)
	camera = Camera2D.new()
	camera.position = cell_pos(CENTER)
	add_child(camera)
	camera.make_current()
	rain = CPUParticles2D.new()
	rain.amount = 1600
	rain.lifetime = 0.7
	rain.texture = Gfx.streak_tex()
	rain.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	rain.direction = Vector2(-0.25, 1)
	rain.spread = 3
	rain.gravity = Vector2(0, 600)
	rain.initial_velocity_min = 1100
	rain.initial_velocity_max = 1400
	rain.local_coords = false
	rain.z_index = 10
	rain.modulate = Color(2.2, 2.2, 2.6, 0.9)
	camera.add_child(rain)

	astar.region = Rect2i(0, 0, MAP, MAP)
	astar.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	astar.update()

	for y in MAP:
		for x in MAP:
			var road := x % 10 == 0 or y % 10 == 0
			var walk := x % 10 in [1, 9] or y % 10 in [1, 9]
			var row := 1 if road else (2 if walk else (0 if rng.randf() < 0.7 else 3))
			ground.set_cell(Vector2i(x, y), 0, Vector2i(rng.randi() % 8, row))

	# Buildings on some blocks, blocking their footprint.
	for by in range(0, MAP / 10):
		for bx in range(0, MAP / 10):
			var c := Vector2i(bx * 10 + 7, by * 10 + 7)
			if c.x >= MAP or c.y >= MAP or (abs(c.x - CENTER.x) < 4 and abs(c.y - CENTER.y) < 4):
				continue
			if rng.randf() < 0.75:
				_prop("props", Rect2(rng.randi() % 4 * 512, 0, 512, 1024), Vector2(0, -488), cell_pos(c))
				for dy in range(-4, 1):
					for dx in range(-4, 1):
						var b := c + Vector2i(dx, dy)
						if astar.is_in_boundsv(b):
							astar.set_point_solid(b)
	# Small props: cars on roads, trees and crates in lots, lamps on corners.
	var count := {"car": 0, "tree": 0, "crate": 0, "lamp": 0}
	for y in MAP:
		for x in MAP:
			var c := Vector2i(x, y)
			if astar.is_point_solid(c):
				continue
			var road := x % 10 == 0 or y % 10 == 0
			var r := rng.randf()
			var slot := -1
			var kind := ""
			if x % 10 == 1 and y % 5 == 1:
				kind = "lamp"
				slot = 3 + 4 * (rng.randi() % 8)
			elif road and r < 0.08:
				kind = "car"
				slot = 0 + 4 * (rng.randi() % 8)
			elif not road and r < 0.07:
				kind = "tree"
				slot = 2 + 4 * (rng.randi() % 8)
			elif not road and r < 0.09:
				kind = "crate"
				slot = 1 + 4 * (rng.randi() % 8)
			if slot < 0:
				continue
			var row := slot / 8
			var col := slot % 8
			var pos := cell_pos(c) + Vector2(rng.randf_range(-12, 12), rng.randf_range(-6, 6))
			_prop("props", Rect2(col * 256, 1024 + row * 256, 256, 256), Vector2(0, -112), pos)
			count[kind] += 1
			if kind == "lamp":
				lamp_heads.append(pos + Vector2(12, -190))
			if kind != "car":
				astar.set_point_solid(c)
	print("props: ", count)


func _prop(tex: String, region: Rect2, offset: Vector2, pos: Vector2) -> void:
	var s := Sprite2D.new()
	s.texture = Gfx.canvas_tex(tex)
	s.region_enabled = true
	s.region_rect = region
	s.offset = offset
	s.position = pos
	sorted.add_child(s)


func cell_pos(c: Vector2i) -> Vector2:
	return ground.map_to_local(c)


func random_path(from: Vector2i, rng: RandomNumberGenerator) -> Array[Vector2i]:
	for _i in 8:
		var to := CENTER + Vector2i(rng.randi_range(-WANDER, WANDER), rng.randi_range(-WANDER, WANDER))
		if astar.is_point_solid(to) or to == from:
			continue
		var p := astar.get_id_path(from, to)
		if p.size() > 1:
			p.remove_at(0)
			return p
	return []


func free_cell(rng: RandomNumberGenerator) -> Vector2i:
	for _i in 100:
		var c := CENTER + Vector2i(rng.randi_range(-WANDER, WANDER), rng.randi_range(-WANDER, WANDER))
		if not astar.is_point_solid(c):
			return c
	return CENTER


func set_walkers(n: int, n_layered: int) -> void:
	for w in walkers_node.get_children():
		w.free()
	var rng := RandomNumberGenerator.new()
	rng.seed = 99
	for i in n:
		var w := Walker.new()
		walkers_node.add_child(w)
		w.setup(self, free_cell(rng), LOOKS[i % LOOKS.size()], i < n_layered, 1000 + i)


func set_lights(n: int) -> void:
	for l in lights_node.get_children():
		l.free()
	flicker.clear()
	# Nearest lamps to the centre first, then lanterns carried by walkers.
	var centre := cell_pos(CENTER)
	var lamps := lamp_heads.duplicate()
	lamps.sort_custom(func(a: Vector2, b: Vector2) -> bool: return a.distance_squared_to(centre) < b.distance_squared_to(centre))
	var walkers := walkers_node.get_children()
	var wi := 0
	var li := 0
	for i in n:
		var l := PointLight2D.new()
		l.texture = Gfx.light_tex()
		l.height = 60
		if i % 3 == 2 and wi < walkers.size():
			l.color = Color(1.0, 0.72, 0.4)
			l.energy = 1.4
			l.texture_scale = 2.2
			l.position = Vector2(10, -60)
			l.height = 30
			walkers[wi].add_child(l)
			flicker.append([l, 1.4, randf() * 10.0])
			wi += 1
		else:
			l.color = Color(1.0, 0.92, 0.75) if i % 2 == 0 else Color(0.75, 0.85, 1.0)
			l.energy = 1.6
			l.texture_scale = 4.0
			l.position = lamps[li % lamps.size()] if not lamps.is_empty() else centre
			li += 1
			lights_node.add_child(l)


func set_night(on: bool) -> void:
	night.color = Color(0.16, 0.18, 0.27) if on else Color(1, 1, 1)


func set_rain(on: bool) -> void:
	rain.emitting = on
	rain.visible = on


func set_view(render_scale: float, screen_h: float) -> void:
	base_zoom = screen_h * render_scale / 1080.0
	_apply_zoom()


func _apply_zoom() -> void:
	camera.zoom = Vector2.ONE * base_zoom * user_zoom
	var vp_size := get_viewport_rect().size / camera.zoom
	rain.emission_rect_extents = vp_size * 0.6
	rain.position = Vector2(0, -vp_size.y * 0.3)


func _process(delta: float) -> void:
	t += delta
	for f in flicker:
		f[0].energy = f[1] * (0.85 + 0.15 * sin(t * 9.0 + f[2]) * sin(t * 3.7 + f[2] * 2.0))


func _unhandled_input(e: InputEvent) -> void:
	if e is InputEventScreenTouch:
		if e.pressed:
			touches[e.index] = e.position
		else:
			touches.erase(e.index)
		if touches.size() == 2:
			var k := touches.keys()
			pinch_start = (touches[k[0]] as Vector2).distance_to(touches[k[1]])
			pinch_zoom = user_zoom
	elif e is InputEventScreenDrag:
		touches[e.index] = e.position
		if touches.size() >= 2:
			var k := touches.keys()
			var d := (touches[k[0]] as Vector2).distance_to(touches[k[1]])
			if pinch_start > 1.0:
				user_zoom = clampf(pinch_zoom * d / pinch_start, 1.0, 2.0)
				_apply_zoom()
		else:
			camera.position -= e.relative / camera.zoom
	elif e is InputEventMouseMotion and (e.button_mask & MOUSE_BUTTON_MASK_LEFT):
		camera.position -= e.relative / camera.zoom
	elif e is InputEventMouseButton and e.pressed:
		if e.button_index == MOUSE_BUTTON_WHEEL_UP:
			user_zoom = clampf(user_zoom * 1.1, 1.0, 2.0)
			_apply_zoom()
		elif e.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			user_zoom = clampf(user_zoom / 1.1, 1.0, 2.0)
			_apply_zoom()


func to_save() -> Dictionary:
	var ws: Array = []
	for w in walkers_node.get_children():
		ws.append(w.to_save())
	return {"map_seed": map_seed, "camera": [camera.position.x, camera.position.y], "zoom": user_zoom, "walkers": ws}


func from_save(d: Dictionary) -> void:
	camera.position = Vector2(d["camera"][0], d["camera"][1])
	user_zoom = float(d["zoom"])
	_apply_zoom()
	var ws: Array = d["walkers"]
	var kids := walkers_node.get_children()
	for i in mini(ws.size(), kids.size()):
		kids[i].from_save(ws[i])
