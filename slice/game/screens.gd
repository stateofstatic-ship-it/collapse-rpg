class_name Screens
extends RefCounted
## Every non-map screen and the slice's flow from the family screen to the
## end of Act 1. Reads GameState, sends commands to the core, never decides
## a rule itself.

const WEEK_DATES := ["Sep 6 to 12", "Sep 13 to 19", "Sep 20 to 26", "Sep 27 to Oct 3", "Oct 4 to 10", "Oct 11 to 17", "Oct 18 to 24", "Oct 25 to 31"]
const ROLE_LABELS := {"hero": "You, the Steward", "partner": "Partner: charge nurse at the hill hospital", "teen": "Teen, 16: distance runner", "child": "Child, 9: has asthma", "elder": "Elder, 74: your parent, a retired lineman"}
const TRAITS := {
	"mossback": ["Mossback", "+10 Fieldcraft and Homestead", "-10 Electronics and Signals", true],
	"webfoot": ["Webfoot", "Rain and mud never slow travel or cut sight", "+2 Strain a day on the Dry Side", false],
	"third_cup": ["Third Cup", "Morning coffee sheds 6 Strain, not 4", "No coffee: +4 Strain that day", false],
	"block_captain": ["Block Captain", "+10 Leadership; neighbors start friendlier", "Profile +15, permanently", true],
	"envelope": ["Envelope System", "Profile -15; $300 more in small bills", "No credit line in Act 0", true],
	"coffee_can": ["Coffee Can of Bolts", "The first repair each day uses no parts", "Carry -10 lb", false],
	"barbless": ["Barbless Hook", "Non-lethal attacks +10%; Mercy gains +50%", "Killing Strain doubled", false],
	"pull_start": ["Pull-Start Temper", "+2 AP the turn after first being hit", "Every break is Sees Red", false],
	"checklist": ["Laminated Checklist", "+1 AP in round one of a non-ambush fight", "Ambushed: +5 Strain, -4 Initiative", false],
	"boots": ["Sleeps in Boots", "Never surprised in camp or at home", "Sleep sheds 2 less Strain", false],
	"porch_light": ["Porch Light", "Home nights shed 3 more Strain", "After 3 days away: +2 Strain a day", false],
}

var m: Node
var resume_point := ""
var selected_activity := ""
var family_sel: Dictionary = {}


func _init(main: Node) -> void:
	m = main


var s: GameState:
	get:
		return m.s


static func week_dates(w: int) -> String:
	return WEEK_DATES[clampi(w - 1, 0, 7)]


func resume() -> void:
	match s.phase:
		"family":
			show_family_screen()
		"act0":
			show_week()
		"dayzero":
			start_dayzero()
		"act1":
			if s.members["hero"]["where"] == "home":
				go_court()
			else:
				show_worldmap()
		_:
			show_summary()


# ------------------------------------------------------------------ popups
func popup(heading: String, build: Callable, on_close: Callable = Callable(), close_text: String = "Close") -> void:
	var layer: Control = m.overlay
	UI.clear(layer)
	layer.mouse_filter = Control.MOUSE_FILTER_STOP
	var shade := ColorRect.new()
	shade.color = Color(0, 0, 0, 0.45)
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(shade)
	var mc := MarginContainer.new()
	mc.set_anchors_preset(Control.PRESET_FULL_RECT)
	var sz: Vector2 = m.get_viewport().get_visible_rect().size
	var side := maxi(UI.dp(10), int((sz.x - UI.dp(1000)) / 2))
	mc.add_theme_constant_override("margin_left", side)
	mc.add_theme_constant_override("margin_right", side)
	mc.add_theme_constant_override("margin_top", UI.dp(54))
	mc.add_theme_constant_override("margin_bottom", UI.dp(10))
	layer.add_child(mc)
	var p := UI.panel(mc)
	var v := UI.vbox(p)
	UI.title(heading, v)
	var sc := UI.scroll(v)
	var body := UI.vbox(sc)
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	build.call(body)
	UI.button(close_text, func() -> void:
		UI.clear(layer)
		layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
		m.refresh_status()
		if on_close.is_valid():
			on_close.call(), v, 200)


func close_popup() -> void:
	UI.clear(m.overlay)
	m.overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE


func show_ledger() -> void:
	popup("Household ledger", func(b: VBoxContainer) -> void:
		var L := s.ledger
		UI.rich("[b]Food[/b] %d food-days · [b]Water[/b] %d water-days stored + %d in the water heater%s · [b]Heat[/b] %d heat-days%s\n[b]Fuel[/b] %d gal · [b]Kits[/b] %d · [b]Inhalers[/b] %d days · [b]Components[/b] %d · [b]Rounds[/b] %d\n[b]Money[/b] $%d in the bank, $%d card balance, $%d small bills, $%d barter goods" % [
			L["food"], L["water"], L["heater_water"], ", filter" if s.flag("filter") else "", L["heat"], ", wood stove and CO alarm" if s.flag("stove") else "",
			L["fuel"], L["kits"], L["inhalers"], L["components"], L["rounds"], s.money, s.card, s.cash, s.barter], b)
		var tr := ""
		for t in GameState.TRACKS:
			if float(s.tracks[t]) > 0.0:
				tr += "%s %.1f · " % [GameState.TRACKS[t], float(s.tracks[t])]
		UI.rich("[b]Prep tracks[/b] " + (tr if tr != "" else "none yet"), b)
		var it := ""
		for id in s.items:
			if int(s.items[id]) > 0:
				it += "%s x%d, " % [Rules.item_name(id), int(s.items[id])]
		UI.rich("[b]In the house[/b] " + it, b)
		if not s.shielded.is_empty():
			var sh := ""
			for id in s.shielded:
				sh += "%s x%d, " % [Rules.item_name(id), int(s.shielded[id])]
			UI.rich("[b]Sealed locker[/b] " + sh, b)
		for v in s.vehicles:
			UI.rich("[b]%s[/b] hardening: %s · %s · load %d of %d lb" % [Rules.db("items")["vehicles"][v["kind"]]["name"], ", ".join(v.get("mods", [])) if not v.get("mods", []).is_empty() else "none", "dead" if v["state"] == "dead" else ("runs, Worn" if v.get("worn", false) else "runs"), int(Devices.load_weight(v)), int(Devices.capacity(v))], b)
		var nb := ""
		for h in s.neighbors:
			nb += "%s: Trust %d · " % [GameState.HOUSEHOLDS[h], int(s.neighbors[h])]
		UI.rich("[b]Neighbors[/b] " + nb, b)
		var st := ""
		for f in s.standing:
			if int(s.standing[f]) != 0:
				st += "%s %+d · " % [GameState.FACTIONS[f], int(s.standing[f])]
		UI.rich("[b]Word[/b] %+d · [b]Mercy[/b] %+d · [b]Standing[/b] %s" % [s.word, s.mercy, st if st != "" else "nobody knows you yet"], b))


