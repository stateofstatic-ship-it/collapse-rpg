class_name Combat
extends RefCounted
## Turn-based fight core (loops.md Combat): 6 AP, shown odds, cover, Strain,
## Call Out as a shown gate, Parley and surrender, Down and bleeding out.
## No node, no clock: the view animates the events this returns.

const WEAPONS := {
	"fists": {"name": "Fists", "bonus": 45, "dmg": 1, "sinew": true, "range": 1, "lethal": false},
	"knife": {"name": "Knife", "bonus": 45, "dmg": 4, "sinew": true, "range": 1, "lethal": true},
	"tool": {"name": "Pry bar", "bonus": 40, "dmg": 6, "sinew": true, "range": 1, "lethal": true},
	"pistol": {"name": "Pistol", "bonus": 25, "dmg": 12, "sinew": false, "range": 10, "lethal": true},
	"shotgun": {"name": "Shotgun", "bonus": 40, "dmg": 20, "sinew": false, "range": 6, "lethal": true},
	"rifle": {"name": "Rifle", "bonus": 35, "dmg": 18, "sinew": false, "range": 30, "lethal": true},
}
const QUICK_AP := 3
const AIMED_AP := 5
const MELEE_AP := 2

var s: GameState
var enc: Dictionary
var size := Vector2i(14, 12)
var cover: Dictionary = {}     # Vector2i -> 20 or 40
var units: Array = []
var order: Array = []
var turn := 0
var round_no := 1
var outcome := ""
var parley_offered := false
var breath_used: Dictionary = {}
var events: Array = []
var astar := AStarGrid2D.new()
var night := false


func _init(state: GameState, encounter_id: String) -> void:
	s = state
	enc = Rules.db("encounters")[encounter_id]
	size = Vector2i(int(enc["size"][0]), int(enc["size"][1]))
	night = bool(enc.get("night", false))
	astar.region = Rect2i(Vector2i.ZERO, size)
	astar.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	astar.update()
	for c in enc.get("cover", []):
		var cell := Vector2i(int(c[0]), int(c[1]))
		cover[cell] = 40 if c[2] == "full" else 20
		astar.set_point_solid(cell)
	var pc: Array = enc["party_cells"]
	var i := 0
	for role in _party_roles():
		var m: Dictionary = s.members[role]
		var cell := Vector2i(int(pc[i][0]), int(pc[i][1]))
		units.append({"id": role, "name": m["name"], "team": "party", "role": role, "look": "layer_body" if role == "hero" else _look(role),
			"cell": cell, "hp": s.hp_max(role) if int(m.get("hp", 0)) <= 0 else int(m["hp"]), "hp_max": s.hp_max(role),
			"ap": 0, "ap_max": s.ap_max(role), "fire": s.skill(role, "firearms"), "melee": s.skill(role, "close_quarters"),
			"weapon": _party_weapon(role), "sinew": s.attr(role, "sinew"), "reflex": s.attr(role, "reflex"),
			"init": 2 * s.attr(role, "reflex") + s.attr(role, "awareness"), "state": "ok", "bleed": 3, "leader": false})
		i += 1
	var k := 0
	for e in enc["enemies"]:
		units.append({"id": "foe%d" % k, "name": e["name"], "team": "foe", "role": "", "look": e.get("look", "char_raider"),
			"cell": Vector2i(int(e["cell"][0]), int(e["cell"][1])), "hp": int(e["hp"]), "hp_max": int(e["hp"]),
			"ap": 0, "ap_max": int(e["ap"]), "fire": int(e["skill"]), "melee": int(e["skill"]), "weapon": e["weapon"],
			"sinew": 4, "reflex": 4, "init": int(e.get("init", 10)), "state": "ok", "bleed": 3, "leader": bool(e.get("leader", false)),
			"strain": int(e.get("strain", 30)), "discipline": int(e.get("discipline", 4)), "grain": e.get("grain", "bolts"),
			"dummy": bool(e.get("dummy", false))})
		k += 1
	for u in units:
		astar.set_point_solid(u["cell"])
	order = range(units.size())
	order.sort_custom(func(a: int, b: int) -> bool: return int(units[a]["init"]) > int(units[b]["init"]))
	turn = 0
	_begin(false)


func _party_roles() -> Array:
	var out: Array = ["hero"]
	for r in enc.get("allies", []):
		if s.members[r]["where"] == s.members["hero"]["where"]:
			out.append(r)
	return out


