class_name Act1
extends RefCounted
## Stopped Clocks Act 1, Gather (f4.md): the clock in six-hour watches, the
## household ledger, travel by foot, bicycle or a running vehicle, true
## darkness and the moon, M1 and M2 state, and Profile knocks.

const WATCH_NAMES: Array[String] = ["Morning", "Afternoon", "Evening", "Night"]
const LAST_DAY := 7
## Miles a watch: foot 15 a day, bicycle 40 (25 with the elder), Old Iron 120 (f4.md).
const SPEED := {"foot": 5.0, "bicycle": 13.0, "bicycle_elder": 8.0, "vehicle": 30.0}


static func nodes() -> Dictionary:
	return Rules.db("worldmap")["nodes"]


static func miles(a: String, b: String) -> float:
	var links: Dictionary = Rules.db("worldmap")["links"]
	if links.has(a + ">" + b):
		return float(links[a + ">" + b])
	if links.has(b + ">" + a):
		return float(links[b + ">" + a])
	var pa: Array = nodes()[a]["pos"]
	var pb: Array = nodes()[b]["pos"]
	return Vector2(float(pa[0]), float(pa[1])).distance_to(Vector2(float(pb[0]), float(pb[1]))) / 40.0


static func travel_modes(s: GameState) -> Array:
	var out: Array = ["foot"]
	if Devices.working_count(s, "bicycle") > 0 or s.flag("took_bike"):
		out.append("bicycle")
	var v := Devices.vehicle_runs(s)
	if not v.is_empty() and s.led("fuel") > 0 and String(s.flags.get("vehicle_at", "home")) == s.members["hero"]["where"]:
		out.append("vehicle")
	return out


static func travel_watches(s: GameState, a: String, b: String, mode: String) -> int:
	var sp: float = SPEED[mode]
	if mode == "bicycle" and s.members["elder"]["where"] == a:
		sp = SPEED["bicycle_elder"]
	var m := miles(a, b)
	var route_mult := float(nodes()[b].get("route_mult", {}).get(mode, 1.0))
	return maxi(1, int(ceil(m * route_mult / sp)))


## Move the hero (and anyone travelling with them) to node b.
static func travel(s: GameState, b: String, mode: String, party: Array) -> Dictionary:
	var a: String = s.members["hero"]["where"]
	var w := travel_watches(s, a, b, mode)
	var night_legs := 0
	for i in w:
		if s.watch == 3:
			night_legs += 1
		advance_watch(s)
	for r in ["hero"] + party:
		s.members[r]["where"] = b
	if mode == "vehicle":
		var v := Devices.vehicle_runs(s)
		var gal := int(ceil(miles(a, b) / float(Rules.db("items")["vehicles"][v["kind"]]["mpg"])))
		s.add_led("fuel", -maxi(1, gal))
		s.profile = mini(100, s.profile + 5)
		s.flags["vehicle_at"] = b
	if night_legs > 0:
		s.add_strain("hero", 3)
	return {"watches": w, "night": night_legs}


static func advance_watch(s: GameState) -> void:
	s.watch += 1
	if s.watch > 3:
		s.watch = 0
		s.day += 1
		daily_tick(s)


static func wait_until(s: GameState, watch: int) -> void:
	var guard := 0
	while s.watch != watch and guard < 8:
		advance_watch(s)
		guard += 1


static func home_count(s: GameState) -> int:
	var n := 0
	for r in GameState.ROLES:
		if s.members[r]["where"] == "home":
			n += 1
	return n


## One day of the household ledger (loops.md), run at each new morning.
static func daily_tick(s: GameState) -> void:
	var lines: Array = []
	var home := home_count(s)
	var food_use := 1 if home >= 3 else (0 if home == 0 else 1)
	if s.led("food") >= food_use:
		s.add_led("food", -food_use)
	else:
		s.ledger["food"] = 0
		for r in GameState.ROLES:
			s.add_strain(r, 4)
		lines.append("Short rations: everyone +4 Strain.")
	if s.day >= 3:
		if s.flag("taps_noted") == false:
			s.set_flag("taps_noted")
			lines.append("The taps sputter and stop. The city pumps had no power to lose; they lost it on Day 0 and the towers have drained.")
		if s.flag("well_share"):
			pass
		elif s.led("water") > 0:
			s.add_led("water", -1)
		elif s.led("heater_water") > 0:
			s.add_led("heater_water", -1)
		else:
			for r in GameState.ROLES:
				s.add_strain(r, 4)
			lines.append("No clean water: +4 Strain each. Day 2 without costs AP.")
	var cold := false
	if s.flag("stove") and s.led("heat") > 0:
		s.add_led("heat", -1)
	elif s.flag("thermal_cooker") and s.led("heat") > 0:
		s.add_led("heat", -1)
	else:
		cold = true
		for r in GameState.ROLES:
			s.add_strain(r, 4)
		lines.append("A cold night: +4 Strain each.")
	if s.members["child"]["where"] == "home" or true:
		var use := 2 if cold or s.strain_band("child") >= 2 else 1
		if s.led("inhalers") >= use:
			s.add_led("inhalers", -use)
		else:
			s.ledger["inhalers"] = 0
			lines.append("{child.name} has no inhaler. An attack is a matter of time.")
	for r in GameState.ROLES:
		if s.members[r]["where"] == "home" and s.members["hero"]["where"] == "home":
			s.add_strain(r, -6)
	var missing := 0
	for r in GameState.ROLES:
		if r != "hero" and s.members[r]["where"] != "home" and not s.flag("accounted_" + r):
			missing += 1
	if missing > 0:
		s.add_strain("hero", 2 * missing)
	s.profile = maxi(0, s.profile - 1) if not s.flag("lit_window") else mini(100, s.profile + 2)
	for l in lines:
		s.add_log("Day %d: %s" % [s.day, l])


