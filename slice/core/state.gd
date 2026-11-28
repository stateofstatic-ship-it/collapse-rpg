class_name GameState
extends RefCounted
## The whole simulation state. No nodes, no rendering, no clock, no global
## random (tech.md Architecture). Everything saves through to_dict().

const ATTRS: Array[String] = ["sinew", "tenacity", "reflex", "wits", "awareness", "discipline", "empathy"]
const ATTR_NAMES := {"sinew": "Sinew", "tenacity": "Tenacity", "reflex": "Reflex", "wits": "Wits", "awareness": "Awareness", "discipline": "Discipline", "empathy": "Empathy"}
const ATTR_GROUPS := {"Body": ["sinew", "tenacity", "reflex"], "Mind": ["wits", "awareness"], "Will": ["discipline", "empathy"]}
## Skill: [primary, secondary] (character.md Skills).
const SKILLS := {
	"firearms": ["awareness", "discipline"], "close_quarters": ["sinew", "tenacity"],
	"bowcraft": ["awareness", "sinew"], "stealth": ["reflex", "awareness"],
	"security": ["reflex", "discipline"], "fieldcraft": ["tenacity", "awareness"],
	"homestead": ["tenacity", "sinew"], "medicine": ["wits", "empathy"],
	"mechanics": ["sinew", "wits"], "electronics": ["wits", "reflex"],
	"signals": ["discipline", "awareness"], "negotiation": ["empathy", "wits"],
	"leadership": ["discipline", "empathy"], "guile": ["empathy", "reflex"],
}
const SKILL_NAMES := {
	"firearms": "Firearms", "close_quarters": "Close Quarters", "bowcraft": "Bowcraft", "stealth": "Stealth",
	"security": "Security", "fieldcraft": "Fieldcraft", "homestead": "Homestead", "medicine": "Medicine",
	"mechanics": "Mechanics", "electronics": "Electronics", "signals": "Signals", "negotiation": "Negotiation",
	"leadership": "Leadership", "guile": "Guile",
}
const TRANSFERABLE: Array[String] = ["medicine", "homestead", "fieldcraft", "mechanics", "negotiation", "leadership"]
const ROLES: Array[String] = ["hero", "partner", "teen", "child", "elder"]
const HOUSEHOLDS := {
	"pellow": "Ruth Pellow", "dunmore": "Arlo Dunmore", "lisk": "Teo Lisk",
	"varga": "Inez Varga", "achterberg": "the Achterbergs", "quan": "Marisol Quan",
}
const FACTIONS := {"halls": "Harvest Halls", "union": "Carburetor Union", "guard": "Talbert Guard", "relay": "The Relay", "nation": "Goldthread River Nation", "twelvemonth": "The Twelvemonth"}
const TRACKS := {"stores": "Stores", "shielded": "Shielded electronics", "radio": "Radio", "cash": "Cash and barter", "old_iron": "Old Iron", "arms": "Arms", "medical": "Medical", "homestead": "Homestead", "bugout": "Bug-out site", "hardening": "Home hardening", "paper": "Paper records", "fitness": "Fitness"}

var game_seed: int = 1
var streams: Dictionary = {}   # name -> [seed, state]

var members: Dictionary = {}   # role -> member dict
var dog_name: String = "Pilot"
var surname: String = "Hale"
var job: String = "mechanic"
var traits: Array = []
var specialties: Array = []

var phase: String = "family"   # family, act0, dayzero, act1, done
var week: int = 1
var blocks_used: int = 0
var day: int = 0               # Act 1 day, Day Zero = 0
var watch: int = 2             # 0 morning, 1 afternoon, 2 evening, 3 night
var money: int = 1200
var card: int = 0
var cash: int = 0
var barter: int = 0
var job_standing: int = 60
var profile: int = 5
var word: int = 0
var mercy: int = 0
var checks_bonus: int = 0

var ledger: Dictionary = {"food": 7, "water": 3, "heater_water": 8, "heat": 2, "fuel": 8, "kits": 1, "inhalers": 20, "components": 0, "rounds": 0}
var tracks: Dictionary = {}
var flags: Dictionary = {}
var neighbors: Dictionary = {}       # household -> trust 0..3
var neighbor_week: Dictionary = {}   # household -> last week raised
var standing: Dictionary = {}
var items: Dictionary = {}           # id -> count, in the house
var shielded: Dictionary = {}        # id -> count, in the sealed locker
var vehicles: Array = []             # [{kind, cover, load: {id: n}, state}]
var device_state: Dictionary = {}    # after Day Zero: "where:id" -> {"alive": n, "dead": n}
var orders: Array = []               # [{activity, arrive}]
var week_log: Array = []             # [{week, picks}]
var activity_counts: Dictionary = {}
var classes: Array = []
var tallies: Array = []
var habits: Array = []               # teen habits copied from the hero
var quests: Dictionary = {}          # id -> {state, end}
var clues: Array = []
var board: Dictionary = {}           # thread -> [{week, solid, checked}]
var stars: Array = []
var last_pin: String = ""
var kills: Array = []
var journal: Array = []                  # player-facing journal lines
var telemetry: Dictionary = {}       # segment -> seconds (filled by the presentation)
var perks: Array = []


