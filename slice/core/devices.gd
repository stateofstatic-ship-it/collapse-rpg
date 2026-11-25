class_name Devices
extends RefCounted
## Stopped Clocks device rules (f4.md, revised 2026-11-25): post-2005 vehicles 95% Dead; 75% of every other
## unshielded item that needs electronics is Dead, vehicles included; Old
## Iron rolls 10%, panels 5%, sealed gear 5%. Survivors are Worn. Vehicle
## hardening from prep90's Go Kit stacks on the vehicle's roll, floor 35%.

const SEAL_CAPACITY := 6


static func dead_chance(tier: String) -> int:
	return int(Rules.db("items")["dead_chance"].get(tier, 0))


static func hardening() -> Dictionary:
	return Rules.db("items")["hardening"]


static func is_electronic(tier: String) -> bool:
	return tier in ["electronic", "plugged", "handheld", "inverter", "vehicle_post2005", "vehicle_1980_2005"]


## Chance (0-100) that a vehicle dies, after its hardening options.
static func vehicle_chance(v: Dictionary) -> int:
	var era: String = Rules.db("items")["vehicles"][v["kind"]]["era"]
	var base := dead_chance(era)
	if not is_electronic(era):
		return base
	var minus := 0
	for opt in v.get("mods", []):
		minus += int(hardening()["options"][opt]["minus"])
	if minus == 0:
		return base
	return maxi(int(hardening()["floor"]), base - minus)


## The flash. Returns report rows [{where, id, alive, dead, chance, worn}].
static func flash(s: GameState) -> Array:
	var items_db: Dictionary = Rules.db("items")["items"]
	var rows: Array = []
	s.device_state.clear()
	var r := s.rng("flash")
	for id in s.items:
		var tier: String = items_db.get(id, {}).get("tier", "mechanical")
		rows.append(_roll(r, "house", id, int(s.items[id]), dead_chance(tier), is_electronic(tier)))
	for id in s.shielded:
		rows.append(_roll(r, "locker", id, int(s.shielded[id]), dead_chance("shielded"), false))
	for v in s.vehicles:
		var load: Dictionary = v["load"]
		for id in load:
			var tier: String = items_db.get(id, {}).get("tier", "mechanical")
			# A tarp gives nothing to small gear inside (prep90 Go Kit).
			rows.append(_roll(r, "vehicle:" + String(v["kind"]), id, int(load[id]), dead_chance(tier), is_electronic(tier)))
		var c := vehicle_chance(v)
		var dead := r.randi_range(1, 100) <= c
		v["state"] = "dead" if dead else "ok"
		var era: String = Rules.db("items")["vehicles"][v["kind"]]["era"]
		if not dead and is_electronic(era):
			v["worn"] = true
		rows.append({"where": "vehicle", "id": v["kind"], "alive": 0 if dead else 1, "dead": 1 if dead else 0, "chance": c, "vehicle": true, "worn": 1 if v.get("worn", false) else 0})
	s.save_rng("flash", r)
	for row in rows:
		if row.get("vehicle", false):
			continue
		s.device_state["%s:%s" % [row["where"], row["id"]]] = {"alive": row["alive"], "dead": row["dead"], "worn": row["worn"]}
	return rows


static func _roll(r: RandomNumberGenerator, where: String, id: String, n: int, chance: int, electronic: bool) -> Dictionary:
	var dead := 0
	for i in n:
		if chance > 0 and r.randi_range(1, 100) <= chance:
			dead += 1
	return {"where": where, "id": id, "alive": n - dead, "dead": dead, "chance": chance, "worn": n - dead if electronic else 0}


## Working units of an item anywhere: before the flash all count.
static func working_count(s: GameState, id: String) -> int:
	if s.device_state.is_empty():
		var n := int(s.items.get(id, 0)) + int(s.shielded.get(id, 0))
		for v in s.vehicles:
			n += int(v["load"].get(id, 0))
		return n
	var total := 0
	for k in s.device_state:
		if String(k).ends_with(":" + id):
			total += int(s.device_state[k]["alive"])
	return total