func show_family_sheet() -> void:
	popup("Family", func(b: VBoxContainer) -> void:
		for r in GameState.ROLES:
			var mm: Dictionary = s.members[r]
			var band: int = s.strain_band(r)
			var where := String(mm["where"])
			UI.rich("[b]%s[/b] (%s) · %s · Buy-in %d · Strain %d %s · at %s" % [mm["name"], r, ["she/her", "he/him", "they/them"][["she", "he", "they"].find(mm["pronoun_key"])],
				int(mm["buyin"]), int(mm["strain"]), ["Steady", "Frayed", "Shaken", "Unmoored"][band], _place_name(where)], b)
		var h := ""
		for a in GameState.ATTRS:
			h += "%s %d · " % [GameState.ATTR_NAMES[a], s.attr("hero", a)]
		UI.rich("[b]%s's attributes[/b] %s" % [s.members["hero"]["name"], h], b)
		var sk := ""
		for k in GameState.SKILLS:
			sk += "%s %d · " % [GameState.SKILL_NAMES[k], s.skill("hero", k)]
		UI.rich("[b]Skills[/b] %s" % sk, b)
		UI.rich("[b]Health[/b] %d · [b]AP[/b] %d · [b]Job[/b] %s · [b]Traits[/b] %s · [b]Perks[/b] %s" % [s.hp_max("hero"), s.ap_max("hero"), Act0.job_info(s.job)["name"], ", ".join(s.traits.map(func(t: String) -> String: return TRAITS[t][0])), ", ".join(s.perks) if not s.perks.is_empty() else "none"], b)
		if not s.habits.is_empty():
			UI.rich("[b]%s's Habits[/b] (copied from you): %s" % [s.members["teen"]["name"], ", ".join(s.habits)], b)
		var tl := ""
		for t in s.tallies:
			tl += "%s (%s) · " % [t["text"], t["state"]]
		if tl != "":
			UI.rich("[b]Tallies[/b] " + tl, b))


func show_journal() -> void:
	popup("Journal", func(b: VBoxContainer) -> void:
		var lines: Array = s.journal.slice(-40)
		lines.reverse()
		for l in lines:
			UI.label(String(l), b, 15))


func _place_name(where: String) -> String:
	var nodes := Act1.nodes()
	if nodes.has(where):
		return s.fill(String(nodes[where]["name"]))
	return where


# ------------------------------------------------------------------ family screen
func show_family_screen() -> void:
	m.clear_world()
	m.clear_screen()
	m.set_segment("family")
	s.phase = "family"
	var body := UI.page(m.screen, "Your family")
	UI.rich("Name everyone, or roll names. Choose each person's gender, pronouns and heritage preset; members never have to match. No rule in the game reads gender or heritage. Roles stay fixed because the story needs them.", body, 15)
	UI.button("Quick start: skip setup with the default family", func() -> void:
		quick_defaults()
		finish_family(), body, 300)
	var r := RandomNumberGenerator.new()
	r.randomize()
	var top := UI.hbox(body)
	UI.label("Family name", top)
	var sur := LineEdit.new()
	sur.text = s.surname
	sur.custom_minimum_size = Vector2(UI.dp(200), UI.dp(48))
	sur.text_changed.connect(func(t: String) -> void: s.surname = t)
	top.add_child(sur)
	UI.button("Roll", func() -> void:
		s.surname = Heritage.roll_name("surname", r)
		sur.text = s.surname, top)
	UI.label("Dog", top)
	var dog := LineEdit.new()
	dog.text = s.dog_name
	dog.custom_minimum_size = Vector2(UI.dp(160), UI.dp(48))
	dog.text_changed.connect(func(t: String) -> void: s.dog_name = t)
	top.add_child(dog)
	UI.button("Roll", func() -> void:
		s.dog_name = Heritage.roll_name("dog", r)
		dog.text = s.dog_name, top)
	var name_edits := {}
	for role in GameState.ROLES:
		var mm: Dictionary = s.members[role]
		var box := UI.panel(body)
		var v := UI.vbox(box, 6)
		UI.label(ROLE_LABELS[role], v, 16, UI.ACCENT)
		var row := UI.hbox(v, 6)
		var le := LineEdit.new()
		le.text = mm["name"]
		le.custom_minimum_size = Vector2(UI.dp(180), UI.dp(48))
		le.text_changed.connect(func(t: String) -> void: mm["name"] = t if t.strip_edges() != "" else mm["name"])
		row.add_child(le)
		name_edits[role] = le
		UI.button("Roll", func() -> void:
			mm["name"] = Heritage.roll_name(role, r)
			le.text = mm["name"], row)
		var g := OptionButton.new()
		for gi in ["Woman", "Man", "Nonbinary"]:
			g.add_item(gi)
		g.custom_minimum_size = Vector2(UI.dp(130), UI.dp(48))
		g.selected = ["she", "he", "they"].find(mm["pronoun_key"])
		row.add_child(g)
		var pr := OptionButton.new()
		for pi in ["she/her", "he/him", "they/them"]:
			pr.add_item(pi)
		pr.custom_minimum_size = Vector2(UI.dp(130), UI.dp(48))
		pr.selected = ["she", "he", "they"].find(mm["pronoun_key"])
		row.add_child(pr)
		g.item_selected.connect(func(i: int) -> void:
			mm["pronoun_key"] = ["she", "he", "they"][i]
			pr.selected = i)
		pr.item_selected.connect(func(i: int) -> void: mm["pronoun_key"] = ["she", "he", "they"][i])
		var row2 := UI.hbox(v, 6)
		var her := OptionButton.new()
		for hp in Heritage.PRESETS:
			her.add_item(hp)
		her.selected = int(mm["heritage"])
		her.custom_minimum_size = Vector2(UI.dp(260), UI.dp(48))
		row2.add_child(her)
		var sw := ColorRect.new()
		sw.custom_minimum_size = Vector2(UI.dp(48), UI.dp(48))
		sw.color = Heritage.tone(int(mm["heritage"]))[1]
		row2.add_child(sw)
		her.item_selected.connect(func(i: int) -> void:
			mm["heritage"] = i
			sw.color = Heritage.tone(i)[1])
		if role == "partner" or role == "teen" or role == "elder":
			var kin := LineEdit.new()
			kin.placeholder_text = "What the kids call them (optional)" if role == "partner" else ("Role word (optional)" if role == "teen" else "What the kids call them (optional)")
			kin.custom_minimum_size = Vector2(UI.dp(300), UI.dp(48))
			kin.text_changed.connect(func(t: String) -> void: mm["kinword"] = t)
			row2.add_child(kin)
	UI.button("Roll the whole family", func() -> void:
		s.surname = Heritage.roll_name("surname", r)
		sur.text = s.surname
		s.dog_name = Heritage.roll_name("dog", r)
		dog.text = s.dog_name
		for role in GameState.ROLES:
			s.members[role]["name"] = Heritage.roll_name(role, r)
			name_edits[role].text = s.members[role]["name"], body, 260)
	_hero_build(body)


