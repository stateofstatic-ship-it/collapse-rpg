class_name Rules
extends RefCounted
## Shared rules: content loading, shown gates with Make Do, conditions and
## effects. Dialogue, Act 0 activities and quests all go through here, so a
## bot and the interface change the world the same way.

static var _db: Dictionary = {}

const MAKE_DO_MARGIN: Array[int] = [15, 10, 5, 0]


static func db(file: String) -> Dictionary:
	if _db.has(file):
		return _db[file]
	var path := "res://content/%s.json" % file
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		push_error("missing content " + path)
		return {}
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	var d: Dictionary = parsed if parsed is Dictionary else {}
	_db[file] = d
	return d


static func item_name(id: String) -> String:
	return String(db("items")["items"].get(id, {}).get("name", id))


# ------------------------------------------------------------------ gates
## Who rolls a gate: the hero, or the best present member at -10 (Assist).
static func gate_value(s: GameState, skill: String) -> Dictionary:
	var best := s.skill("hero", skill)
	var who := "hero"
	var here: String = s.members["hero"]["where"]
	for r in GameState.ROLES:
		if r == "hero" or r == "child":
			continue
		if s.members[r]["where"] != here:
			continue
		var v := s.skill(r, skill) - 10
		if v > best:
			best = v
			who = r
	return {"value": best, "who": who}


## Returns {pass, make_do, gap, value, who, cost}. Gates never roll (character.md).
static func gate(s: GameState, skill: String, dc: int) -> Dictionary:
	var g := gate_value(s, skill)
	var v: int = g["value"]
	var gap := dc - v
	var margin := MAKE_DO_MARGIN[s.strain_band("hero")]
	return {"pass": v >= dc, "make_do": v < dc and gap <= margin, "gap": maxi(gap, 0), "value": v,
		"who": g["who"], "cost": 5 + maxi(gap, 0)}


static func gate_label(s: GameState, skill: String, dc: int) -> String:
	var g := gate(s, skill, dc)
	var who := "" if g["who"] == "hero" else " (%s assists)" % s.members[g["who"]]["name"]
	var tag := "PASS" if g["pass"] else ("MAKE DO +%d Strain" % g["cost"] if g["make_do"] else "short %d" % g["gap"])
	return "[%s %d: you have %d%s, %s]" % [GameState.SKILL_NAMES.get(skill, skill), dc, g["value"], who, tag]


# ------------------------------------------------------------------ conditions
static func check(s: GameState, conds: Array) -> bool:
	for c in conds:
		if not check_one(s, c):
			return false
	return true


static func check_one(s: GameState, c: Array) -> bool:
	var op: String = c[0]
	match op:
		"flag":
			return s.flag(c[1])
		"not_flag":
			return not s.flag(c[1])
		"item":
			return int(s.items.get(c[1], 0)) >= (int(c[2]) if c.size() > 2 else 1)
		"led":
			return s.led(c[1]) >= int(c[2])
		"money":
			return s.money >= int(c[1])
		"cash":
			return s.cash >= int(c[1])
		"buyin":
			return s.buyin_avg() >= int(c[1])
		"buyin_role":
			return int(s.members[c[1]]["buyin"]) >= int(c[2])
		"trust_count":
			return s.trusting_households(int(c[1])) >= int(c[2])
		"track":
			return float(s.tracks.get(c[1], 0.0)) >= float(c[2])
		"has_vehicle":
			return s.has_vehicle()
		"vehicle_runs":
			for v in s.vehicles:
				if v["state"] == "ok":
					return true
			return false
		"clues":
			return s.clues.size() >= int(c[1])
		"clue":
			return c[1] in s.clues
		"quest_end":
			return String(s.quests.get(c[1], {}).get("end", "")) == String(c[2])
		"quest_state":
			return String(s.quests.get(c[1], {}).get("state", "")) == String(c[2])
		"day_ge":
			return s.day >= int(c[1])
		"profile_ge":
			return s.profile >= int(c[1])
		"profile_lt":
			return s.profile < int(c[1])
		"where":
			return s.members[c[1]]["where"] == c[2]
		"not_where":
			return s.members[c[1]]["where"] != c[2]
		"rounds":
			return s.led("rounds") >= int(c[1])
		"weapon":
			return s.items.get("rifle", 0) > 0 or s.items.get("pistol", 0) > 0
		"habit":
			return c[1] in s.habits
		"tally":
			for t in s.tallies:
				if t["id"] == c[1] and t["state"] == "open":
					return true
			return false
		"not_tally":
			for t in s.tallies:
				if t["id"] == c[1] and t["state"] == "open":
					return false
			return true
		"working":
			return Devices.working_count(s, c[1]) > 0
		"any":
			for sub in c.slice(1):
				if check_one(s, sub):
					return true
			return false
	push_warning("unknown condition " + op)
	return false