func _look(role: String) -> String:
	return {"partner": "char_medic", "teen": "char_civilian", "elder": "char_elder"}.get(role, "char_survivor")


func is_practice() -> bool:
	return bool(enc.get("practice", false))


func _party_weapon(role: String) -> String:
	if role == "hero" and enc.has("loan_weapon"):
		return String(enc["loan_weapon"])
	if role != "hero":
		return "tool" if role == "elder" else "fists"
	if Devices.working_count(s, "rifle") > 0 and s.led("rounds") > 0:
		return "rifle"
	if Devices.working_count(s, "pistol") > 0 and s.led("rounds") > 0:
		return "pistol"
	return "tool"


func unit(id: String) -> Dictionary:
	for u in units:
		if u["id"] == id:
			return u
	return {}


func active() -> Dictionary:
	return units[order[turn]]


func is_player_turn() -> bool:
	return outcome == "" and active()["team"] == "party"


# ------------------------------------------------------------------ odds
func cover_between(attacker: Vector2i, target: Vector2i) -> int:
	var best := 0
	var dir := Vector2(attacker - target).normalized()
	for dx in [-1, 0, 1]:
		for dy in [-1, 0, 1]:
			var c := target + Vector2i(dx, dy)
			if cover.has(c) and Vector2(dx, dy).normalized().dot(dir) > 0.3:
				best = maxi(best, int(cover[c]))
	return best


static func dist(a: Vector2i, b: Vector2i) -> int:
	return maxi(absi(a.x - b.x), absi(a.y - b.y))


func hit_chance(att: Dictionary, tgt: Dictionary, aimed: bool) -> int:
	var w: Dictionary = WEAPONS[att["weapon"]]
	var sk: int = att["melee"] if int(w["range"]) <= 1 else att["fire"]
	var d := dist(att["cell"], tgt["cell"])
	var h := sk + int(w["bonus"])
	if d > int(w["range"]):
		if int(w["range"]) <= 1:
			return 0
		h -= 3 * (d - int(w["range"]))
	if int(w["range"]) > 1:
		h -= cover_between(att["cell"], tgt["cell"])
	h -= 2 * int(tgt["reflex"])
	if att["team"] == "party":
		h -= s.strain_penalty(att["role"])
	else:
		h -= 15 if int(att.get("strain", 0)) >= 55 + 2 * int(att.get("discipline", 4)) else 0
	if night and d > 6:
		h -= 15
	if aimed:
		h += 20
	return clampi(h, 5, 95)


func damage(att: Dictionary) -> int:
	var w: Dictionary = WEAPONS[att["weapon"]]
	return int(w["dmg"]) + (int(att["sinew"]) if w["sinew"] else 0)


func reach(u: Dictionary) -> Dictionary:
	# cell -> AP cost, 1 AP per 2 steps.
	var out := {}
	var steps := int(u["ap"]) * 2
	astar.set_point_solid(u["cell"], false)
	for x in size.x:
		for y in size.y:
			var c := Vector2i(x, y)
			if astar.is_point_solid(c) or c == u["cell"] or dist(c, u["cell"]) > steps:
				continue
			var p := astar.get_id_path(u["cell"], c)
			if p.size() > 1 and p.size() - 1 <= steps:
				out[c] = int(ceil((p.size() - 1) / 2.0))
	astar.set_point_solid(u["cell"], true)
	return out


# ------------------------------------------------------------------ commands
func move(to: Vector2i) -> bool:
	var u := active()
	var r := reach(u)
	if not r.has(to):
		return false
	astar.set_point_solid(u["cell"], false)
	var path := astar.get_id_path(u["cell"], to)
	u["cell"] = to
	astar.set_point_solid(to, true)
	u["ap"] = int(u["ap"]) - int(r[to])
	events.append({"type": "move", "unit": u["id"], "path": path})
	return true


func can_attack(tgt: Dictionary, aimed: bool) -> bool:
	var u := active()
	if tgt.is_empty() or tgt["team"] == u["team"] or tgt["state"] != "ok":
		return false
	var cost := _attack_cost(u, aimed)
	return int(u["ap"]) >= cost and hit_chance(u, tgt, aimed) > 0


func _attack_cost(u: Dictionary, aimed: bool) -> int:
	if int(WEAPONS[u["weapon"]]["range"]) <= 1:
		return MELEE_AP
	return AIMED_AP if aimed else QUICK_AP