func _hero_build(body: VBoxContainer) -> void:
	UI.title("Build the Steward", body)
	var pts_label := UI.label("", body, 16)
	var attrs: Dictionary = s.members["hero"]["attrs"]
	var refresh_pts := func() -> void:
		var total := 0
		for a in GameState.ATTRS:
			total += int(attrs[a])
		pts_label.text = "Attributes start at 4. Points left to spend: %d (cap 8, floor 2)." % (38 - total)
	for grp in GameState.ATTR_GROUPS:
		var row := UI.hbox(body, 6)
		UI.label(grp, row, 16, UI.ACCENT).custom_minimum_size.x = UI.dp(60)
		for a in GameState.ATTR_GROUPS[grp]:
			var lab := UI.label("%s %d" % [GameState.ATTR_NAMES[a], int(attrs[a])], row, 16)
			lab.custom_minimum_size.x = UI.dp(130)
			UI.button("-", func() -> void:
				if int(attrs[a]) > 2:
					attrs[a] = int(attrs[a]) - 1
				lab.text = "%s %d" % [GameState.ATTR_NAMES[a], int(attrs[a])]
				refresh_pts.call(), row)
			UI.button("+", func() -> void:
				var total := 0
				for k in GameState.ATTRS:
					total += int(attrs[k])
				if int(attrs[a]) < 8 and total < 38:
					attrs[a] = int(attrs[a]) + 1
				lab.text = "%s %d" % [GameState.ATTR_NAMES[a], int(attrs[a])]
				refresh_pts.call(), row)
	refresh_pts.call()
	UI.label("Two Specialties (+25 each). Bedrock-tagged skills transfer to every collapse.", body, 16)
	var flow := HFlowContainer.new()
	body.add_child(flow)
	var spec_buttons := {}
	for k in GameState.SKILLS:
		var tag := " (Bedrock)" if k in GameState.TRANSFERABLE else ""
		var b := UI.button(GameState.SKILL_NAMES[k] + tag, func() -> void: pass, flow, 150)
		b.toggle_mode = true
		b.button_pressed = k in s.specialties
		b.toggled.connect(func(on: bool) -> void:
			if on and s.specialties.size() >= 2:
				b.set_pressed_no_signal(false)
				return
			if on:
				s.specialties.append(k)
			else:
				s.specialties.erase(k))
		spec_buttons[k] = b
	UI.label("A job (pay buys bets; a trade buys Bedrock).", body, 16)
	var jflow := HFlowContainer.new()
	body.add_child(jflow)
	var jbtns: Array = []
	for j in Act0.jobs():
		var b := UI.button("%s · $%d a week · %s +%d" % [j["name"], int(j["pay"]), GameState.SKILL_NAMES[j["skill"]], int(j["bonus"])], func() -> void: pass, jflow, 240)
		b.toggle_mode = true
		b.button_pressed = s.job == j["id"]
		jbtns.append(b)
		var jid: String = j["id"]
		b.pressed.connect(func() -> void:
			s.job = jid
			for o in jbtns:
				o.set_pressed_no_signal(o == b))
	UI.label("Two traits. Each pays somewhere and costs somewhere. Traits marked * are not active in this slice yet.", body, 16)
	var tflow := HFlowContainer.new()
	body.add_child(tflow)
	for t in TRAITS:
		var info: Array = TRAITS[t]
		var b := UI.button("%s%s\n+ %s\n- %s" % [info[0], "" if info[3] else " *", info[1], info[2]], func() -> void: pass, tflow, 280)
		b.toggle_mode = true
		b.toggled.connect(func(on: bool) -> void:
			if on and s.traits.size() >= 2:
				b.set_pressed_no_signal(false)
				return
			if on:
				s.traits.append(t)
			else:
				s.traits.erase(t))
	var go_row := UI.hbox(body)
	UI.button("Begin the Long Autumn", func() -> void:
		var total := 0
		for a in GameState.ATTRS:
			total += int(attrs[a])
		if total != 38 or s.specialties.size() != 2 or s.traits.size() != 2:
			m.toast("Spend all 10 points, and pick two Specialties and two traits.")
			return
		finish_family(), go_row, 300)
	UI.button("Quick start (defaults)", func() -> void:
		quick_defaults()
		finish_family(), go_row, 240)


func quick_defaults() -> void:
	var attrs: Dictionary = s.members["hero"]["attrs"]
	for a in GameState.ATTRS:
		attrs[a] = 4
	attrs["empathy"] = 6
	attrs["wits"] = 6
	attrs["awareness"] = 6
	attrs["discipline"] = 6
	attrs["reflex"] = 6
	s.specialties = ["negotiation", "medicine"]
	s.traits = ["mossback", "envelope"]
	s.job = "mechanic"


func finish_family() -> void:
	var hero: Dictionary = s.members["hero"]
	for sp in s.specialties:
		hero["bonus"][sp] = int(hero["bonus"].get(sp, 0)) + 25
	var j := Act0.job_info(s.job)
	hero["bonus"][j["skill"]] = int(hero["bonus"].get(j["skill"], 0)) + int(j["bonus"])
	for t in s.traits:
		match t:
			"mossback":
				for k in ["fieldcraft", "homestead"]:
					hero["bonus"][k] = int(hero["bonus"].get(k, 0)) + 10
				for k in ["electronics", "signals"]:
					hero["bonus"][k] = int(hero["bonus"].get(k, 0)) - 10
			"block_captain":
				hero["bonus"]["leadership"] = int(hero["bonus"].get("leadership", 0)) + 10
				s.profile += 15
				s.neighbors["quan"] = 1
			"envelope":
				s.profile = maxi(0, s.profile - 15)
				s.cash += 300
	for r in GameState.ROLES:
		if r != "hero":
			s.members[r]["buyin"] = 20 + 3 * s.attr("hero", "empathy") if r != "partner" else 18 + 3 * s.attr("hero", "empathy")
	s.phase = "act0"
	s.week = 1
	s.add_log("The Long Autumn begins: Monday, September 6, 2027.")
	m.save_game()
	show_week()


# ------------------------------------------------------------------ Act 0 weeks
func show_week() -> void:
	m.set_segment("act0")
	resume_point = "week"
	if s.phase == "dayzero":
		start_dayzero()
		return
	if not s.flag("week_started_%d" % s.week):
		s.set_flag("week_started_%d" % s.week)
		var landed := Act0.start_week(s)
		if not landed.is_empty():
			m.toast("Delivered: " + ", ".join(landed))
	var scene: String = Act0.SCENES.get(s.week, "")
	if scene != "" and scene != "eve" and not s.flag("scene_" + scene):
		s.set_flag("scene_" + scene)
		play_scene(scene)
		return
	show_planner()


func play_scene(scene: String) -> void:
	match scene:
		"cookout":
			m.run_dialogue("cookout_intro", func() -> void: start_cookout())
		"pump_four":
			m.clear_world()
			m.run_dialogue("pump_four", show_planner)
		"the_blow":
			m.clear_world()
			m.run_dialogue("the_blow", show_planner)


func start_cookout() -> void:
	m.clear_screen()
	var ex := Explore.new()
	m.host_world(ex)
	ex.setup(s, "court", "cookout")
	ex.set_view(m.RENDER_SCALE, m.get_viewport().get_visible_rect().size.y)
	ex.hint.connect(func(t: String) -> void: m.toast(t))
	var done := {}
	ex.interact.connect(func(t: Dictionary) -> void:
		if t.has("dialogue") and not (t.get("once", false) and done.has(t["id"])):
			m.run_dialogue(t["dialogue"], func() -> void:
				done[t["id"]] = true
				_cookout_check(ex, done))
		elif t.has("line"):
			m.toast(s.fill("%s: %s" % [t["name"], t["line"]]), 4.0))
	m.refresh_status()
	m.toast("Labor Day. Tap a neighbor once to see them, again to walk over and talk.", 5.0)


func _cookout_check(ex: Explore, done: Dictionary) -> void:
	var fin: Dictionary = ex.variant["finish"]
	for need in fin["needs"]:
		if not done.has(need):
			return
	m.run_dialogue(fin["event"], func() -> void:
		m.run_dialogue("cookout_end", func() -> void:
			m.clear_world()
			show_planner()))


