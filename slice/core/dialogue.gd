class_name Dialogue
extends RefCounted
## Dialogue runner over JSON node graphs (dialogue.md node anatomy): shown
## gates that never roll, Make Do, fail-forward, effects through Rules.
## The interface and the bots call the same three functions.

var s: GameState
var data: Dictionary
var node_id := ""
var pending_events: Array = []
var families_used: Array = []
var extra: Dictionary = {}   # {token: text} filled by the presentation


func _init(state: GameState, dialogue_id: String) -> void:
	s = state
	data = Rules.db("dialogue/" + dialogue_id)
	enter(String(data["start"]))


func node() -> Dictionary:
	return data["nodes"].get(node_id, {})


func done() -> bool:
	return node_id == "end" or node_id == ""


func enter(id: String) -> void:
	node_id = id
	if done():
		return
	var n := node()
	if n.has("effects"):
		pending_events.append_array(Rules.apply(s, n["effects"]))
	# A node may redirect by condition, for branches the player does not pick.
	if n.has("route"):
		for r in n["route"]:
			if Rules.check(s, r.get("cond", [])):
				enter(String(r["next"]))
				return


func speaker() -> String:
	return s.fill(String(node().get("speaker", "")))


func text() -> String:
	var t := String(node().get("text", ""))
	for k in extra:
		t = t.replace("{%s}" % k, String(extra[k]))
	return s.fill(t)


## Visible options: [{index, text, enabled, label, family}]. Options whose
## cond fails are hidden; gated options always show their number.
func options() -> Array:
	var out: Array = []
	var opts: Array = node().get("options", [])
	for i in opts.size():
		var o: Dictionary = opts[i]
		if o.has("cond") and not Rules.check(s, o["cond"]):
			continue
		var enabled := true
		var label := ""
		if o.has("gate"):
			var g := Rules.gate(s, o["gate"][0], int(o["gate"][1]))
			label = Rules.gate_label(s, o["gate"][0], int(o["gate"][1]))
			enabled = g["pass"] or g["make_do"] or o.has("fail")
			if o.get("calm", false) and s.strain_band("hero") >= 2:
				enabled = false
				label += " [Shaken: calm lines lock]"
		if o.has("cost_money") and s.money + s.cash < int(o["cost_money"]):
			enabled = false
			label = "[Needs $%d]" % int(o["cost_money"])
		out.append({"index": i, "text": s.fill(String(o["text"])), "enabled": enabled, "label": label, "family": o.get("family", "")})
	if out.is_empty():
		out.append({"index": -1, "text": "(Leave)", "enabled": true, "label": "", "family": ""})
	return out


## Choose an option by its index. Returns events for the presentation.
func choose(index: int) -> Array:
	if index < 0:
		enter("end")
		return _flush()
	var o: Dictionary = node()["options"][index]
	var next := String(o.get("next", "end"))
	if o.has("gate"):
		var g := Rules.gate(s, o["gate"][0], int(o["gate"][1]))
		if not g["pass"]:
			if g["make_do"]:
				s.add_strain("hero", int(g["cost"]))
				s.add_log("Make Do: passed %s %d for %d Strain." % [GameState.SKILL_NAMES[o["gate"][0]], int(o["gate"][1]), int(g["cost"])])
			elif o.has("fail"):
				next = String(o["fail"])
				if o.has("fail_effects"):
					pending_events.append_array(Rules.apply(s, o["fail_effects"]))
				enter(next)
				return _flush()
			else:
				return []
	if o.has("cost_money"):
		var c := int(o["cost_money"])
		var from_cash := mini(s.cash, c)
		s.cash -= from_cash
		s.money -= c - from_cash
	if o.has("family"):
		families_used.append(o["family"])
	if o.has("effects"):
		pending_events.append_array(Rules.apply(s, o["effects"]))
	enter(next)
	return _flush()


func _flush() -> Array:
	var e := pending_events
	pending_events = []
	return e
