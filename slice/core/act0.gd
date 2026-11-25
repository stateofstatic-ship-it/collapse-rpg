class_name Act0
extends RefCounted
## The Long Autumn (prep90.md), condensed for the slice: eight weeks of three
## blocks, orders with lead times, the Bedrock, Buy-in, Profile, the Signal
## Board, and the scenes that interrupt weeks 1, 4, 5 and 8.

const BLOCKS_PER_WEEK := 3
const CARD_LIMIT := 2000
const SCENES := {1: "cookout", 4: "pump_four", 5: "the_blow", 8: "eve"}
const BEDROCK_NAMES := {"water": "Water", "pantry": "Pantry", "warmth": "Warmth", "medicine": "Medicine", "circle": "Circle", "plan": "Plan", "skills": "Skills"}
const GEAR := {
	"_note": "Gear Run prices: rough 2020s retail (hypothesis). Placeholder until the prep-kit thread's catalog lands.",
	"food_bucket": 120, "water_jugs": 30, "med_bag": 250,
	"fuel_can": 45, "spare_parts": 150, "handheld_radio": 35, "shortwave": 80, "oil_lantern": 30,
	"camp_stove": 70, "body_armor": 450, "pistol": 550,
}


static func activities() -> Array:
	return Rules.db("activities")["activities"]


static func activity(id: String) -> Dictionary:
	for a in activities():
		if a["id"] == id:
			return a
	return {}


static func jobs() -> Array:
	return Rules.db("activities")["jobs"]


static func job_info(id: String) -> Dictionary:
	for j in jobs():
		if j["id"] == id:
			return j
	return jobs()[0]


static func blocks_left(s: GameState) -> int:
	return BLOCKS_PER_WEEK - s.blocks_used


static func spendable(s: GameState) -> int:
	return s.money + (CARD_LIMIT - s.card)


## Why an activity cannot be booked now, or "" if it can.
static func blocker(s: GameState, a: Dictionary) -> String:
	if int(a["blocks"]) > blocks_left(s):
		return "Needs %d blocks" % int(a["blocks"])
	if int(a["money"]) > spendable(s):
		return "Needs $%d" % int(a["money"])
	if a.has("last_week") and s.week > int(a["last_week"]):
		return "Too late: orders after Oct 17 miss Day Zero"
	if a.has("weeks") and not (s.week in a["weeks"]):
		return "Cohorts start weeks 2, 4, 6"
	if a.has("per_week") and int(s.activity_counts.get("%s@%d" % [a["id"], s.week], 0)) >= int(a["per_week"]):
		return "Once a week"
	if a.has("req") and not Rules.check(s, a["req"]):
		var r: Array = a["req"][0]
		match String(r[0]):
			"buyin":
				return "Needs family Buy-in %d" % int(r[1])
			"has_vehicle":
				return "Needs a vehicle"
			"flag":
				return "Needs the truck"
			_:
				return "Already done"
	if a["id"] == "teach_teen" and teachable_skills(s).is_empty():
		return "Needs a hero skill at 35"
	return ""


static func pay(s: GameState, amount: int) -> void:
	s.money -= amount
	if s.money < 0:
		s.card += -s.money
		s.money = 0


## Book an activity. pick is the skill for Night Class or Teach. Returns events.
static func book(s: GameState, id: String, pick: String = "") -> Array:
	var a := activity(id)
	if a.is_empty() or blocker(s, a) != "":
		return []
	s.blocks_used += int(a["blocks"])
	pay(s, int(a["money"]))
	var key := "%s@%d" % [id, s.week]
	s.activity_counts[key] = int(s.activity_counts.get(key, 0)) + 1
	s.activity_counts[id] = int(s.activity_counts.get(id, 0)) + 1
	s.week_log.append({"week": s.week, "id": id, "pick": pick})
	if int(a.get("lead", 0)) > 0:
		s.orders.append({"activity": id, "arrive": s.week + int(a["lead"])})
		s.add_log("Ordered %s: arrives week %d." % [a["name"], s.week + int(a["lead"])])
		return []
	return _run(s, a, pick)


