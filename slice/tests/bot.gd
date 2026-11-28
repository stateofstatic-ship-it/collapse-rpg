extends SceneTree
## Headless playthrough bots (tech.md pacing bots). They drive the same core
## commands as the interface: Act0.book, Dialogue.choose, Combat.attack,
## Act1.travel. Minutes come from a time model (hypothesis until fitted to
## Prime's real sessions): reading at 200 words a minute, 4 s per choice,
## 25 s per planner booking, 6 s per fight action, 15 s per trip or menu.
##
## Run: godot --headless --path . -s tests/bot.gd -- [--seeds=N]

const WPM := 200.0
const SEC_CHOICE := 4.0
const SEC_BOOK := 25.0
const SEC_FIGHT_ACTION := 6.0
const SEC_MENU := 15.0

var s: GameState
var persona := "talker"
var secs := {}
var seg := "family"
var log_lines: Array = []
var failures: Array = []
var words := 0


func _init() -> void:
	var seeds := 6
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--seeds="):
			seeds = int(a.substr(8))
	var results: Array = []
	for p in ["talker", "fighter", "go_kit", "skeptic"]:
		for k in seeds:
			results.append(run(p, 1000 + k * 17))
	var by := {}
	for r in results:
		var key: String = r["persona"]
		if not by.has(key):
			by[key] = []
		by[key].append(r)
	var out := {"runs": results.size(), "failures": failures, "personas": {}}
	for key in by:
		var rs: Array = by[key]
		var mean := {}
		for segk in ["family", "act0", "dayzero", "act1", "total"]:
			var t := 0.0
			for r in rs:
				t += float(r["minutes"].get(segk, 0.0))
			mean[segk] = snappedf(t / rs.size(), 0.1)
		var ends := {}
		for r in rs:
			var e := "%s/%s" % [r["m1"], r["m2"]]
			ends[e] = int(ends.get(e, 0)) + 1
		var br := 0.0
		for r in rs:
			br += float(r["bedrock"])
		out["personas"][key] = {"mean_minutes": mean, "end_states": ends, "bedrock_mean": snappedf(br / rs.size(), 0.1), "sample": rs[0]}
	var txt := JSON.stringify(out, "  ")
	print(txt)
	var f := FileAccess.open("res://tests/bot_report.json", FileAccess.WRITE)
	if f != null:
		f.store_string(txt)
	quit(1 if not failures.is_empty() else 0)


func t(sec: float) -> void:
	secs[seg] = float(secs.get(seg, 0.0)) + sec


func read(text: String) -> void:
	var w := text.split(" ", false).size()
	words += w
	t(w / WPM * 60.0)


# ------------------------------------------------------------------ one run
func run(p: String, seed_v: int) -> Dictionary:
	persona = p
	secs = {}
	words = 0
	s = GameState.new(seed_v)
	seg = "family"
	t(150.0 if p != "skeptic" else 60.0)
	_family()
	seg = "act0"
	s.phase = "act0"
	for w in range(1, 9):
		_week()
	seg = "dayzero"
	_dayzero()
	seg = "act1"
	_act1()
	var total := 0.0
	var mins := {}
	for k in secs:
		mins[k] = snappedf(float(secs[k]) / 60.0, 0.1)
		total += float(secs[k])
	mins["total"] = snappedf(total / 60.0, 0.1)
	var m1 := String(s.quests.get("m1", {}).get("end", "none"))
	var m2 := String(s.quests.get("m2", {}).get("end", "none"))
	if m1 == "none" or m2 == "none":
		failures.append("%s seed %d: m1 %s m2 %s day %d where %s" % [p, seed_v, m1, m2, s.day, str(Act1.m1_status(s))])
	# Replay determinism: same seed, same commands, same hash.
	return {"persona": p, "seed": seed_v, "minutes": mins, "m1": m1, "m2": m2, "bedrock": Act0.bedrock_count(s),
		"profile": s.profile, "buyin": s.buyin_avg(), "kills": s.kills.size(), "words_read": words,
		"vehicles": s.vehicles.map(func(v: Dictionary) -> String: return "%s:%s" % [v["kind"], v["state"]]),
		"last_pin": s.last_pin, "hash": s.state_hash()}