func show_planner() -> void:
	m.clear_world()
	m.clear_screen()
	m.set_segment("act0")
	m.refresh_status()
	var body := UI.page(m.screen, "Week %d · %s" % [s.week, week_dates(s.week)])
	var heads: Array = Act0.threads()["headlines"].get(str(s.week), [])
	if not heads.is_empty():
		UI.rich("[b]Headlines:[/b] " + " · ".join(heads), body, 15)
	var fridge := UI.panel(body)
	var fv := UI.vbox(fridge, 4)
	UI.rich("[b]The fridge card[/b] · Bedrock %d of 7 · next gap: %s" % [Act0.bedrock_count(s), s.fill(Act0.fridge_gap(s))], fv, 16)
	var br := Act0.bedrock(s)
	var line := ""
	for k in br:
		line += "%s %s   " % ["[color=#2e7031]✔[/color]" if br[k]["met"] else "[color=#8a2a1a]✘[/color]", Act0.BEDROCK_NAMES[k]]
	UI.rich(line, fv, 15)
	if not s.orders.is_empty():
		UI.rich("[b]On order:[/b] " + ", ".join(s.orders.map(func(o: Dictionary) -> String: return "%s (week %d)" % [Act0.activity(o["activity"])["name"], int(o["arrive"])])), fv, 14)
	var tools := UI.hbox(body)
	UI.button("Signal Board (%d checks)" % Act0.checks_left(s), func() -> void: show_board(), tools, 200)
	if s.has_vehicle():
		UI.button("Garage", func() -> void: show_garage(show_planner), tools, 120)
	var end_txt := "End week %d" % s.week if s.week < 8 else "To Halloween"
	UI.button(end_txt + (" (%d blocks unused)" % Act0.blocks_left(s) if Act0.blocks_left(s) > 0 else ""), func() -> void: end_week(), tools, 220)
	var booked := s.week_log.filter(func(x: Dictionary) -> bool: return int(x["week"]) == s.week)
	if not booked.is_empty():
		UI.rich("[b]This week:[/b] " + ", ".join(booked.map(func(x: Dictionary) -> String: return s.fill(Act0.activity(x["id"])["name"]))), body, 15)
	var detail := UI.panel(body)
	var dv := UI.vbox(detail, 6)
	_activity_detail(dv)
	var cats := {}
	for a in Act0.activities():
		if not cats.has(a["cat"]):
			cats[a["cat"]] = []
		cats[a["cat"]].append(a)
	for cat in cats:
		UI.label(cat, body, 16, UI.ACCENT)
		var flow := HFlowContainer.new()
		flow.add_theme_constant_override("h_separation", UI.dp(6))
		flow.add_theme_constant_override("v_separation", UI.dp(6))
		body.add_child(flow)
		for a in cats[cat]:
			var bl := Act0.blocker(s, a)
			var lead := " · ships week %d" % (s.week + int(a["lead"])) if int(a.get("lead", 0)) > 0 else ""
			var b := UI.button("%s\n$%d · %d block%s%s%s" % [s.fill(a["name"]), int(a["money"]), int(a["blocks"]), "s" if int(a["blocks"]) > 1 else "", lead, "\n" + bl if bl != "" else ""], func() -> void:
				selected_activity = a["id"]
				show_planner(), flow, 200)
			b.custom_minimum_size.y = UI.dp(76)
			if bl != "":
				b.modulate = Color(1, 1, 1, 0.55)
			if a.get("bedrock", "") != "" and not br[a["bedrock"]]["met"]:
				b.text = "★ " + b.text


func _activity_detail(dv: VBoxContainer) -> void:
	if selected_activity == "":
		UI.rich("Tap an activity to see what it does, then book it. ★ marks a card whose Bedrock item is not met yet. Profile goes up when the town notices what you buy.", dv, 15)
		return
	var a := Act0.activity(selected_activity)
	var bl := Act0.blocker(s, a)
	UI.rich("[b]%s[/b] · %s · $%d · %d block%s\n%s" % [s.fill(a["name"]), a["cat"], int(a["money"]), int(a["blocks"]), "s" if int(a["blocks"]) > 1 else "", s.fill(a["text"])], dv, 16)
	var prof := 0
	for e in a["effects"]:
		if e[0] == "profile":
			prof += int(e[1])
	if prof > 0:
		UI.label("Profile +%d (preview)" % prof, dv, 15, UI.WARN)
	if int(a["money"]) > s.money and bl == "":
		UI.label("This goes on the card: $%d of $%d used." % [s.card + int(a["money"]) - s.money, Act0.CARD_LIMIT], dv, 15, UI.WARN)
	var row := UI.hbox(dv)
	if bl != "":
		UI.label(bl, row, 16, UI.BAD)
	elif a.get("pick_skill", false):
		var opts: Array = GameState.SKILLS.keys() if a["id"] == "night_class" else Act0.teachable_skills(s)
		var flow := HFlowContainer.new()
		dv.add_child(flow)
		for k in opts:
			UI.button("%s (%d)" % [GameState.SKILL_NAMES[k], s.skill_base("hero" if a["id"] == "night_class" else "teen", k)], func() -> void:
				_book(a["id"], k), flow, 150)
	else:
		UI.button("Book it", func() -> void: _book(a["id"], ""), row, 200)


func _book(id: String, pick: String) -> void:
	var evs := Act0.book(s, id, pick)
	selected_activity = ""
	m.save_game()
	m.run_events(evs, show_planner)


func end_week() -> void:
	if s.week == 8:
		m.run_dialogue("eve", func() -> void: show_last_pin())
		return
	Act0.end_week(s)
	m.save_game()
	show_week()


func show_last_pin() -> void:
	popup("The Last Pin", func(b: VBoxContainer) -> void:
		var post := Act0.posterior(s)
		UI.rich("Your hunch: [b]%s[/b] (%s). Pick the thread you believe." % [Act0.threads()["names"][Act0.hunch(s)["thread"]], Act0.hunch(s)["label"]], b)
		for th in Act0.threads()["names"]:
			UI.button("%s · your read %d%%" % [Act0.threads()["names"][th], int(round(float(post[th]) * 100))], func() -> void:
				s.last_pin = th
				close_popup()
				Act0.end_week(s)
				m.run_dialogue("breakfast", start_dayzero), b, 300), Callable(), "Not yet")


func show_board() -> void:
	popup("The Signal Board", func(b: VBoxContainer) -> void:
		var h := Act0.hunch(s)
		var post := Act0.posterior(s)
		UI.rich("Seven threads, two pins a week each, each secretly solid or smoke. Checking a pin spends a check (%d left this week). Air pins need Signals 20 or a radio. No Strong Lead shows before week 5.\n[b]Hunch:[/b] %s, %s (%d%%)" % [Act0.checks_left(s), Act0.threads()["names"][h["thread"]], h["label"], int(round(h["p"] * 100))], b, 15)
		for th in Act0.threads()["names"]:
			var row := UI.hbox(b, 4)
			UI.label("%s %d%%" % [Act0.threads()["names"][th], int(round(float(post[th]) * 100))], row, 15).custom_minimum_size.x = UI.dp(130)
			var flow := HFlowContainer.new()
			flow.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			row.add_child(flow)
			var pins: Array = s.board.get(th, [])
			for i in pins.size():
				var p: Dictionary = pins[i]
				var txt := "W%d %s\n%s" % [int(p["week"]), p["kind"], ("solid" if p["solid"] else "smoke") if p["checked"] else "?"]
				var bt := UI.button(txt, func() -> void:
					if Act0.check_pin(s, th, i):
						show_board()
					else:
						m.toast("No checks left, or an Air pin without a radio."), flow, 70)
				if p["checked"]:
					bt.modulate = Color(0.7, 1, 0.7) if p["solid"] else Color(1, 0.8, 0.8)
	, func() -> void:
		if s.phase == "act0":
			show_planner())


func show_gear(cb: Callable) -> void:
	popup("Gear Run", func(b: VBoxContainer) -> void:
		UI.rich(Act0.GEAR["_note"] + " Spendable: $%d (bank plus card)." % Act0.spendable(s), b, 15)
		var flow := HFlowContainer.new()
		b.add_child(flow)
		for id in Act0.GEAR:
			if id.begins_with("_"):
				continue
			UI.button("%s\n$%d · own %d" % [Rules.item_name(id), int(Act0.GEAR[id]), int(s.items.get(id, 0))], func() -> void:
				if Act0.buy_gear(s, id):
					m.toast("Bought: " + Rules.item_name(id))
					show_gear(cb)
				else:
					m.toast("Not enough money."), flow, 200), cb, "Done shopping")