func _init(p_seed: int = 1) -> void:
	game_seed = p_seed
	for t in TRACKS:
		tracks[t] = 0.0
	for h in HOUSEHOLDS:
		neighbors[h] = 0
		neighbor_week[h] = 0
	neighbors["pellow"] = 1
	for f in FACTIONS:
		standing[f] = 0
	items = {"phone": 1, "laptop": 1, "led_lantern": 1, "hand_tools": 1, "bicycle": 1}
	vehicles = [{"kind": "family_car", "mods": [], "load": {}, "state": "ok"}]
	default_family()


# ------------------------------------------------------------------ random
func rng(stream: String) -> RandomNumberGenerator:
	var r := RandomNumberGenerator.new()
	if streams.has(stream):
		r.seed = String(streams[stream][0]).to_int()
		r.state = String(streams[stream][1]).to_int()
	else:
		r.seed = hash("%d:%s" % [game_seed, stream])
	return r


func save_rng(stream: String, r: RandomNumberGenerator) -> void:
	streams[stream] = [str(r.seed), str(r.state)]


func roll(stream: String, sides: int = 100) -> int:
	var r := rng(stream)
	var v := r.randi_range(1, sides)
	save_rng(stream, r)
	return v


# ------------------------------------------------------------------ family
func default_family() -> void:
	members = {
		"hero": _member("hero", "Morgan", "they", 0, {"sinew": 4, "tenacity": 4, "reflex": 4, "wits": 4, "awareness": 4, "discipline": 4, "empathy": 4}, {}),
		"partner": _member("partner", "Dana", "she", 1, {"sinew": 4, "tenacity": 5, "reflex": 4, "wits": 6, "awareness": 5, "discipline": 6, "empathy": 6}, {"medicine": 60, "negotiation": 30}),
		"teen": _member("teen", "Tess", "she", 2, {"sinew": 4, "tenacity": 6, "reflex": 7, "wits": 5, "awareness": 5, "discipline": 3, "empathy": 4}, {"stealth": 30, "fieldcraft": 20}),
		"child": _member("child", "Eli", "he", 3, {"sinew": 2, "tenacity": 4, "reflex": 4, "wits": 4, "awareness": 4, "discipline": 2, "empathy": 5}, {}),
		"elder": _member("elder", "Walt", "he", 4, {"sinew": 3, "tenacity": 3, "reflex": 3, "wits": 6, "awareness": 5, "discipline": 6, "empathy": 5}, {"electronics": 50, "mechanics": 30}),
	}
	members["hero"]["pronoun_key"] = "they"


func _member(role: String, given: String, pron: String, heritage: int, attrs: Dictionary, fixed: Dictionary) -> Dictionary:
	return {"role": role, "name": given, "pronoun_key": pron, "heritage": heritage, "attrs": attrs,
		"fixed": fixed, "bonus": {}, "strain": 0, "buyin": 20 + 3 * int(attrs["empathy"]), "hp": 0, "where": "home"}


func hero() -> Dictionary:
	return members["hero"]


func attr(role: String, a: String) -> int:
	return int(members[role]["attrs"][a])


## Skill value before Strain: authored sheets for family, else 2 x primary + secondary, plus bonuses.
func skill_base(role: String, s: String) -> int:
	var m: Dictionary = members[role]
	var pair: Array = SKILLS[s]
	var v := 2 * int(m["attrs"][pair[0]]) + int(m["attrs"][pair[1]])
	if m["fixed"].has(s):
		v = maxi(v, int(m["fixed"][s]))
	v += int(m["bonus"].get(s, 0))
	return clampi(v, 0, 100)


func strain_band(role: String) -> int:
	var m: Dictionary = members[role]
	var d := int(m["attrs"]["discipline"])
	var st := int(m["strain"])
	if st >= mini(95, 80 + 2 * d):
		return 3
	if st >= 55 + 2 * d:
		return 2
	if st >= 30 + 2 * d:
		return 1
	return 0