static func vehicle_runs(s: GameState) -> Dictionary:
	for v in s.vehicles:
		if v["state"] == "ok" and v["kind"] != "family_car" and not v.get("stall", false):
			return v
	return {}


static func load_weight(v: Dictionary) -> float:
	var items_db: Dictionary = Rules.db("items")["items"]
	var w := 0.0
	for id in v["load"]:
		w += float(items_db.get(id, {}).get("weight", 1)) * int(v["load"][id])
	return w


static func capacity(v: Dictionary) -> float:
	return float(Rules.db("items")["vehicles"][v["kind"]]["capacity"])


## Move one item between the house and a vehicle. Returns false if it will not fit.
static func load_item(s: GameState, v: Dictionary, id: String, into: bool) -> bool:
	var items_db: Dictionary = Rules.db("items")["items"]
	if into:
		if int(s.items.get(id, 0)) <= 0:
			return false
		if load_weight(v) + float(items_db.get(id, {}).get("weight", 1)) > capacity(v):
			return false
		s.items[id] = int(s.items[id]) - 1
		v["load"][id] = int(v["load"].get(id, 0)) + 1
	else:
		if int(v["load"].get(id, 0)) <= 0:
			return false
		v["load"][id] = int(v["load"][id]) - 1
		if int(v["load"][id]) == 0:
			v["load"].erase(id)
		s.items[id] = int(s.items.get(id, 0)) + 1
	return true


## Add or remove a hardening option. Returns "" or the reason it failed.
static func toggle_mod(s: GameState, v: Dictionary, opt: String) -> String:
	var rec: Dictionary = hardening()["options"][opt]
	var mods: Array = v.get("mods", [])
	if opt in mods:
		mods.erase(opt)
		v.erase("stall")
		v["mods"] = mods
		return ""
	var cost := int(rec["cost"])
	if cost > Act0.spendable(s):
		return "Needs $%d" % cost
	if rec.has("gate"):
		var g := Rules.gate(s, rec["gate"][0], int(rec["gate"][1]))
		if not g["pass"]:
			# A real method that backfires when fitted wrong (prep90).
			v["stall"] = true
			s.add_log("The suppressors went on wrong. The engine stalls at random until they come off.")
	Act0.pay(s, cost)
	mods.append(opt)
	v["mods"] = mods
	return ""


## Seal one small device in the shielding bag (Seal the Spares).
static func seal(s: GameState, id: String) -> bool:
	if not s.flag("seal_bag") or int(s.items.get(id, 0)) <= 0:
		return false
	var used := 0
	for k in s.shielded:
		used += int(s.shielded[k])
	if used >= SEAL_CAPACITY + int(s.flags.get("locker_bonus", 0)):
		return false
	s.items[id] = int(s.items[id]) - 1
	s.shielded[id] = int(s.shielded.get(id, 0)) + 1
	return true


static func sealable(id: String) -> bool:
	var tier: String = Rules.db("items")["items"].get(id, {}).get("tier", "")
	var w := float(Rules.db("items")["items"].get(id, {}).get("weight", 99))
	return is_electronic(tier) and w <= 5.0


## A Mechanics 35 day with sealed spares restores a dead fuel-injected vehicle 70% of the time.
static func try_restore(s: GameState, v: Dictionary) -> String:
	var rec: Dictionary = hardening()["restore"]
	if v["state"] != "dead" or not s.flag("seal_bag") or v.get("restore_tried", false):
		return "nothing to try"
	var g := Rules.gate(s, rec["gate"][0], int(rec["gate"][1]))
	if not g["pass"] and not g["make_do"]:
		return "Needs %s %d" % [GameState.SKILL_NAMES[rec["gate"][0]], int(rec["gate"][1])]
	if not g["pass"]:
		s.add_strain("hero", int(g["cost"]))
	v["restore_tried"] = true
	for i in 4:
		Act1.advance_watch(s)
	if s.roll("restore") <= int(rec["chance"]):
		v["state"] = "ok"
		v["worn"] = true
		return "ok"
	return "failed"