# ------------------------------------------------------------------ darkness
## Moon on Day d (f4.md moon table): full on Day 12, new from Day 26.
static func moon(d: int) -> String:
	var p := posmod(d - 12, 30)
	if p <= 2 or p >= 28:
		return "full"
	if p >= 12 and p <= 17:
		return "new"
	if (p >= 5 and p <= 9) or (p >= 20 and p <= 24):
		return "half"
	return "crescent"


## Sight in tiles: 4 + Awareness by day; at night 2 flat unlit, a lantern 6.
static func sight(s: GameState, lit: bool) -> int:
	var aw := s.attr("hero", "awareness")
	if s.watch <= 1:
		return 4 + aw
	if lit:
		return 6
	if s.watch == 2 and s.day == 0:
		return 2
	if "light_discipline" in s.perks:
		return 3
	return 2


# ------------------------------------------------------------------ M1
static func m1_status(s: GameState) -> Dictionary:
	var out := {}
	for r in ["partner", "teen", "elder", "child"]:
		out[r] = s.members[r]["where"]
	return out


static func all_home(s: GameState) -> bool:
	for r in GameState.ROLES:
		if s.members[r]["where"] != "home":
			return false
	return true


## Called whenever the hero reaches home: closes M1 when everyone is in.
static func check_m1(s: GameState) -> String:
	if String(s.quests.get("m1", {}).get("state", "")) == "done":
		return ""
	var others_home := true
	for r in ["teen", "elder", "child"]:
		if s.members[r]["where"] != "home":
			others_home = false
	if not others_home or s.members["hero"]["where"] != "home":
		return ""
	var end := ""
	if s.members["partner"]["where"] == "home":
		end = "all_home" if s.day <= 3 else "long_way_round"
	elif s.flag("partner_stays"):
		end = "partner_stays"
	else:
		return ""
	s.quests["m1"] = {"state": "done", "end": end}
	match end:
		"all_home":
			s.add_buyin(10)
			s.add_log("M1 Gather: All Home. Family Buy-in +10.")
		"partner_stays":
			s.add_log("M1 Gather: {partner.name} Stays at the hospital and will walk home on Day 7.")
		"long_way_round":
			for r in GameState.ROLES:
				s.add_strain(r, 20)
			s.add_log("M1 Gather: the Long Way Round. Everyone home, everyone frayed: Strain +20.")
	return end


## Profile tier sets extra Act 1 knocks (prep90.md).
static func knocks_for_night(s: GameState) -> Array:
	var tier := Act0.profile_tier(s.profile)
	var out: Array = []
	if s.day == 1:
		out.append("knock_ruth")
	if tier != "Gray" and s.day == 2:
		out.append("knock_neighbors")
	if (tier == "Talked About" or tier == "Marked") and s.day == 4:
		out.append("knock_strangers")
	if tier == "Marked" and s.day == 5:
		out.append("night_attempt")
	return out


## Day 0 unpacking: consumable items count into the ledger once they are home.
static func unpack(s: GameState, items: Dictionary) -> void:
	var db: Dictionary = Rules.db("items")["items"]
	for id in items.keys():
		var rec: Dictionary = db.get(id, {})
		if rec.get("tier", "") != "consumable":
			continue
		var n := int(items[id])
		s.add_led("food", int(rec.get("food_days", 0)) * n)
		s.add_led("water", int(rec.get("water_days", 0)) * n)
		s.add_led("kits", int(rec.get("kits", 0)) * n)
		s.add_led("fuel", int(rec.get("fuel", 0)) * n)
		s.add_led("components", int(rec.get("components", 0)) * n)
		items.erase(id)