func _family() -> void:
	var a: Dictionary = s.members["hero"]["attrs"]
	match persona:
		"fighter":
			a.merge({"sinew": 6, "reflex": 7, "awareness": 7, "discipline": 5, "tenacity": 5, "wits": 4, "empathy": 4}, true)
			s.specialties = ["firearms", "fieldcraft"]
			s.job = "road_crew"
		"go_kit":
			a.merge({"sinew": 5, "wits": 7, "awareness": 5, "discipline": 5, "empathy": 5, "reflex": 5, "tenacity": 6}, true)
			s.specialties = ["mechanics", "electronics"]
			s.job = "fab_tech"
		_:
			a.merge({"empathy": 7, "wits": 6, "awareness": 6, "discipline": 5, "reflex": 5, "sinew": 4, "tenacity": 5}, true)
			s.specialties = ["negotiation", "medicine"]
			s.job = "mechanic"
	var hero: Dictionary = s.members["hero"]
	for sp in s.specialties:
		hero["bonus"][sp] = int(hero["bonus"].get(sp, 0)) + 25
	var j := Act0.job_info(s.job)
	hero["bonus"][j["skill"]] = int(hero["bonus"].get(j["skill"], 0)) + int(j["bonus"])
	for r in GameState.ROLES:
		if r != "hero":
			s.members[r]["buyin"] = 20 + 3 * s.attr("hero", "empathy") if r != "partner" else 18 + 3 * s.attr("hero", "empathy")


# ------------------------------------------------------------------ Act 0
const PLANS := {
	"talker": ["sunday_dinner", "water_order", "clinic_visit", "porch_rounds", "paper_day", "warm_room", "bulk_run", "porch_rounds", "family_drill", "pharmacy_run", "porch_rounds", "library_day", "night_class", "antenna_day", "shield_kit", "dig_beds", "sunday_dinner", "overtime", "bulk_run", "porch_rounds", "ruck", "sunday_dinner", "overtime", "sunday_dinner"],
	"fighter": ["counter_day", "water_order", "bulk_run", "warm_room", "porch_rounds", "clinic_visit", "paper_day", "family_drill", "counter_day", "sunday_dinner", "porch_rounds", "night_class", "pharmacy_run", "ruck", "porch_rounds", "sunday_dinner", "buy_truck", "wrench_day", "overtime", "ruck", "sunday_dinner", "overtime", "ruck", "sunday_dinner"],
	"go_kit": ["buy_rig", "water_order", "sunday_dinner", "clinic_visit", "warm_room", "porch_rounds", "power_kit", "seal_spares", "gear_run", "paper_day", "family_drill", "porch_rounds", "gear_run", "go_kit", "bulk_run", "porch_rounds", "counter_day", "antenna_day", "sunday_dinner", "overtime", "go_kit", "sunday_dinner", "overtime", "sunday_dinner"],
	"skeptic": ["overtime", "overtime", "bulk_run", "sunday_dinner", "overtime", "cash_out", "overtime", "sunday_dinner", "overtime", "overtime", "sunday_dinner", "overtime"],
}
var plan_i := 0


func _week() -> void:
	if s.week == 1:
		plan_i = 0
	Act0.start_week(s)
	t(SEC_MENU * 2)
	match s.week:
		1:
			_dialogue("cookout_intro")
			for d in ["cookout_arlo", "cookout_ruth", "cookout_teo"]:
				t(20.0)
				_dialogue(d)
			_dialogue("cookout_dog")
			_dialogue("cookout_end")
		4:
			_dialogue("pump_four")
		5:
			_dialogue("the_blow")
	# Signal Board: spend this week's checks on starred threads first.
	var order: Array = ["sky", "missiles", "machines", "ledgers", "fevers", "faultline", "ballots"]
	for th in order:
		var pins: Array = s.board.get(th, [])
		for i in pins.size():
			if Act0.checks_left(s) <= 0:
				break
			if Act0.check_pin(s, th, i):
				t(5.0)
	var plan: Array = PLANS[persona]
	var guard := 0
	while Act0.blocks_left(s) > 0 and guard < 12:
		guard += 1
		var id: String = plan[plan_i % plan.size()] if plan_i < plan.size() else "sunday_dinner"
		plan_i += 1
		var a := Act0.activity(id)
		if a.is_empty() or Act0.blocker(s, a) != "":
			continue
		var pick := ""
		if a.get("pick_skill", false):
			pick = "leadership" if persona == "talker" else ("mechanics" if persona == "go_kit" else "homestead")
			if id == "teach_teen":
				var ts := Act0.teachable_skills(s)
				if ts.is_empty():
					continue
				pick = ts[0]
		t(SEC_BOOK)
		read(a["text"])
		for ev in Act0.book(s, id, pick):
			_act0_event(ev)
	if s.week == 8:
		_dialogue("eve")
		s.last_pin = Act0.hunch(s)["thread"]
		t(20.0)
	Act0.end_week(s)