func show_garage(cb: Callable) -> void:
	popup("Garage and Go Kit", func(b: VBoxContainer) -> void:
		UI.rich("Load a vehicle and choose its hardening. In Stopped Clocks 95% of post-2005 vehicles and 75% of all other unshielded electronics die, older vehicles included; Old Iron rolls 10%. Hardening stacks on the vehicle's roll, never below 35%, and gives nothing to small gear inside: seal that separately. A conductive tarp that only touches bare concrete leaves the floor side open, so it is partial at best. These odds are fiction beyond public data.", b, 15)
		var hard: Dictionary = Devices.hardening()
		for v in s.vehicles:
			if v["kind"] == "family_car":
				continue
			var vrec: Dictionary = Rules.db("items")["vehicles"][v["kind"]]
			var pv := UI.panel(b)
			var vv := UI.vbox(pv, 6)
			UI.rich("[b]%s[/b] · dies %d%% at the flash · load %d of %d lb%s" % [vrec["name"], Devices.vehicle_chance(v), int(Devices.load_weight(v)), int(Devices.capacity(v)), " · [color=#8a2a1a]stalls at random[/color]" if v.get("stall", false) else ""], vv, 16)
			var era: String = vrec["era"]
			if Devices.is_electronic(era):
				var crow := HFlowContainer.new()
				vv.add_child(crow)
				for opt in hard["options"]:
					var rec: Dictionary = hard["options"][opt]
					var on: bool = opt in v.get("mods", [])
					var gate_txt := "\n" + Rules.gate_label(s, rec["gate"][0], int(rec["gate"][1])) if rec.has("gate") else ""
					var bt := UI.button("%s%s\n$%d · -%d · %s%s" % ["✔ " if on else "", rec["name"], int(rec["cost"]), int(rec["minus"]), rec["note"], gate_txt], func() -> void:
						var err := Devices.toggle_mod(s, v, opt)
						if err != "":
							m.toast(err)
						show_garage(cb), crow, 320)
					bt.custom_minimum_size.y = UI.dp(96)
			UI.label("In the house: tap to load", vv, 15, UI.ACCENT)
			var hflow := HFlowContainer.new()
			vv.add_child(hflow)
			for id in s.items:
				if int(s.items[id]) <= 0:
					continue
				UI.button("%s x%d →" % [Rules.item_name(id), int(s.items[id])], func() -> void:
					if not Devices.load_item(s, v, id, true):
						m.toast("It won't fit.")
					show_garage(cb), hflow, 170)
			UI.label("In the vehicle: tap to unload", vv, 15, UI.ACCENT)
			var lflow := HFlowContainer.new()
			vv.add_child(lflow)
			for id in v["load"]:
				UI.button("← %s x%d" % [Rules.item_name(id), int(v["load"][id])], func() -> void:
					Devices.load_item(s, v, id, false)
					show_garage(cb), lflow, 170)
		if s.flag("seal_bag"):
			var used := 0
			for k in s.shielded:
				used += int(s.shielded[k])
			var ps := UI.panel(b)
			var sv := UI.vbox(ps, 6)
			UI.rich("[b]Shielding bag[/b] (Seal the Spares): %d of %d small devices. Sealed gear survives 95%%. The bag also holds any vehicle's engine computer, ignition module and crank sensor, so a Mechanics 35 day can restore a dead fuel-injected vehicle 70%% of the time." % [used, Devices.SEAL_CAPACITY], sv, 15)
			var sflow := HFlowContainer.new()
			sv.add_child(sflow)
			for id in s.items:
				if int(s.items[id]) > 0 and Devices.sealable(id):
					UI.button("Seal %s" % Rules.item_name(id), func() -> void:
						if not Devices.seal(s, id):
							m.toast("The bag is full.")
						show_garage(cb), sflow, 170)
		if s.vehicles.size() <= 1:
			UI.label("No Go Kit vehicle yet. Buy the Rig (a 1990s 4x4) or Buy the Truck (1968, Old Iron) in Supply.", b, 15), cb, "Done")


# ------------------------------------------------------------------ Day Zero
func start_dayzero() -> void:
	s.phase = "act1"
	m.set_segment("dayzero")
	resume_point = "dayzero"
	s.day = 0
	s.watch = 2
	s.members["hero"]["where"] = "tvhwy"
	s.members["partner"]["where"] = "hospital"
	s.members["teen"]["where"] = "home" if s.flag("rally_rehearsed") else "school"
	s.members["child"]["where"] = "home"
	s.members["elder"]["where"] = "sorrel"
	if s.buyin_avg() >= 75:
		s.set_flag("partner_walking")
	var right: bool = s.last_pin == "sky"
	if right:
		s.add_buyin(5)
	s.add_log("Day Zero. The Last Pin was %s." % ("right" if right else "wrong"))
	m.save_game()
	m.run_dialogue("dz_flash", func() -> void: _dz_map())


func _dz_map() -> void:
	m.clear_screen()
	var ex := Explore.new()
	m.host_world(ex)
	ex.setup(s, "tvhwy", "dayzero")
	ex.set_view(m.RENDER_SCALE, m.get_viewport().get_visible_rect().size.y)
	ex.hint.connect(func(t: String) -> void: m.toast(t))
	ex.interact.connect(func(t: Dictionary) -> void:
		if t.has("dialogue"):
			m.run_dialogue(t["dialogue"], func() -> void: ex.apply_light())
		elif t.has("line"):
			m.toast(s.fill("%s: %s" % [t["name"], t["line"]]), 4.0))
	ex.exit_reached.connect(func(_e: Dictionary) -> void: _diagnose())
	var hud := UI.hbox(m.screen)
	hud.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	hud.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	hud.grow_vertical = Control.GROW_DIRECTION_BEGIN
	hud.position -= Vector2(UI.dp(12), UI.dp(12))
	UI.button("Read the signs and head home", func() -> void: _diagnose(), hud, 260)
	m.refresh_status()


func _diagnose() -> void:
	var names := {"phones": "dead phones in people's hands", "sky": "no aircraft lights, no blast", "old_truck": "a 1968 pickup running while new cars sit dark"}
	var seen: Array = s.clues.map(func(c: String) -> String: return names.get(c, c))
	m.run_dialogue("dz_diagnosis", func() -> void:
		if s.flag("diagnosed"):
			_leave_tvhwy()
		else:
			m.toast("Look around more: phones, the sky, the cars."), {"clue_list": ", ".join(seen) if not seen.is_empty() else "not much yet"})