static func _run(s: GameState, a: Dictionary, pick: String) -> Array:
	var out: Array = []
	for ev in Rules.apply(s, a["effects"]):
		match String(ev[0]):
			"class":
				var b: Dictionary = s.members["hero"]["bonus"]
				b[pick] = int(b.get(pick, 0)) + 15
				var short := 35 - s.skill_base("hero", pick)
				if short > 0:
					b[pick] = int(b[pick]) + short
				s.classes.append(pick)
				s.add_log("Night Class: %s certified at %d." % [GameState.SKILL_NAMES[pick], s.skill_base("hero", pick)])
			"teach":
				var cap := s.skill_base("hero", pick) - 10
				var tb: Dictionary = s.members["teen"]["bonus"]
				var cur := s.skill_base("teen", pick)
				var gain := clampi(cap - cur, 0, 10)
				tb[pick] = int(tb.get(pick, 0)) + gain
				s.add_log("{teen.name} learned %s: now %d." % [GameState.SKILL_NAMES[pick], s.skill_base("teen", pick)])
			"porch":
				var raised := 0
				var order: Array = s.neighbors.keys()
				order.sort_custom(func(x: String, y: String) -> bool: return int(s.neighbors[x]) < int(s.neighbors[y]))
				for h in order:
					if raised >= 2:
						break
					if int(s.neighbors[h]) < 3 and int(s.neighbor_week[h]) != s.week:
						s.neighbors[h] = int(s.neighbors[h]) + 1
						s.neighbor_week[h] = s.week
						raised += 1
						s.add_log("%s trusts you more (Trust %d)." % [GameState.HOUSEHOLDS[h], s.neighbors[h]])
			"overtime":
				s.money += int(round(job_info(s.job)["pay"] * 0.4))
			"drill":
				if s.flag("rally_cards"):
					s.set_flag("rally_rehearsed")
					s.add_log("Drill: the rally plan is rehearsed.")
				else:
					s.add_log("Drill without rally cards: everyone agrees to meet at home, nothing written down.")
				s.add_buyin(2)
			"family_time":
				s.set_flag("family_week_%d" % s.week)
			"gear":
				s.flags["gear_left"] = 4
				out.append(ev)
			_:
				out.append(ev)
	return out


static func teachable_skills(s: GameState) -> Array:
	var out: Array = []
	for k in GameState.SKILLS:
		if s.skill_base("hero", k) >= 35 and s.skill_base("teen", k) < s.skill_base("hero", k) - 10:
			out.append(k)
	return out


## Gear Run: one item from the shop list, no block cost once the Gear Run block is booked.
static func buy_gear(s: GameState, id: String) -> bool:
	if not GEAR.has(id) or int(GEAR[id]) > spendable(s) or int(s.flags.get("gear_left", 0)) <= 0:
		return false
	s.flags["gear_left"] = int(s.flags["gear_left"]) - 1
	pay(s, int(GEAR[id]))
	s.items[id] = int(s.items.get(id, 0)) + 1
	if id == "food_bucket" or id == "water_jugs":
		s.tracks["stores"] = minf(3.0, float(s.tracks["stores"]) + 0.1)
	return true


# ------------------------------------------------------------------ weeks
static func start_week(s: GameState) -> Array:
	var landed: Array = []
	var keep: Array = []
	for o in s.orders:
		if int(o["arrive"]) <= s.week:
			var a := activity(o["activity"])
			_run(s, a, "")
			landed.append(a["name"])
			s.add_log("Delivered: " + String(a["name"]))
		else:
			keep.append(o)
	s.orders = keep
	board_new_pins(s)
	return landed


static func end_week(s: GameState) -> void:
	var j := job_info(s.job)
	var pay_amt := int(j["pay"])
	if s.job_standing >= 80:
		pay_amt = int(round(pay_amt * 1.1))
	if s.job_standing > 0:
		s.money += pay_amt
	if not s.flag("family_week_%d" % s.week):
		s.add_buyin(-2)
	# Each Bedrock item met raises Buy-in once (the fridge card).
	var br := bedrock(s)
	for k in br:
		if br[k]["met"] and not s.flag("bedrock_met_" + k):
			s.set_flag("bedrock_met_" + k)
			s.add_buyin(3)
			s.add_log("Bedrock met: %s. Family Buy-in +3." % BEDROCK_NAMES[k])
	if s.week == 4 or s.week == 8:
		var owed := s.card - 500
		if owed > 0:
			s.add_buyin(-int(owed / 250))
	s.week += 1
	s.blocks_used = 0
	if s.week > 8:
		s.phase = "dayzero"


static func fridge_gap(s: GameState) -> String:
	var br := bedrock(s)
	for k in ["water", "pantry", "medicine", "warmth", "plan", "circle", "skills"]:
		if not br[k]["met"]:
			return "%s: %s" % [BEDROCK_NAMES[k], br[k]["need"]]
	return "The Bedrock is met. Everything else is a bet."