func _act0_event(ev: Array) -> void:
	match String(ev[0]):
		"gear":
			for id in ["food_bucket", "food_bucket", "med_bag", "fuel_can"]:
				Act0.buy_gear(s, id)
				t(6.0)
		"garage":
			t(60.0)
			for v in s.vehicles:
				if v["kind"] == "family_car":
					continue
				if s.flag("go_kit"):
					for id in s.items.keys():
						if id in ["food_bucket", "med_bag", "fuel_can", "power_station", "solar_panel", "water_filter", "camp_stove"]:
							while int(s.items.get(id, 0)) > 0 and Devices.load_item(s, v, id, true):
								pass
					for opt in ["tarp", "battery_off", "ferrites"]:
						if not (opt in v.get("mods", [])):
							Devices.toggle_mod(s, v, opt)
			if s.flag("seal_bag"):
				for id in ["handheld_radio", "phone", "laptop", "shortwave"]:
					Devices.seal(s, id)


# ------------------------------------------------------------------ dialogue
const PREFER := {
	"talker": ["talk", "know", "trade", "fix", "sneak", "fight"],
	"fighter": ["fight", "fix", "know", "talk", "trade", "sneak"],
	"go_kit": ["fix", "know", "talk", "trade", "sneak", "fight"],
	"skeptic": ["sneak", "talk", "trade", "fix", "know", "fight"],
}


func _dialogue(id: String, extra: Dictionary = {}) -> Array:
	var d := Dialogue.new(s, id)
	d.extra = extra
	var events: Array = d._flush()
	var guard := 0
	while not d.done() and guard < 40:
		guard += 1
		read(d.text())
		var opts := d.options()
		var pick := -1
		var best := 99
		for o in opts:
			if not o["enabled"]:
				continue
			var fam: String = o["family"]
			var rank: int = PREFER[persona].find(fam) if fam != "" else 3
			if rank < 0:
				rank = 5
			if rank < best:
				best = rank
				pick = int(o["index"])
		if pick == -1 and not opts.is_empty():
			pick = int(opts[0]["index"])
		t(SEC_CHOICE)
		events.append_array(d.choose(pick))
	for ev in events:
		_event(ev)
	return events


func _event(ev: Array) -> void:
	match String(ev[0]):
		"battle":
			_battle(String(ev[1]))
		"garage", "gear":
			_act0_event(ev)
		"flash_report":
			Devices.flash(s)
			Act1.unpack(s, s.items)
			for v in s.vehicles:
				if v["kind"] != "family_car":
					Act1.unpack(s, v["load"])
			s.flags["vehicle_at"] = "home"
			t(40.0)


func _battle(enc: String) -> void:
	var c := Combat.new(s, enc)
	var guard := 0
	while c.outcome == "" and guard < 200:
		guard += 1
		if not c.is_player_turn():
			c.end_turn()
			continue
		var a := c.active()
		var acted := false
		var best := ""
		var bh := 0
		for u in c.units:
			if u["team"] == "foe" and u["state"] == "ok" and c.can_attack(u, false) and c.hit_chance(a, u, false) > bh:
				bh = c.hit_chance(a, u, false)
				best = u["id"]
		if persona != "fighter" and a["role"] == "hero" and int(s.flags.get("callouts_this_fight", 0)) == 0 and int(a["ap"]) >= 2 and s.strain_band("hero") < 2:
			c.call_out()
			acted = true
		elif best != "":
			c.attack(best, false)
			acted = true
		else:
			var r := c.reach(a)
			var goal := Vector2i(-1, -1)
			for u in c.units:
				if u["team"] == "foe" and u["state"] == "ok":
					goal = u["cell"]
			var bc := Vector2i(-1, -1)
			var bd := Combat.dist(a["cell"], goal) if goal.x >= 0 else 0
			for cell in r:
				var dd := Combat.dist(cell, goal)
				if dd < bd:
					bd = dd
					bc = cell
			if bc.x >= 0:
				c.move(bc)
				acted = true
		t(SEC_FIGHT_ACTION)
		if not acted:
			c.end_turn()
		if c.parley_offered and c.outcome == "" and persona != "fighter":
			c.accept_parley()
	for f in c.downed_foes():
		c.resolve_down(f["id"], persona == "talker" and s.led("kits") > 0)
	var effects: Array = c.enc.get(c.outcome if c.outcome != "" else "win", [])
	Rules.apply(s, effects)
	c.write_back()
	t(30.0)