func attack(target_id: String, aimed: bool) -> bool:
	var u := active()
	var t := unit(target_id)
	if not can_attack(t, aimed):
		return false
	u["ap"] = int(u["ap"]) - _attack_cost(u, aimed)
	var ranged := int(WEAPONS[u["weapon"]]["range"]) > 1
	if ranged and u["team"] == "party" and not is_practice():
		s.add_led("rounds", -1)
		s.profile = mini(100, s.profile + 2 if not s.flag("shot_profiled") else s.profile)
		s.set_flag("shot_profiled")
	var hc := hit_chance(u, t, aimed)
	var r := s.roll("combat")
	var hit := r <= hc
	var solid := r <= hc - 40
	var dmg := 0
	if hit:
		dmg = damage(u)
		if solid:
			dmg = int(dmg * 1.5)
		t["hp"] = int(t["hp"]) - dmg
		if t["team"] == "foe":
			t["strain"] = int(t["strain"]) + dmg
		else:
			s.add_strain(t["role"], 15 if solid else 8)
	events.append({"type": "attack", "from": u["id"], "to": t["id"], "hit": hit, "solid": solid, "dmg": dmg, "ranged": ranged, "chance": hc})
	_say("%s %s %s (%d%%): %s" % [u["name"], "shoots at" if ranged else "strikes", t["name"], hc, ("solid hit, %d" % dmg if solid else "hit, %d" % dmg) if hit else "miss"])
	if int(t["hp"]) <= 0 and t["state"] == "ok":
		_down(t)
	_morale()
	return true


func _down(t: Dictionary) -> void:
	t["state"] = "down"
	t["hp"] = 0
	astar.set_point_solid(t["cell"], false)
	events.append({"type": "down", "unit": t["id"]})
	_say("%s is Down." % t["name"])
	if is_practice():
		_say("%s falls over." % t["name"])
	elif t["team"] == "foe":
		for f in units:
			if f["team"] == "foe" and f["state"] == "ok":
				f["strain"] = int(f["strain"]) + (15 if t["leader"] else 5)
	else:
		for r in GameState.ROLES:
			s.add_strain(r, 20 if t["role"] != "hero" else 10)


func call_out_dc() -> int:
	var lead_d := 4
	for f in units:
		if f["team"] == "foe" and f["leader"]:
			lead_d = int(f["discipline"])
	var out_n := 0
	var foes := 0
	var party := 0
	for f in units:
		if f["team"] == "foe":
			foes += 1
			if f["state"] != "ok":
				out_n += 1
		elif f["state"] == "ok":
			party += 1
	var dc := 30 + 5 * lead_d - mini(30, 10 * out_n) - int(maxi(s.mercy, 0) / 5)
	if foes - out_n >= 2 * party:
		dc += 10
	dc += 10 * int(s.flags.get("callouts_this_fight", 0))
	return dc


func call_out() -> Dictionary:
	var u := active()
	if u["role"] != "hero" or int(u["ap"]) < 2 or s.strain_band("hero") >= 2:
		return {}
	var g := Rules.gate(s, "negotiation", call_out_dc())
	u["ap"] = int(u["ap"]) - 2
	s.flags["callouts_this_fight"] = int(s.flags.get("callouts_this_fight", 0)) + 1
	if g["pass"] or g["make_do"]:
		if not g["pass"]:
			s.add_strain("hero", int(g["cost"]))
		for f in units:
			if f["team"] == "foe" and f["state"] == "ok":
				f["strain"] = int(f["strain"]) + 15
		_say("%s calls them out. It lands." % u["name"])
		events.append({"type": "callout", "ok": true})
		_morale()
	else:
		_say("%s calls them out. Nobody moves." % u["name"])
		events.append({"type": "callout", "ok": false})
	return g


func take_breath() -> bool:
	var u := active()
	if u["team"] != "party" or breath_used.has(u["id"]) or int(u["ap"]) < 2:
		return false
	breath_used[u["id"]] = true
	u["ap"] = int(u["ap"]) - 2
	s.add_strain(u["role"], -2 * s.attr(u["role"], "discipline"))
	_say("%s takes a breath." % u["name"])
	return true