func show_flash_report(cb: Callable) -> void:
	var rows := Devices.flash(s)
	Act1.unpack(s, s.items)
	for v in s.vehicles:
		if v["kind"] != "family_car":
			Act1.unpack(s, v["load"])
	s.flags["vehicle_at"] = "home"
	var car := s.vehicle("family_car")
	if not car.is_empty():
		car["state"] = "dead" if car["state"] == "dead" else car["state"]
	popup("What still works", func(b: VBoxContainer) -> void:
		UI.rich("The flash rolled every device once, from the Stopped Clocks tier table: gear on long cables 95% dead, unplugged handhelds 50%, inverters 90%, panels 5%; vehicles after 2005 95%, 1980 to 2005 85%, before 1980 10%; sealed caches 5%. These shares are fiction beyond public data.", b, 14)
		for r in rows:
			var nm := Rules.item_name(r["id"]) if not r.get("vehicle", false) else String(Rules.db("items")["vehicles"][r["id"]]["name"])
			var where := String(r["where"]).replace("vehicle:", "in the ").replace("rig_90s", "4x4").replace("old_iron", "pickup").replace("family_car", "hatchback").replace("house", "house").replace("locker", "sealed locker")
			var col := "#2e7031" if int(r["dead"]) == 0 else ("#8a2a1a" if int(r["alive"]) == 0 else "#8a5a10")
			if int(r["chance"]) == 0 and not r.get("vehicle", false):
				continue
			UI.rich("[color=%s]%s[/color] (%s): %d working, %d dead · %d%% chance each" % [col, nm, where, int(r["alive"]), int(r["dead"]), int(r["chance"])], b, 15)
		UI.rich("Food, water, kits, fuel and parts from buckets and cans are unpacked into the ledger.", b, 14), cb, "Get home")


func _leave_tvhwy() -> void:
	var mode := "foot"
	if s.flag("dell_ride"):
		mode = "vehicle_free"
	elif s.flag("took_bike") or Devices.working_count(s, "bicycle") > 0:
		mode = "bicycle"
	var w := 1 if mode != "foot" else 2
	for i in w:
		Act1.advance_watch(s)
	s.members["hero"]["where"] = "home"
	m.set_segment("act1")
	resume_point = "act1"
	s.add_log("Day 0: home by %s." % ("Dell's pickup" if mode == "vehicle_free" else mode))
	m.run_dialogue("home_day0", func() -> void: go_court(), {"garage_report": _garage_report()})


func _garage_report() -> String:
	var lines: Array = []
	for v in s.vehicles:
		if v["kind"] == "family_car":
			lines.append("The hatchback is still on TV Highway with the others, %s." % ("dead" if v["state"] == "dead" else "somehow fine, if you go back for it"))
			continue
		var vrec: Dictionary = Rules.db("items")["vehicles"][v["kind"]]
		if v["state"] == "ok":
			lines.append("The %s turns over on the first try. %s" % [vrec["name"], "It is Worn: it runs, but something in it is cooked, and it needs Bench time within 20 days." if v.get("worn", false) else "Old Iron: nothing in it to kill."])
		else:
			lines.append("The %s is dead: the dash stays dark and the starter clicks once. %s" % [vrec["name"], "The tarp did not close the floor." if "tarp" in v.get("mods", []) else ""])
			if s.flag("seal_bag") and Devices.is_electronic(vrec["era"]) and not v.get("restore_tried", false):
				lines.append("The sealed spares are in the bag: a Mechanics 35 day could restore it (70%).")
	if lines.size() <= 1 and s.vehicles.size() <= 1:
		lines.append("There's nothing in the garage but the lawnmower and the bikes.")
	var working: Array = []
	for id in ["handheld_radio", "shortwave", "power_station", "led_lantern", "phone", "laptop"]:
		var n := Devices.working_count(s, id)
		if n > 0:
			working.append("%s x%d" % [Rules.item_name(id), n])
	lines.append("Still working: " + (", ".join(working) if not working.is_empty() else "nothing with a circuit in it."))
	return "\n\n".join(lines)


# ------------------------------------------------------------------ Act 1
func go_court() -> void:
	m.clear_screen()
	m.set_segment("act1")
	if _check_end():
		return
	var ex := Explore.new()
	m.host_world(ex)
	ex.setup(s, "court", "act1")
	ex.set_view(m.RENDER_SCALE, m.get_viewport().get_visible_rect().size.y)
	ex.hint.connect(func(t: String) -> void: m.toast(t))
	ex.interact.connect(func(t: Dictionary) -> void:
		if t.get("event", "") == "garage_view":
			popup("Your garage", func(b: VBoxContainer) -> void:
				UI.rich(_garage_report(), b)
				for v in s.vehicles:
					if v["state"] == "dead" and v["kind"] != "family_car" and s.flag("seal_bag") and not v.get("restore_tried", false):
						UI.button("Swap in the sealed spares (a full day, %s)" % Rules.gate_label(s, "mechanics", 35), func() -> void:
							var res := Devices.try_restore(s, v)
							close_popup()
							m.toast({"ok": "It catches. The 4x4 runs, Worn.", "failed": "A day of work and it still won't catch."}.get(res, res), 5.0)
							go_court(), b, 300))
		elif t.has("dialogue"):
			m.run_dialogue(t["dialogue"], func() -> void:
				if String(s.quests.get("m2", {}).get("state", "")) == "done":
					s.set_flag("m2_done")
				go_court(), _tokens())
		elif t.has("line"):
			m.toast(s.fill("%s: %s" % [t["name"], t["line"]]), 4.0))
	ex.exit_reached.connect(func(_e: Dictionary) -> void: show_worldmap())
	var hud := UI.hbox(m.screen)
	hud.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	hud.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	hud.grow_vertical = Control.GROW_DIRECTION_BEGIN
	hud.position -= Vector2(UI.dp(12), UI.dp(12))
	UI.button("World map", func() -> void: show_worldmap(), hud, 140)
	UI.button("Wait a watch", func() -> void: _pass_time(1), hud, 140)
	UI.button("Sleep until morning", func() -> void: _sleep(), hud, 200)
	_status_card(m.screen)
	m.refresh_status()


func _status_card(parent: Control) -> void:
	var p := UI.panel(parent)
	p.position = Vector2(UI.dp(10), UI.dp(64))
	p.modulate = Color(1, 1, 1, 0.92)
	var v := UI.vbox(p, 2)
	var m1: Dictionary = s.quests.get("m1", {})
	var m2: Dictionary = s.quests.get("m2", {})
	UI.label("M1 Gather: %s" % (String(m1.get("end", "")).replace("_", " ").capitalize() if m1.get("state", "") == "done" else "bring everyone home"), v, 14)
	for r in ["partner", "teen", "elder", "child"]:
		var w := String(s.members[r]["where"])
		var note := " (staying, home Day 7)" if r == "partner" and s.flag("partner_stays") and w != "home" else ""
		UI.label("  %s: %s%s" % [s.members[r]["name"], _place_name(w) if w != "home" else "home", note], v, 14)
	UI.label("M2 The Week After: %s" % (String(m2.get("end", "")).replace("_", " ").capitalize() if m2.get("state", "") == "done" else "the lantern meeting, from Day 2"), v, 14)


func _tokens() -> Dictionary:
	var tap := "still trickle" if s.day < 3 else "are dry"
	var radio := "The shortwave and the handhelds are on the shelf. %s" % ("At least one still works." if Devices.working_count(s, "shortwave") + Devices.working_count(s, "handheld_radio") > 0 else "None of them do anything.")
	return {"day": str(s.day), "tap_state": tap, "radio_state": radio, "home_report": _home_report(), "garage_report": _garage_report()}


func _home_report() -> String:
	var who: Array = []
	for r in ["partner", "teen", "elder", "child"]:
		if s.members[r]["where"] == "home":
			who.append(s.members[r]["name"])
	return "Home. In the house: %s. %s" % [", ".join(who) if not who.is_empty() else "nobody but the dog", "Everyone is in." if Act1.all_home(s) else "Not everyone yet."]


func _pass_time(n: int) -> void:
	for i in n:
		Act1.advance_watch(s)
		_auto_moves()
	_night_events(go_court)


func _sleep() -> void:
	Act1.wait_until(s, 0)
	_auto_moves()
	s.add_log("Day %d: morning." % s.day)
	_night_events(go_court)


