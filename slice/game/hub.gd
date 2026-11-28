class_name Hub
extends RefCounted
## Act 0 weeks on the street map. Every errand is a place you walk to (your car,
## garage, front door, mailbox, the bus stop, each neighbor's door), and every
## week adds one hands-on task that teaches a mechanic (plan: Act 0 tutorial
## requirement, at most 20 minutes of teaching spread over the weeks).

## Where everything stands on the street: maps/court.json "spots", written by
## tools/make_content.py, which checks every spot is reachable.
static func spot(key: String) -> Array:
	return Rules.db("maps/court")["spots"][key]


static func doors() -> Dictionary:
	return Rules.db("maps/court")["spots"]["doors"]


static func drill_spots() -> Dictionary:
	return {"partner": spot("drill_partner"), "teen": spot("drill_teen"), "child": spot("drill_child"), "elder": spot("drill_elder")}

## One line per week: what the task is and what it teaches.
const TASKS := {
	1: "Walk the street. Your car is for shopping, your garage for projects, your front door for family. Each errand uses time from the week.",
	2: "Ruth wants help with the street's check-on chain. Find her on her porch (orange marker). Teaches skill checks.",
	3: "Arlo is heading to the shooting range and wants company. Find him by his house. Teaches fights.",
	4: "Fuel is getting scarce. Errands as usual; the gas station is on the way to anything.",
	5: "A windstorm is forecast for the weekend.",
	6: "Teo has something for you: a shielding bag. Find him by his ladder. Teaches sealing gear and the garage.",
	7: "Run a family drill tonight: everyone scatters, you bring them home. Talk to {partner.name} by your door. Teaches the rally plan.",
	8: "Inez listens to the ham radio every night. Find her on her porch. Teaches the Signal Board.",
}

var sc: Screens
var m: Node
var s: GameState
var ex: Explore


func _init(screens: Screens) -> void:
	sc = screens
	m = screens.m


func _hint_once(key: String, text: String) -> void:
	if not s.flag("hint_" + key):
		s.set_flag("hint_" + key)
		m.toast(s.fill(text), 6.0)


func variant() -> Dictionary:
	var objs: Array = [
		{"id": "st_car", "name": "Your car: shopping runs", "prop": "truck_x" if s.vehicles.any(func(v: Dictionary) -> bool: return v["kind"] != "family_car") else "car_x", "cell": spot("car"), "event": "station:supply"},
		{"id": "st_garage", "name": "Your garage: projects and the Go Kit", "prop": "none", "cell": spot("garage"), "event": "station:site"},
		{"id": "st_door", "name": "Your front door: family, the fridge card, end the week", "prop": "none", "cell": spot("home_door"), "event": "station:door"},
		{"id": "st_mail", "name": "Mailbox and porch radio: the Signal Board", "prop": "mailbox", "cell": spot("mail"), "event": "board"},
		{"id": "st_bus", "name": "Bus stop: classes, work, the library, the hills", "prop": "busstop", "cell": spot("bus"), "event": "station:out"},
	]
	var dd := doors()
	for h in dd:
		var d := {"id": "door_" + h, "name": "%s's door: porch visit" % GameState.HOUSEHOLDS[h], "prop": "none", "cell": dd[h], "event": "porch:" + h}
		if h == "quan" and s.flag("quan_card") and not s.flag("quan_done"):
			d["name"] = "Marisol Quan's door: deliver Ruth's card"
			d.erase("event")
			d["dialogue"] = "quan_card"
			d["task"] = true
		objs.append(d)
	var npcs: Array = []
	var w := s.week
	if w >= 2 and not s.flag("ruth_chain_done"):
		npcs.append({"id": "ruth_t", "name": "Ruth Pellow", "look": "char_elder", "cell": spot("ruth"), "dialogue": "ruth_chain", "task": true, "after_flag": "ruth_chain_done"})
	else:
		npcs.append({"id": "ruth_l", "name": "Ruth Pellow", "look": "char_elder", "cell": spot("ruth"), "line": ["\"Morning.\"", "\"Morning.\"", "\"The chain's on my fridge.\"", "\"Gas line at the Fred Meyer went round the block.\"", "\"Wind's coming. I can feel it in my knee.\"", "\"Still got your card.\"", "\"Kids should know where to go. Ours never did.\"", "\"Something's off this week. I can't name it.\""][clampi(w - 1, 0, 7)]})
	if w >= 3 and not s.flag("range_done"):
		npcs.append({"id": "arlo_t", "name": "Arlo Dunmore", "look": "char_trader", "cell": spot("arlo"), "dialogue": "arlo_range", "task": true})
	if w >= 6 and not s.flag("teo_bag_given"):
		npcs.append({"id": "teo_t", "name": "Teo Lisk", "look": "char_survivor", "cell": spot("teo"), "dialogue": "teo_bag", "task": true})
	if w >= 7 and not s.flag("drill_done"):
		npcs.append({"id": "partner_t", "name": "{partner.name}", "look": "char_medic", "role": "partner", "cell": spot("partner"), "event": "task:drill", "task": true})
	if w >= 8 and not s.flag("inez_radio"):
		npcs.append({"id": "inez_t", "name": "Inez Varga", "look": "char_survivor", "cell": spot("inez"), "dialogue": "inez_radio", "task": true, "after": "board"})
	return {"night": false, "spawn": spot("hub_spawn"), "npcs": npcs, "objects": objs}


