class_name ViewCam
extends RefCounted
## Shared world-camera gestures for the town map and fights.
## Touch: one finger taps or pans, two fingers pinch to zoom and twist to turn
## the map a quarter turn. Mouse: click taps, drag (any button) pans, wheel zooms.
## Keys: Q / [ turn left, R / ] turn right, + / - zoom, Home recentres.
## handle() returns {"tap": Vector2 or null, "turn": -1/0/1, "panned": bool, "recenter": bool}.

const ZOOM_MIN := 0.5
const ZOOM_MAX := 2.5
const TWIST_STEP := 0.6   # radians of twist (about 35 degrees) per quarter turn

var camera: Camera2D
var base_zoom := 1.0
var user_zoom := 1.0
var touches: Dictionary = {}
var moved := 0.0
var pinch_d0 := 0.0
var pinch_z0 := 1.0
var twist_a0 := 0.0
var twist_acc := 0.0
var multi := false          # a two-finger gesture happened since the first finger went down
var mouse_down := false
var mouse_moved := 0.0


func apply_zoom() -> void:
	if camera != null:
		camera.zoom = Vector2.ONE * base_zoom * user_zoom


func zoom_by(f: float) -> void:
	user_zoom = clampf(user_zoom * f, ZOOM_MIN, ZOOM_MAX)
	apply_zoom()


func _pan(rel: Vector2) -> void:
	if camera != null:
		camera.position -= rel / camera.zoom.x


func _pair() -> Array:
	var k := touches.keys()
	return [touches[k[0]], touches[k[1]]]


static func _empty() -> Dictionary:
	return {"tap": null, "turn": 0, "panned": false, "recenter": false}


func handle(e: InputEvent) -> Dictionary:
	var out := _empty()
	if e is InputEventScreenTouch:
		if e.pressed:
			if touches.is_empty():
				moved = 0.0
				multi = false
			touches[e.index] = e.position
			if touches.size() == 2:
				multi = true
				var pr := _pair()
				pinch_d0 = maxf(1.0, (pr[0] as Vector2).distance_to(pr[1]))
				pinch_z0 = user_zoom
				twist_a0 = ((pr[1] as Vector2) - (pr[0] as Vector2)).angle()
				twist_acc = 0.0
		else:
			touches.erase(e.index)
			if touches.is_empty() and not multi and moved < UI.dp(12):
				out["tap"] = e.position
	elif e is InputEventScreenDrag:
		touches[e.index] = e.position
		if touches.size() >= 2:
			var pr := _pair()
			var d := (pr[0] as Vector2).distance_to(pr[1])
			user_zoom = clampf(pinch_z0 * d / pinch_d0, ZOOM_MIN, ZOOM_MAX)
			apply_zoom()
			var a := ((pr[1] as Vector2) - (pr[0] as Vector2)).angle()
			twist_acc += wrapf(a - twist_a0, -PI, PI)
			twist_a0 = a
			if absf(twist_acc) >= TWIST_STEP:
				out["turn"] = 1 if twist_acc > 0.0 else -1
				twist_acc = 0.0
		elif not multi:
			moved += e.relative.length()
			if moved >= UI.dp(12):
				_pan(e.relative)
				out["panned"] = true
	elif e is InputEventMouseButton and e.device != InputEvent.DEVICE_ID_EMULATION:
		match e.button_index:
			MOUSE_BUTTON_WHEEL_UP:
				if e.pressed:
					zoom_by(1.1)
			MOUSE_BUTTON_WHEEL_DOWN:
				if e.pressed:
					zoom_by(1.0 / 1.1)
			MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT, MOUSE_BUTTON_MIDDLE:
				if e.pressed:
					mouse_down = true
					mouse_moved = 0.0
				else:
					if mouse_down and e.button_index == MOUSE_BUTTON_LEFT and mouse_moved < UI.dp(8):
						out["tap"] = e.position
					mouse_down = false
	elif e is InputEventMouseMotion and e.device != InputEvent.DEVICE_ID_EMULATION and mouse_down and e.button_mask != 0:
		mouse_moved += e.relative.length()
		if mouse_moved >= UI.dp(8):
			_pan(e.relative)
			out["panned"] = true
	elif e is InputEventMagnifyGesture:
		zoom_by(e.factor)
	elif e is InputEventPanGesture:
		_pan(-e.delta * 20.0)
		out["panned"] = true
	elif e is InputEventKey and e.pressed and not e.echo:
		match e.keycode:
			KEY_Q, KEY_BRACKETLEFT:
				out["turn"] = -1
			KEY_R, KEY_BRACKETRIGHT:
				out["turn"] = 1
			KEY_EQUAL, KEY_PLUS, KEY_KP_ADD:
				zoom_by(1.15)
			KEY_MINUS, KEY_KP_SUBTRACT:
				zoom_by(1.0 / 1.15)
			KEY_HOME:
				out["recenter"] = true
	return out


## Quarter-turn cell mapping for a w x h grid. rot 0..3, clockwise on screen.
static func rot_cell(c: Vector2i, rot: int, w: int, h: int) -> Vector2i:
	match posmod(rot, 4):
		1:
			return Vector2i(h - 1 - c.y, c.x)
		2:
			return Vector2i(w - 1 - c.x, h - 1 - c.y)
		3:
			return Vector2i(c.y, w - 1 - c.x)
	return c


static func unrot_cell(d: Vector2i, rot: int, w: int, h: int) -> Vector2i:
	match posmod(rot, 4):
		1:
			return Vector2i(d.y, h - 1 - d.x)
		2:
			return Vector2i(w - 1 - d.x, h - 1 - d.y)
		3:
			return Vector2i(w - 1 - d.y, d.x)
	return d


## Grid direction that moves "up/down/left/right" the way the turned map shows it.
static func unrot_dir(v: Vector2i, rot: int) -> Vector2i:
	var r := v
	for i in posmod(rot, 4):
		r = Vector2i(r.y, -r.x)   # inverse of one clockwise turn of a direction
	return r


## Fade sprites that sit in front of any of the given world points and cover them.
static func fade_occluders(sprites: Array, points: Array, delta: float) -> void:
	for sp in sprites:
		if not is_instance_valid(sp):
			continue
		var r: Rect2 = sp.get_rect()
		r.position += sp.position
		var hide := false
		for p in points:
			if sp.position.y > p.y + 4.0 and r.has_point(p):
				hide = true
				break
		var target := 0.3 if hide else 1.0
		sp.modulate.a = move_toward(sp.modulate.a, target, delta * 4.0)


## Fade a sprite cut into strips as one piece: if any strip covers a point
## from in front, every strip fades.
static func fade_group(sprites: Array, points: Array, delta: float) -> void:
	var hide := false
	for sp in sprites:
		if not is_instance_valid(sp):
			continue
		var r: Rect2 = sp.get_rect()
		r.position += sp.position
		for p in points:
			if sp.position.y > p.y + 4.0 and r.has_point(p):
				hide = true
				break
		if hide:
			break
	var target := 0.3 if hide else 1.0
	for sp in sprites:
		if is_instance_valid(sp):
			sp.modulate.a = move_toward(sp.modulate.a, target, delta * 4.0)