## Family who move on their own (prep90.md Buy-in tiers, f4.md M1 end states).
func _auto_moves() -> void:
	if s.flag("partner_walking") and s.day >= 2 and s.members["partner"]["where"] == "hospital" and not s.flag("partner_stays"):
		s.members["partner"]["where"] = "home"
		s.add_log("{partner.name} walked home over the hill on their own, as the plan said.")
	if s.members["teen"]["where"] == "school" and s.day >= 2:
		s.members["teen"]["where"] = "home"
		s.add_strain("teen", 15)
		s.add_log("{teen.name} gave up waiting and walked home alone. Strain +15.")
	if s.members["partner"]["where"] == "hospital" and not s.flag("partner_stays") and s.day >= 4:
		s.members["partner"]["where"] = "home"
		s.add_log("{partner.name} walked home on Day 4, exhausted.")
	if s.flag("partner_stays") and s.day >= 7 and s.members["partner"]["where"] == "hospital":
		pass


func _night_events(cb: Callable) -> void:
	if s.members["hero"]["where"] != "home":
		cb.call()
		return
	var queue: Array = []
	for k in Act1.knocks_for_night(s):
		if not s.flag("knock_%s_%d" % [k, s.day]):
			s.set_flag("knock_%s_%d" % [k, s.day])
			if k == "knock_ruth" and not s.flag("ruth_knock_done"):
				s.set_flag("ruth_knock_done")
				queue.append(k)
			elif k != "knock_ruth":
				queue.append(k)
	_run_queue(queue, cb)


func _run_queue(q: Array, cb: Callable) -> void:
	if q.is_empty():
		cb.call()
		return
	var k: String = q.pop_front()
	m.run_dialogue(k, func() -> void: _run_queue(q, cb), _tokens())


func _check_end() -> bool:
	Act1.check_m1(s)
	if s.day >= Act1.LAST_DAY and s.members["hero"]["where"] == "home" and not s.flag("act1_over"):
		s.set_flag("act1_over")
		m.run_dialogue("day7", func() -> void: pass)
		return true
	if s.flag("act1_over"):
		show_summary()
		return true
	return false


# ------------------------------------------------------------------ world map
var _wm_sel := ""


func show_worldmap() -> void:
	m.clear_world()
	m.clear_screen()
	m.set_segment("act1")
	resume_point = "worldmap"
	m.refresh_status()
	var bg := ColorRect.new()
	bg.color = Color(0.82, 0.78, 0.66)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	m.screen.add_child(bg)
	var sz: Vector2 = m.get_viewport().get_visible_rect().size
	var mapw := sz.x * 0.62
	var holder := Control.new()
	holder.position = Vector2(0, UI.dp(56))
	holder.size = Vector2(mapw, sz.y - UI.dp(56))
	m.screen.add_child(holder)
	var lines := Line2D.new()
	lines.width = UI.dp(3)
	lines.default_color = Color(0.45, 0.38, 0.28)
	holder.add_child(lines)
	# Fit the node box into the holder so close nodes do not stack.
	var lo := Vector2(INF, INF)
	var hi := Vector2(-INF, -INF)
	for nid in Act1.nodes():
		var np: Array = Act1.nodes()[nid]["pos"]
		lo = lo.min(Vector2(float(np[0]), float(np[1])))
		hi = hi.max(Vector2(float(np[0]), float(np[1])))
	var pad := Vector2(UI.dp(80), UI.dp(60))
	var sx := (holder.size.x - 2.0 * pad.x) / maxf(1.0, hi.x - lo.x)
	var sy := minf((holder.size.y - 2.0 * pad.y) / maxf(1.0, hi.y - lo.y), sx * 1.6)
	var off := Vector2(pad.x, (holder.size.y - (hi.y - lo.y) * sy) / 2.0)
	var to_map := func(q: Vector2) -> Vector2: return (q - lo) * Vector2(sx, sy) + off
	var here: String = s.members["hero"]["where"]
	var hills := Label.new()
	hills.text = "W E S T   H I L L S"
	hills.position = to_map.call(Vector2(1120, 470))
	hills.add_theme_color_override("font_color", Color(0.35, 0.45, 0.3))
	hills.add_theme_font_size_override("font_size", UI.dp(16))
	holder.add_child(hills)
	for id in Act1.nodes():
		var n: Dictionary = Act1.nodes()[id]
		var p: Vector2 = to_map.call(Vector2(float(n["pos"][0]), float(n["pos"][1])))
		lines.add_point(p)
		var b := UI.button(s.fill(n["name"]) + (" (you)" if id == here else ""), func() -> void:
			_wm_sel = id
			show_worldmap(), holder, 120)
		b.position = p - Vector2(UI.dp(60), UI.dp(24))
		if id == here:
			b.modulate = Color(0.7, 1.0, 0.7)
		elif id == _wm_sel:
			b.modulate = Color(1.0, 0.9, 0.6)
	var side := UI.panel(m.screen)
	side.position = Vector2(mapw + UI.dp(8), UI.dp(60))
	side.size = Vector2(sz.x - mapw - UI.dp(16), sz.y - UI.dp(70))
	var sc := UI.scroll(side)
	var v := UI.vbox(sc)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	UI.label("Walt's atlas, Day %d, %s. Sight at night: %d tiles. Moon: %s." % [s.day, Act1.WATCH_NAMES[s.watch], Act1.sight(s, false), Act1.moon(s.day)], v, 15)
	for r in ["partner", "teen", "elder", "child"]:
		UI.label("%s: %s" % [s.members[r]["name"], _place_name(String(s.members[r]["where"]))], v, 15)
	if _wm_sel != "" and _wm_sel != here:
		var n: Dictionary = Act1.nodes()[_wm_sel]
		UI.label(s.fill(n["name"]), v, 18, UI.ACCENT)
		UI.label(s.fill(n.get("blurb", "")) + " %.1f miles." % Act1.miles(here, _wm_sel), v, 15)
		var party := _party_here()
		if not party.is_empty():
			UI.label("Travelling with you: " + ", ".join(party.map(func(r: String) -> String: return s.members[r]["name"])), v, 15)
		for mode in Act1.travel_modes(s):
			var wt := Act1.travel_watches(s, here, _wm_sel, mode)
			if _wm_sel == "hospital" or here == "hospital":
				if s.flag("via_tunnel"):
					wt = maxi(1, int(ceil(wt * 0.7)))
			var label := "%s: %d watch%s" % [mode.capitalize(), wt, "es" if wt > 1 else ""]
			if mode == "vehicle":
				label += " · fuel, Profile +3 (an engine carries)"
			var target := _wm_sel
			UI.button(label, func() -> void: _travel(target, mode), v, 200)
	elif here == "home":
		UI.button("Back to the court", func() -> void: go_court(), v, 200)
	else:
		UI.button("Look around here", func() -> void: _arrive(here), v, 200)
	UI.button("Wait a watch here", func() -> void:
		Act1.advance_watch(s)
		_auto_moves()
		show_worldmap(), v, 200)


func _party_here() -> Array:
	var out: Array = []
	for r in ["partner", "teen", "elder", "child"]:
		if s.members[r]["where"] == s.members["hero"]["where"] and s.members["hero"]["where"] != "home":
			out.append(r)
	return out


func _travel(to: String, mode: String) -> void:
	var n: Dictionary = Act1.nodes()[to]
	var go := func() -> void:
		var party := _party_here()
		var res := Act1.travel(s, to, mode, party)
		if s.flag("via_tunnel") and (to == "hospital"):
			pass
		_auto_moves()
		s.add_log("Day %d: reached %s (%d watches)." % [s.day, s.fill(n["name"]), int(res["watches"])])
		m.save_game()
		_arrive(to)
	if n.has("approach") and not s.flag("crossed_" + to):
		s.set_flag("crossed_" + to)
		m.run_dialogue(n["approach"], go)
	else:
		go.call()