## The seven Bedrock items (plan.md), each {met, need}.
static func bedrock(s: GameState) -> Dictionary:
	var water := s.led("water") + s.led("heater_water")
	var skills_at := 0
	for k in GameState.TRANSFERABLE:
		if s.skill_base("hero", k) >= 35 or s.skill_base("teen", k) >= 35:
			skills_at += 1
	var circle := s.trusting_households(2)
	return {
		"water": {"met": water >= 14 and s.flag("filter"), "need": "%d of 14 water-days%s" % [water, "" if s.flag("filter") else ", no filter"]},
		"pantry": {"met": s.led("food") >= 30, "need": "%d of 30 food-days" % s.led("food")},
		"warmth": {"met": s.flag("stove") and s.flag("co_alarm") and s.led("heat") >= 30, "need": "%d of 30 heat-days%s" % [s.led("heat"), "" if s.flag("co_alarm") else ", no CO alarm"]},
		"medicine": {"met": s.led("kits") >= 2 and s.led("inhalers") >= 90 and int(s.members["partner"]["buyin"]) >= 40,
			"need": "%d of 90 inhaler-days, %d of 2 kits, {partner.name} Buy-in %d of 40" % [s.led("inhalers"), s.led("kits"), int(s.members["partner"]["buyin"])]},
		"circle": {"met": circle >= 3, "need": "%d of 3 trusting households" % circle},
		"plan": {"met": s.flag("rally_cards") and s.flag("rally_rehearsed"), "need": ("rally cards" if not s.flag("rally_cards") else "") + ("" if s.flag("rally_rehearsed") else " not rehearsed")},
		"skills": {"met": skills_at >= 2, "need": "%d of 2 transferable skills at 35" % skills_at},
	}


static func bedrock_count(s: GameState) -> int:
	var n := 0
	var br := bedrock(s)
	for k in br:
		if br[k]["met"]:
			n += 1
	return n


static func buyin_tier(avg: int) -> String:
	if avg >= 75:
		return "All In"
	if avg >= 50:
		return "On Board"
	if avg >= 25:
		return "Going Along"
	return "Humoring You"


static func profile_tier(p: int) -> String:
	if p >= 45:
		return "Marked"
	if p >= 30:
		return "Talked About"
	if p >= 15:
		return "Noticed"
	return "Gray"


# ------------------------------------------------------------------ Signal Board
static func threads() -> Dictionary:
	return Rules.db("activities")["threads"]


static func odds(thread: String, truth: String, w: int) -> int:
	var t := threads()
	var i := clampi(w - 1, 0, 7)
	if thread == truth:
		return int(t["true_odds"][i])
	if thread == String(t["herring"]):
		return int(t["herring_odds"][i])
	return int(t["decoy_odds"][i])


static func board_new_pins(s: GameState) -> void:
	var truth := "sky"
	var r := s.rng("board")
	for th in threads()["names"]:
		var pins: Array = s.board.get(th, [])
		for kind in ["Print", "Air"]:
			var solid := r.randi_range(1, 100) <= odds(th, truth, s.week)
			pins.append({"week": s.week, "kind": kind, "solid": solid, "checked": false})
		s.board[th] = pins
	s.save_rng("board", r)


static func checks_per_week(s: GameState) -> int:
	return 2 + int(s.attr("hero", "awareness") / 2) + int(s.skill("hero", "signals") / 20)


static func checks_left(s: GameState) -> int:
	var used := int(s.activity_counts.get("checks@%d" % s.week, 0))
	return checks_per_week(s) + s.checks_bonus - used


static func check_pin(s: GameState, thread: String, idx: int) -> bool:
	if checks_left(s) <= 0:
		return false
	var p: Dictionary = s.board[thread][idx]
	if p["checked"]:
		return false
	if p["kind"] == "Air" and s.skill("hero", "signals") < 20 and float(s.tracks["radio"]) < 0.5:
		return false
	p["checked"] = true
	var key := "checks@%d" % s.week
	if checks_per_week(s) - int(s.activity_counts.get(key, 0)) <= 0:
		s.checks_bonus -= 1
	else:
		s.activity_counts[key] = int(s.activity_counts.get(key, 0)) + 1
	return true


## Posterior that each thread is the true one, from checked pins at the
## known odds (prep90.md: the hunch names the true posterior).
static func posterior(s: GameState) -> Dictionary:
	var names: Array = threads()["names"].keys()
	var w := {}
	var total := 0.0
	for hyp in names:
		var p := 1.0
		for th in names:
			for pin in s.board.get(th, []):
				if not pin["checked"]:
					continue
				var o := odds(th, hyp, int(pin["week"])) / 100.0
				p *= o if pin["solid"] else (1.0 - o)
		w[hyp] = p
		total += p
	for hyp in names:
		w[hyp] = float(w[hyp]) / total if total > 0.0 else 1.0 / names.size()
	return w


static func hunch(s: GameState) -> Dictionary:
	var post := posterior(s)
	var best := ""
	var bp := -1.0
	for k in post:
		if float(post[k]) > bp:
			bp = float(post[k])
			best = k
	var label := "Murky"
	if bp >= 0.7 and s.week >= 5:
		label = "Strong Lead"
	elif bp >= 0.4:
		label = "Leaning"
	return {"thread": best, "p": bp, "label": label}