func _morale() -> void:
	var foes := 0
	var out_n := 0
	for f in units:
		if f["team"] != "foe":
			continue
		foes += 1
		if f["state"] != "ok":
			out_n += 1
			continue
		var shaken := 55 + 2 * int(f["discipline"])
		if int(f["strain"]) >= shaken:
			if f["grain"] == "sees_red":
				continue
			f["state"] = "surrendered" if f["grain"] == "locks_up" or f["grain"] == "goes_quiet" else "fled"
			astar.set_point_solid(f["cell"], false)
			out_n += 1
			events.append({"type": f["state"], "unit": f["id"]})
			_say("%s %s." % [f["name"], "drops the weapon and kneels" if f["state"] == "surrendered" else "breaks and runs"])
	if out_n >= foes:
		outcome = "win"
	elif out_n * 2 >= foes and not parley_offered and not is_practice():
		parley_offered = true
		events.append({"type": "parley"})
		_say("Their leader calls for Parley: let them go, and it ends here.")
	var alive := 0
	for f in units:
		if f["team"] == "party" and f["state"] == "ok":
			alive += 1
	if alive == 0:
		outcome = "lose"


func accept_parley() -> void:
	for f in units:
		if f["team"] == "foe" and f["state"] == "ok":
			f["state"] = "fled"
	outcome = "parley"


func end_turn() -> void:
	if outcome != "":
		return
	_advance()
	while outcome == "" and active()["team"] == "foe":
		_ai(active())
		if outcome != "":
			break
		_advance()


func _advance() -> void:
	turn += 1
	if turn >= order.size():
		turn = 0
		round_no += 1
		for u in units:
			if u["state"] == "down":
				u["bleed"] = int(u["bleed"]) - 1
	_begin(true)


func _begin(_skip_dead: bool) -> void:
	var guard := 0
	while active()["state"] != "ok" and guard < units.size() * 2:
		turn += 1
		if turn >= order.size():
			turn = 0
			round_no += 1
		guard += 1
	var u := active()
	u["ap"] = int(u["ap_max"])


func _ai(u: Dictionary) -> void:
	if u.get("dummy", false):
		u["ap"] = 0
		return
	var targets: Array = []
	for t in units:
		if t["team"] == "party" and t["state"] == "ok":
			targets.append(t)
	if targets.is_empty():
		return
	targets.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return dist(a["cell"], u["cell"]) < dist(b["cell"], u["cell"]))
	var t: Dictionary = targets[0]
	var safety := 0
	while int(u["ap"]) > 0 and outcome == "" and safety < 6:
		safety += 1
		if can_attack(t, false) and hit_chance(u, t, false) >= 30:
			attack(t["id"], false)
			continue
		var r := reach(u)
		if r.is_empty():
			break
		var best := Vector2i(-1, -1)
		var best_score := -9999.0
		for c in r:
			var d := dist(c, t["cell"])
			var w: Dictionary = WEAPONS[u["weapon"]]
			var score := -absf(d - (1.0 if int(w["range"]) <= 1 else 5.0)) * 3.0 - int(r[c])
			if cover_between(t["cell"], c) > 0:
				score += 4.0
			if score > best_score:
				best_score = score
				best = c
		if best.x < 0 or not move(best):
			break
		if not can_attack(t, false):
			break
	u["ap"] = 0


func _say(t: String) -> void:
	events.append({"type": "text", "text": t})


# ------------------------------------------------------------------ aftermath
func downed_foes() -> Array:
	var out: Array = []
	if is_practice():
		return out
	for f in units:
		if f["team"] == "foe" and f["state"] == "down":
			out.append(f)
	return out


## Treat a Down foe with a kit, or leave them. Leaving a Down person to bleed
## out is scored as a killing of this fight's kind (consequences.md).
func resolve_down(foe_id: String, treat: bool) -> void:
	var f := unit(foe_id)
	if treat and s.led("kits") > 0:
		s.add_led("kits", -1)
		f["state"] = "treated"
		s.mercy = clampi(s.mercy + 3, -50, 50)
		s.add_log("You treated %s. They will remember who did." % f["name"])
	else:
		f["state"] = "dead"
		var kind: String = "first_strike" if s.flag("struck_first") else String(enc.get("kill_kind", "self_defense"))
		var first: bool = s.kills.is_empty()
		s.kills.append({"who": f["name"], "kind": kind, "where": enc["name"], "day": s.day, "week": s.week})
		s.add_strain("hero", 10 if first else 4)
		if kind == "first_strike":
			s.mercy = clampi(s.mercy - 2, -50, 50)
		s.add_log("%s died at %s. Kind: %s." % [f["name"], enc["name"], kind.replace("_", " ").capitalize()])


## Party Health carries back to the sheet.
func write_back() -> void:
	for u in units:
		if u["team"] == "party":
			s.members[u["role"]]["hp"] = maxi(1, int(u["hp"]))
	s.flags.erase("callouts_this_fight")
	s.flags.erase("struck_first")
	s.flags.erase("shot_profiled")