func _arrive(to: String) -> void:
	_wm_sel = ""
	if to == "home":
		Act1.check_m1(s)
		m.run_dialogue("home_return", func() -> void: _night_events(go_court), _tokens())
		return
	var n: Dictionary = Act1.nodes()[to]
	if n.has("dialogue"):
		m.run_dialogue(n["dialogue"], show_worldmap, _tokens())
	else:
		show_worldmap()


# ------------------------------------------------------------------ fights
func show_aftermath(c: Combat, outcome: String, cb: Callable) -> void:
	var downs := c.downed_foes()
	var head: String = {"win": "It's over", "parley": "They're gone", "lose": "You lost this one"}.get(outcome, "After")
	popup(head, func(b: VBoxContainer) -> void:
		UI.rich({"win": "The fight is over. Most fights end before anyone dies; people break first.", "parley": "Parley: they leave, and nobody else gets hurt today.", "lose": "On Hearth, family are badly hurt or robbed, never killed."}.get(outcome, ""), b)
		for f in c.units:
			if f["team"] == "foe":
				UI.label("%s: %s" % [f["name"], {"ok": "standing", "down": "Down, bleeding", "fled": "fled", "surrendered": "surrendered", "treated": "treated", "dead": "dead"}.get(f["state"], f["state"])], b, 15)
		if not downs.is_empty():
			UI.rich("Someone is Down. Treat them with a kit (%d left) or leave them. Leaving a Down person is scored as a killing." % s.led("kits"), b, 15)
			for f in downs:
				var row := UI.hbox(b)
				UI.label(String(f["name"]), row, 16)
				var fid: String = f["id"]
				var tb := UI.button("Treat (1 kit)", func() -> void:
					c.resolve_down(fid, true)
					show_aftermath(c, outcome, cb), row, 140)
				tb.disabled = s.led("kits") <= 0
				UI.button("Leave them", func() -> void:
					c.resolve_down(fid, false)
					show_aftermath(c, outcome, cb), row, 140), func() -> void:
		for f in c.downed_foes():
			c.resolve_down(f["id"], false)
		m.clear_world()
		cb.call(), "Continue")


# ------------------------------------------------------------------ summary
func show_summary() -> void:
	s.phase = "done"
	m.set_segment("summary")
	m.clear_world()
	m.clear_screen()
	m.save_game()
	var body := UI.page(m.screen, "The end of the first week")
	var rep := report_text()
	UI.rich(rep.replace("\n", "\n"), body, 15)
	var row := UI.hbox(body)
	UI.button("Copy report", func() -> void:
		DisplayServer.clipboard_set(rep)
		m.toast("Copied. Paste it into the project thread."), row, 200)
	UI.button("New game", func() -> void: m.show_title(), row, 160)
	var f := FileAccess.open("user://slice_report.txt", FileAccess.WRITE)
	if f != null:
		f.store_string(rep)


func report_text() -> String:
	var t := s.telemetry
	var mins := func(k: String) -> String: return "%.1f" % (float(t.get(k, 0.0)) / 60.0)
	var total := 0.0
	for k in ["family", "act0", "dayzero", "act1"]:
		total += float(t.get(k, 0.0))
	var m1: Dictionary = s.quests.get("m1", {})
	var m2: Dictionary = s.quests.get("m2", {})
	var lines: Array = []
	lines.append("Stopped Clocks slice report (%s, seed %d)" % [m.VERSION, s.game_seed])
	lines.append("Play time, minutes: family %s, Long Autumn %s, Day Zero %s, Act 1 %s, total %.1f" % [mins.call("family"), mins.call("act0"), mins.call("dayzero"), mins.call("act1"), total / 60.0])
	lines.append("Design budget for the same span: family 5, Act 0 85 (condensed here), Day Zero 8, Act 1 52.")
	lines.append("Dialogues %d, choices %d" % [m.dialogue_count, m.choice_count])
	lines.append("Bedrock at Day Zero: %d of 7" % Act0.bedrock_count(s))
	lines.append("M1 Gather: %s · M2 The Week After: %s · Thaw: %s" % [m1.get("end", "unfinished"), m2.get("end", "unfinished"), "done" if s.flag("thaw_done") else "skipped"])
	lines.append("Last Pin: %s (true thread: Sky)" % (s.last_pin if s.last_pin != "" else "none"))
	var fam: Array = []
	for r in GameState.ROLES:
		fam.append("%s %s Regard %d Strain %d" % [r, s.members[r]["where"], int(s.members[r]["buyin"]), int(s.members[r]["strain"])])
	lines.append("Family: " + "; ".join(fam))
	lines.append("Ledger: food %d, water %d+%d, heat %d, fuel %d, kits %d, inhalers %d, components %d" % [s.led("food"), s.led("water"), s.led("heater_water"), s.led("heat"), s.led("fuel"), s.led("kits"), s.led("inhalers"), s.led("components")])
	lines.append("Profile %d (%s) · Word %+d · Mercy %+d · trusting households %d" % [s.profile, Act0.profile_tier(s.profile), s.word, s.mercy, s.trusting_households(2)])
	var st: Array = []
	for f in s.standing:
		if int(s.standing[f]) != 0:
			st.append("%s %+d" % [f, int(s.standing[f])])
	lines.append("Standing: " + (", ".join(st) if not st.is_empty() else "none"))
	lines.append("Killings: %d %s" % [s.kills.size(), ", ".join(s.kills.map(func(k: Dictionary) -> String: return "%s (%s)" % [k["who"], k["kind"]]))])
	lines.append("Habits the teen copied: " + ", ".join(s.habits))
	var veh: Array = []
	for v in s.vehicles:
		veh.append("%s hardening [%s] %s%s" % [v["kind"], ",".join(v.get("mods", [])), v["state"], " worn" if v.get("worn", false) else ""])
	lines.append("Vehicles: " + ", ".join(veh))
	lines.append("Device: %s %s, screen %s" % [OS.get_name(), OS.get_model_name(), str(DisplayServer.screen_get_size())])
	return "\n".join(lines)


# ------------------------------------------------------------------ agent screenshots
func debug_scene(name: String) -> void:
	if m.s == null:
		m.s = GameState.new(7)
	match name:
		"family":
			show_family_screen()
		"planner":
			quick_defaults()
			finish_family()
			s.set_flag("scene_cookout")
			Act0.start_week(s)
			s.set_flag("week_started_1")
			selected_activity = "shield_kit"
			show_planner()
		"court":
			quick_defaults()
			finish_family()
			start_cookout()
		"tvhwy":
			quick_defaults()
			finish_family()
			s.phase = "act1"
			s.watch = 2
			_dz_map()
		"worldmap":
			quick_defaults()
			finish_family()
			s.phase = "act1"
			s.members["hero"]["where"] = "home"
			s.members["elder"]["where"] = "sorrel"
			s.members["partner"]["where"] = "hospital"
			_wm_sel = "sorrel"
			show_worldmap()
		"battle":
			quick_defaults()
			finish_family()
			s.items["rifle"] = 1
			s.ledger["rounds"] = 15
			m.start_battle("pump_four", func() -> void: pass)
		"garage":
			quick_defaults()
			finish_family()
			s.vehicles.append({"kind": "rig_90s", "mods": ["tarp"], "load": {"power_station": 1}, "state": "ok"})
			s.set_flag("seal_bag")
			s.items["food_bucket"] = 4
			show_planner()
			show_garage(show_planner)
		"summary":
			quick_defaults()
			finish_family()
			show_summary()