# ------------------------------------------------------------------ effects
## Applies effects and returns the events the presentation must handle
## (battles, scene changes, pickers). Pure state changes happen here.
static func apply(s: GameState, effects: Array) -> Array:
	var events: Array = []
	for e in effects:
		var ev := apply_one(s, e)
		if not ev.is_empty():
			events.append(ev)
	return events


static func apply_one(s: GameState, e: Array) -> Array:
	var op: String = e[0]
	match op:
		"food", "water", "heat", "fuel", "kits", "inhalers", "components", "rounds":
			s.add_led(op, int(e[1]))
		"money":
			s.money += int(e[1])
		"cash":
			s.cash = maxi(0, s.cash + int(e[1]))
		"barter":
			s.barter = maxi(0, s.barter + int(e[1]))
		"profile":
			s.profile = clampi(s.profile + int(e[1]), 0, 100)
		"word":
			s.word = clampi(s.word + int(e[1]), -50, 50)
		"mercy":
			s.mercy = clampi(s.mercy + int(e[1]), -50, 50)
		"track":
			s.tracks[e[1]] = minf(3.0, float(s.tracks.get(e[1], 0.0)) + float(e[2]))
		"flag":
			s.set_flag(e[1])
		"unflag":
			s.set_flag(e[1], false)
		"item":
			s.items[e[1]] = maxi(0, int(s.items.get(e[1], 0)) + int(e[2]))
		"shielded":
			s.shielded[e[1]] = int(s.shielded.get(e[1], 0)) + int(e[2])
		"vehicle":
			if s.vehicle(e[1]).is_empty():
				s.vehicles.append({"kind": e[1], "mods": [], "load": {}, "state": "ok"})
		"skill":
			var b: Dictionary = s.members[e[1]]["bonus"]
			b[e[2]] = int(b.get(e[2], 0)) + int(e[3])
		"buyin":
			s.add_buyin(int(e[1]))
		"buyin_role":
			s.members[e[1]]["buyin"] = clampi(int(s.members[e[1]]["buyin"]) + int(e[2]), 0, 100)
		"strain":
			s.add_strain(e[1], int(e[2]))
		"strain_all":
			for r in GameState.ROLES:
				s.add_strain(r, int(e[1]))
		"trust":
			s.neighbors[e[1]] = clampi(int(s.neighbors.get(e[1], 0)) + int(e[2]), 0, 3)
		"standing":
			s.add_standing(e[1], int(e[2]))
		"job_standing":
			s.job_standing = clampi(s.job_standing + int(e[1]), 0, 100)
		"checks":
			s.checks_bonus += int(e[1])
		"tally":
			s.tallies.append({"id": e[1], "text": s.fill(e[2]), "state": "open", "week": s.week, "day": s.day})
			s.add_log("Promise made: " + String(e[2]))
		"keep_tally":
			for t in s.tallies:
				if t["id"] == e[1] and t["state"] == "open":
					t["state"] = "kept"
					s.word = clampi(s.word + 2, -50, 50)
					s.add_log("Promise kept: " + String(t["text"]))
		"break_tally":
			for t in s.tallies:
				if t["id"] == e[1] and t["state"] == "open":
					t["state"] = "broken"
					s.word = clampi(s.word - 3, -50, 50)
					s.add_log("Promise broken: " + String(t["text"]))
		"habit":
			if not (e[1] in s.habits):
				s.habits.append(e[1])
				s.add_log("{teen.name} saw that. Habit learned: " + String(e[1]).capitalize())
		"clue":
			if not (e[1] in s.clues):
				s.clues.append(e[1])
		"quest":
			var q: Dictionary = s.quests.get(e[1], {"state": "open", "end": ""})
			q["state"] = e[2]
			if e.size() > 3:
				q["end"] = e[3]
			s.quests[e[1]] = q
		"log":
			s.add_log(e[1])
		"where":
			var to: String = e[2]
			if to == "@hero":
				to = s.members["hero"]["where"]
			s.members[e[1]]["where"] = to
		"time":
			for i in int(e[1]):
				Act1.advance_watch(s)
		"wait_morning":
			Act1.wait_until(s, 0)
		"perk":
			if not (e[1] in s.perks):
				s.perks.append(e[1])
		"pay_or_card":
			var amt := int(e[1])
			s.money -= amt
		_:
			# Anything else is an event for the presentation layer.
			return e
	return []