func show() -> void:
	s = m.s
	m.clear_screen()
	m.set_segment("act0")
	sc.planner_filter = []
	ex = Explore.new()
	m.host_world(ex)
	ex.setup(s, "court", "", variant())
	ex.set_view(m.RENDER_SCALE, m.get_viewport().get_visible_rect().size.y)
	ex.hint.connect(func(t: String) -> void: m.toast(t))
	ex.interact.connect(_interact)
	# Start the camera on this week's task, then let it glide back to you.
	for t in ex.targets:
		if t["data"].get("task", false):
			ex.camera.position = ex.cell_pos(t["cell"])
			ex.follow = false
			var hold := ex
			m.get_tree().create_timer(2.5).timeout.connect(func() -> void:
				if is_instance_valid(hold) and hold.is_inside_tree():
					hold.follow = true)
			break
	m.refresh_status()
	if not s.flag("hub_intro_%d" % s.week):
		s.set_flag("hub_intro_%d" % s.week)
		_week_card()
	elif Act0.blocks_left(s) == 0:
		m.toast("No time left this week. Walk to your front door to end it.", 5.0)


func _week_card() -> void:
	sc.popup("Week %d · %s" % [s.week, Screens.week_dates(s.week)], func(b: VBoxContainer) -> void:
		var heads: Array = Act0.threads()["headlines"].get(str(s.week), [])
		if not heads.is_empty():
			UI.rich("[b]In the news:[/b] " + " · ".join(heads.map(func(x: String) -> String: return x.split(" (")[0])), b, 16)
		UI.rich("[b]This week:[/b] " + s.fill(TASKS.get(s.week, "")), b, 16)
		UI.rich("[b]Your time:[/b] %d blocks. An errand or project uses one or two. Walk to a place and tap it to see what you can do there.\n[b]The fridge card:[/b] Bedrock %d of 7. Next gap: %s" % [Act0.blocks_left(s), Act0.bedrock_count(s), s.fill(Act0.fridge_gap(s))], b, 15)
	, Callable(), "Go outside")


func _refresh() -> void:
	# Re-host so tasks that finished or opened show up.
	show()


func _interact(t: Dictionary) -> void:
	if t.has("dialogue"):
		m.run_dialogue(t["dialogue"], func() -> void:
			if t.has("after_flag"):
				s.set_flag(t["after_flag"])
			if t.get("after", "") == "board" and s.flag("inez_radio"):
				sc.show_board(_refresh)
			else:
				_refresh())
		return
	if t.has("line"):
		m.toast(s.fill("%s: %s" % [t["name"], t["line"]]), 4.0)
		return
	var ev: String = t.get("event", "")
	if ev.begins_with("station:"):
		_station(ev.substr(8))
	elif ev == "board":
		_hint_once("board", "The Signal Board: the news about what might be coming. Look into stories to see which hold up.")
		sc.show_board(_refresh)
	elif ev.begins_with("porch:"):
		_porch(ev.substr(6))
	elif ev == "task:drill":
		start_drill()