# ------------------------------------------------------------------ Day Zero and Act 1
func _dayzero() -> void:
	s.phase = "act1"
	s.day = 0
	s.watch = 2
	s.members["hero"]["where"] = "tvhwy"
	s.members["partner"]["where"] = "hospital"
	s.members["teen"]["where"] = "home" if s.flag("rally_rehearsed") else "school"
	s.members["child"]["where"] = "home"
	s.members["elder"]["where"] = "sorrel"
	if s.buyin_avg() >= 75:
		s.set_flag("partner_walking")
	if s.last_pin == "sky":
		s.add_buyin(5)
	_dialogue("breakfast")
	_dialogue("dz_flash")
	for d in ["dz_phone", "dz_sky", "dz_pickup", "dz_driver", "dz_bikeshop"]:
		t(25.0)
		_dialogue(d)
	_dialogue("dz_diagnosis", {"clue_list": ", ".join(s.clues)})
	if not s.flag("diagnosed"):
		failures.append("%s: diagnosis not reached" % persona)
		s.set_flag("diagnosed")
		_event(["flash_report"])
	var w := 1 if s.flag("dell_ride") or s.flag("took_bike") else 2
	for i in w:
		Act1.advance_watch(s)
	s.members["hero"]["where"] = "home"
	_dialogue("home_day0", {"garage_report": "", "home_report": ""})


func _go(to: String) -> void:
	var modes := Act1.travel_modes(s)
	var mode: String = "vehicle" if "vehicle" in modes else ("bicycle" if "bicycle" in modes else "foot")
	var party: Array = []
	for r in ["partner", "teen", "elder"]:
		if s.members[r]["where"] == s.members["hero"]["where"] and s.members["hero"]["where"] != "home":
			party.append(r)
	var n: Dictionary = Act1.nodes()[to]
	if n.has("approach") and not s.flag("crossed_" + to):
		s.set_flag("crossed_" + to)
		_dialogue(n["approach"])
	Act1.travel(s, to, mode, party)
	_auto_moves()
	t(SEC_MENU)
	if n.has("dialogue"):
		_dialogue(n["dialogue"])
	if to == "home":
		Act1.check_m1(s)
		_nights()


func _auto_moves() -> void:
	if s.flag("partner_walking") and s.day >= 2 and s.members["partner"]["where"] == "hospital" and not s.flag("partner_stays"):
		s.members["partner"]["where"] = "home"
	if s.members["teen"]["where"] == "school" and s.day >= 2:
		s.members["teen"]["where"] = "home"
		s.add_strain("teen", 15)
	if s.members["partner"]["where"] == "hospital" and not s.flag("partner_stays") and s.day >= 4:
		s.members["partner"]["where"] = "home"


func _nights() -> void:
	for k in Act1.knocks_for_night(s):
		if not s.flag("knock_%s_%d" % [k, s.day]):
			s.set_flag("knock_%s_%d" % [k, s.day])
			if k == "knock_ruth":
				if s.flag("ruth_knock_done"):
					continue
				s.set_flag("ruth_knock_done")
			_dialogue(k)


func _act1() -> void:
	# Order: school, care home, hospital, home; then the week at home.
	if s.members["teen"]["where"] == "school":
		_go("school")
	_go("sorrel")
	_go("home")
	_go("hospital")
	_go("home")
	_dialogue("relay_radio", {"radio_state": ""})
	var guard := 0
	while s.day < Act1.LAST_DAY and guard < 40:
		guard += 1
		if s.day >= 1 and not s.flag("thaw_done"):
			t(20.0)
			_dialogue("thaw")
		if s.day >= 2 and String(s.quests.get("m2", {}).get("state", "")) != "done":
			t(20.0)
			_dialogue("lantern_meeting", {"day": str(s.day), "tap_state": "are dry" if s.day >= 3 else "still trickle"})
		Act1.wait_until(s, 3)
		_nights()
		Act1.wait_until(s, 0)
		_auto_moves()
		Act1.check_m1(s)
		t(SEC_MENU)
	Act1.check_m1(s)
	_dialogue("day7")
	if s.flag("partner_stays"):
		s.members["partner"]["where"] = "home"
	Act1.check_m1(s)
