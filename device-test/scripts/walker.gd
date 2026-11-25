class_name Walker
extends Node2D
## A character that wanders the test map: 8 facings x 12 walk frames,
## one to three stacked lit sprite layers (art.md: body, outfit, item).

const FRAME_COLS := 12
const SPEED := 85.0

var world: Node = null
var cell := Vector2i.ZERO
var path: Array[Vector2i] = []
var facing := 0
var anim := 0.0
var rng := RandomNumberGenerator.new()
var layers: Array[Sprite2D] = []
var look: String = ""
var layered := false


func setup(p_world: Node, p_cell: Vector2i, p_look: String, p_layered: bool, seed_val: int) -> void:
	world = p_world
	cell = p_cell
	look = p_look
	layered = p_layered
	rng.seed = seed_val
	position = world.cell_pos(cell)
	var names: Array[String] = []
	if layered:
		names = ["layer_body", "layer_outfit", "layer_item"]
	else:
		names = [look]
	for n in names:
		var s := Sprite2D.new()
		s.texture = Gfx.canvas_tex(n)
		s.hframes = FRAME_COLS
		s.vframes = 8
		s.offset = Vector2(0, -70)
		if n == "layer_body":
			var tone := rng.randf()
			s.material = Gfx.skin_material(Color(0.18, 0.1, 0.06).lerp(Color(0.45, 0.3, 0.2), tone), Color(0.45, 0.3, 0.2).lerp(Color(0.95, 0.78, 0.65), tone))
		add_child(s)
		layers.append(s)
	facing = rng.randi() % 8
	anim = rng.randf() * FRAME_COLS


func _process(delta: float) -> void:
	if path.is_empty():
		path = world.random_path(cell, rng)
		if path.is_empty():
			return
	var target: Vector2 = world.cell_pos(path[0])
	var to := target - position
	var step := SPEED * delta
	if to.length() <= step:
		position = target
		cell = path.pop_front()
	else:
		var v := to.normalized()
		position += v * step
		var a := atan2(v.y * 2.0, v.x)
		facing = posmod(int(round(a / (PI / 4.0))), 8)
	anim = fmod(anim + delta * 12.0, FRAME_COLS)
	var fr := facing * FRAME_COLS + int(anim)
	for s in layers:
		s.frame = fr


func to_save() -> Dictionary:
	var p: Array = []
	for c in path:
		p.append([c.x, c.y])
	return {"look": look, "layered": layered, "cell": [cell.x, cell.y], "pos": [position.x, position.y],
		"facing": facing, "anim": anim, "path": p, "rng_state": rng.state, "rng_seed": rng.seed}


func from_save(d: Dictionary) -> void:
	cell = Vector2i(d["cell"][0], d["cell"][1])
	position = Vector2(d["pos"][0], d["pos"][1])
	facing = int(d["facing"])
	anim = float(d["anim"])
	path.clear()
	for c in d["path"]:
		path.append(Vector2i(c[0], c[1]))
	rng.seed = int(d["rng_seed"])
	rng.state = int(d["rng_state"])