func _station(kind: String) -> void:
	match kind:
		"supply":
			_hint_once("car", "Shopping runs stock the house. Some things ship weeks later. Buying in bulk gets you noticed: Profile goes up.")
			sc.planner_filter = ["Supply"]
			sc.show_planner()
		"site":
			_hint_once("garage", "Projects around the house. If you own a vehicle, the Garage button sets up its load and hardening.")
			sc.planner_filter = ["Site"]
			sc.show_planner()
		"out":
			_hint_once("bus", "Out in town: a class raises a skill to 35, overtime pays, the library gives Signal Board looks.")
			sc.planner_filter = ["Train", "Work", "Research", "Fitness"]
			sc.show_planner()
		"door":
			_door()


func _door() -> void:
	sc.popup("Your front door", func(b: VBoxContainer) -> void:
		UI.rich("Bedrock %d of 7 on the fridge card. Next gap: %s.\n%d blocks of time left this week." % [Act0.bedrock_count(s), s.fill(Act0.fridge_gap(s)), Act0.blocks_left(s)], b, 16)
		UI.button("Family time and errands at home", func() -> void:
			sc.close_popup()
			sc.planner_filter = ["Family", "Neighbors"]
			sc.show_planner(), b, 300)
		UI.button("Every activity as one list", func() -> void:
			sc.close_popup()
			sc.planner_filter = ["*"]
			sc.show_planner(), b, 300)
		var end_txt := "End week %d and sleep" % s.week if s.week < 8 else "Go to bed: it's Halloween tomorrow"
		var eb := UI.button(end_txt + (" (%d blocks unused)" % Act0.blocks_left(s) if Act0.blocks_left(s) > 0 else ""), func() -> void:
			sc.close_popup()
			sc.end_week(), b, 300)
		if Act0.blocks_left(s) == 0:
			eb.modulate = Color(1.0, 0.85, 0.55)
	)


func _porch(h: String) -> void:
	var name: String = GameState.HOUSEHOLDS[h]
	var tr := int(s.neighbors.get(h, 0))
	sc.popup("%s's porch" % name, func(b: VBoxContainer) -> void:
		UI.rich("Trust with %s: [b]%d of 3[/b]. A household that trusts you shares, warns and helps. Three trusting households complete the Circle on the fridge card." % [name, tr], b, 16)
		var why := ""
		if tr >= 3:
			why = "They already trust you all the way."
		elif int(s.neighbor_week.get(h, 0)) == s.week:
			why = "You already visited this week."
		elif Act0.blocks_left(s) < 1:
			why = "No time left this week."
		elif Act0.spendable(s) < 20:
			why = "Needs $20."
		if why != "":
			UI.label(why, b, 15, UI.BAD)
		else:
			UI.button("Bring a pie and stay a while (1 block, $20): Trust +1", func() -> void:
				s.blocks_used += 1
				Act0.pay(s, 20)
				s.neighbors[h] = tr + 1
				s.neighbor_week[h] = s.week
				s.add_log("Porch visit: %s trusts you more (Trust %d)." % [name, tr + 1])
				m.save_game()
				sc.close_popup()
				m.refresh_status()
				m.toast("%s trusts you more: %d of 3." % [name, tr + 1]), b, 360)
	)


# ------------------------------------------------------------------ week 5: the dark
func start_blow_search() -> void:
	s = m.s
	var v := {"night": true, "force_night": true, "spawn": spot("home_door"), "npcs": [
		{"id": "child_lost", "name": "{child.name}", "look": "char_civilian", "role": "child", "scale": 0.75, "cell": spot("lost_child"), "event": "blow:child", "task": true}],
		"objects": [{"id": "dog_lost", "name": "{dog.name}, barking", "prop": "none", "cell": spot("lost_dog"), "event": "blow:dog", "task": true},
			{"id": "home_back", "name": "Your front door", "prop": "none", "cell": spot("home_back"), "event": "blow:home"}]}
	m.clear_screen()
	ex = Explore.new()
	m.host_world(ex)
	ex.setup(s, "court", "", v)
	ex.set_view(m.RENDER_SCALE, m.get_viewport().get_visible_rect().size.y)
	ex.hint.connect(func(t: String) -> void: m.toast(t))
	_found = {}
	ex.interact.connect(_blow_interact)
	m.toast(s.fill("It's dark. You can see %d tiles around you%s. {child.name} went west toward the Achterbergs; the barking is off to the northeast. Find both, then come back to the door." % [ex.sight_now(), " by lantern" if ex.lit else ""]), 7.0)