func strain_penalty(role: String) -> int:
	return [0, 5, 15, 15][strain_band(role)]


func skill(role: String, s: String) -> int:
	return maxi(0, skill_base(role, s) - strain_penalty(role))


func hp_max(role: String) -> int:
	return 20 + 5 * attr(role, "tenacity") + 2 * attr(role, "sinew")


func ap_max(role: String) -> int:
	var a := 7 if attr(role, "reflex") >= 7 else 6
	if strain_band(role) >= 2:
		a -= 1
	return a


func buyin_avg() -> int:
	var t := 0
	for r in ROLES:
		t += int(members[r]["buyin"])
	return int(round(float(t) / ROLES.size()))


func add_buyin(n: int) -> void:
	for r in ROLES:
		if r != "hero":
			members[r]["buyin"] = clampi(int(members[r]["buyin"]) + n, 0, 100)


func add_strain(role: String, n: int) -> void:
	members[role]["strain"] = clampi(int(members[role]["strain"]) + n, 0, 100)


# ------------------------------------------------------------------ tokens
const PRONOUNS := {
	"she": {"they": "she", "them": "her", "their": "her", "theirs": "hers", "are": "is", "kin": "Mom"},
	"he": {"they": "he", "them": "him", "their": "his", "theirs": "his", "are": "is", "kin": "Dad"},
	"they": {"they": "they", "them": "them", "their": "their", "theirs": "theirs", "are": "are", "kin": ""},
}


## Resolves {role.name}, {role.they}, {dog.name}, {family.surname} and {hero.kin}.
func fill(text: String) -> String:
	if text.find("{") < 0:
		return text
	var out := text
	for r in ROLES:
		var m: Dictionary = members[r]
		var p: Dictionary = PRONOUNS.get(m["pronoun_key"], PRONOUNS["they"])
		out = out.replace("{%s.name}" % r, m["name"])
		for k in ["they", "them", "their", "theirs", "are"]:
			out = out.replace("{%s.%s}" % [r, k], p[k])
			out = out.replace("{%s.%s_cap}" % [r, k], String(p[k]).capitalize())
		var kin: String = m.get("kinword", "")
		if kin == "":
			kin = p["kin"] if p["kin"] != "" else m["name"]
		out = out.replace("{%s.kin}" % r, kin)
	out = out.replace("{dog.name}", dog_name)
	out = out.replace("{family.surname}", surname)
	return out


# ------------------------------------------------------------------ ledger helpers
func led(k: String) -> int:
	return int(ledger.get(k, 0))


func add_led(k: String, n: int) -> void:
	ledger[k] = maxi(0, led(k) + n)


func trusting_households(tier: int = 2) -> int:
	var n := 0
	for h in neighbors:
		if int(neighbors[h]) >= tier:
			n += 1
	return n


func flag(f: String) -> bool:
	return bool(flags.get(f, false))


func set_flag(f: String, v: bool = true) -> void:
	flags[f] = v


func add_standing(f: String, n: int) -> void:
	standing[f] = clampi(int(standing.get(f, 0)) + n, -100, 100)


func add_log(line: String) -> void:
	journal.append(fill(line))


func has_vehicle() -> bool:
	return vehicles.size() > 0


func vehicle(kind: String) -> Dictionary:
	for v in vehicles:
		if v["kind"] == kind:
			return v
	return {}


# ------------------------------------------------------------------ save
const SAVE_KEYS: Array[String] = ["game_seed", "streams", "members", "dog_name", "surname", "job", "traits", "specialties", "phase", "week", "blocks_used", "day", "watch", "money", "card", "cash", "barter", "job_standing", "profile", "word", "mercy", "checks_bonus", "ledger", "tracks", "flags", "neighbors", "neighbor_week", "standing", "items", "shielded", "vehicles", "device_state", "orders", "week_log", "activity_counts", "classes", "tallies", "habits", "quests", "clues", "board", "stars", "last_pin", "kills", "journal", "telemetry", "perks"]


func to_dict() -> Dictionary:
	var d := {"schema": 1}
	for k in SAVE_KEYS:
		d[k] = get(k)
	return d


static func from_dict(d: Dictionary) -> GameState:
	var s := GameState.new(int(d.get("game_seed", 1)))
	for k in SAVE_KEYS:
		if d.has(k):
			var v: Variant = d[k]
			var cur: Variant = s.get(k)
			if cur is int and v is float:
				v = int(v)
			s.set(k, v)
	return s


## Stable hash for replay tests.
func state_hash() -> int:
	return hash(JSON.stringify(to_dict(), "", true))