var _found: Dictionary = {}


func _blow_interact(t: Dictionary) -> void:
	match String(t.get("event", "")):
		"blow:child":
			_found["child"] = true
			ex.remove_target("child_lost")
			m.toast(s.fill("{child.name} is behind the Achterbergs' hedge, shaking and soaked. \"I heard {dog.name}!\""), 5.0)
		"blow:dog":
			_found["dog"] = true
			ex.remove_target("dog_lost")
			m.toast(s.fill("{dog.name} is wedged under the Lisks' porch. You drag {dog.name} out by the collar."), 5.0)
		"blow:home":
			if _found.size() < 2:
				m.toast("Not everyone is back yet.")
				return
			_blow_home(ex.sight_now())


func _blow_home(sight: int) -> void:
	m.clear_world()
	s.add_buyin(3)
	s.add_led("inhalers", -1)
	s.add_log(s.fill("The Blow: found {child.name} and {dog.name} in the dark."))
	var txt := s.fill("Everyone is in the kitchen. {child.name} uses an extra inhaler-day.\n\n[b]How it works:[/b] in the dark you see only %d tiles around you. A working lantern lights 6. After Day Zero most nights are like this one, and lanterns that weren't shielded may be dead." % sight)
	sc.popup("Home", func(b: VBoxContainer) -> void: UI.rich(txt, b, 16), func() -> void: m.run_dialogue("the_blow_after", show), "Next")


# ------------------------------------------------------------------ week 7: the drill


func start_drill() -> void:
	s = m.s
	var npcs: Array = []
	var ds := drill_spots()
	for r in ds:
		npcs.append({"id": "drill_" + r, "name": "{%s.name}" % r, "look": {"partner": "char_medic", "elder": "char_elder"}.get(r, "char_civilian"), "role": r,
			"scale": 0.75 if r == "child" else 1.0, "cell": ds[r], "event": "drill:" + r, "task": true})
	var v := {"night": true, "force_night": true, "spawn": spot("home_door"), "npcs": npcs,
		"objects": [{"id": "rally", "name": "The rally point: your front door", "prop": "none", "cell": spot("home_back"), "event": "drill:home"}]}
	m.clear_screen()
	ex = Explore.new()
	m.host_world(ex)
	ex.setup(s, "court", "", v)
	ex.set_view(m.RENDER_SCALE, m.get_viewport().get_visible_rect().size.y)
	ex.hint.connect(func(t: String) -> void: m.toast(t))
	_sent = {}
	ex.interact.connect(_drill_interact)
	m.toast(s.fill("Drill: the lights are off on purpose. {partner.name} is at Inez's, {teen.name} at Teo's, {child.name} at Marisol's, {elder.name} at Arlo's. Send each one home, then go to your door."), 9.0)


var _sent: Dictionary = {}


func _drill_interact(t: Dictionary) -> void:
	var ev := String(t.get("event", ""))
	if ev == "drill:home":
		if _sent.size() < drill_spots().size():
			m.toast("%d of %d are home. Find the rest." % [_sent.size(), drill_spots().size()])
			return
		_drill_done(ex.steps_walked)
	elif ev.begins_with("drill:"):
		var r := ev.substr(6)
		_sent[r] = true
		ex.remove_target("drill_" + r)
		m.toast(s.fill("{%s.name} heads for the rally point." % r))


func _drill_done(steps: int) -> void:
	m.clear_world()
	s.set_flag("drill_done")
	s.add_buyin(3)
	var cards := s.flag("rally_cards")
	if cards:
		s.set_flag("rally_rehearsed")
	s.add_log("Family drill at night: %d steps. %s" % [steps, "The rally plan is rehearsed." if cards else "No rally cards yet."])
	m.save_game()
	sc.popup("Drill done", func(b: VBoxContainer) -> void:
		UI.rich("You walked %d steps to gather everyone. Buy-in +3.\n\n" % steps + (
			"The rally cards were on the fridge, so everyone knew the plan. [b]The rally plan is rehearsed[/b]: on Day Zero, family who are away head home on their own." if cards else
			"Nobody had a rally card, so you had to fetch everyone. On Day Zero you won't be able to. Paper Day (in your garage list) makes rally cards; do the drill again after."), b, 16)
	, show, "Back to the street")
