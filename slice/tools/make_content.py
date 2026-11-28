#!/usr/bin/env python3
"""Compile the slice's content to JSON: dialogue, fights, the world map and
local maps. Every file under content/ except items.json and activities.json
comes from this one command (tech.md working conventions).

Run from the slice folder: python3 tools/make_content.py
"""
import json
import os
import random
import re
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
OUT = os.path.join(ROOT, "content")
sys.path.insert(0, HERE)

import content_act0  # noqa: E402
import content_act1  # noqa: E402

FAMILY_DEFAULTS = ["Morgan", "Dana", "Tess", "Eli", "Walt", "Pilot"]
GENDERED = re.compile(r"\b(wife|husband|son|daughter|mom|dad|mother|father|grandpa|grandma)\b", re.I)


def write(rel, data):
    path = os.path.join(OUT, rel)
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "w") as f:
        json.dump(data, f, indent=1, ensure_ascii=False)


def lint_dialogue(name, d):
    """Name and token lint (bible): no hard-coded family names or gendered family words;
    every next/fail target exists; every option list is non-empty."""
    errors = []
    nodes = d["nodes"]
    for nid, n in nodes.items():
        texts = [n.get("text", ""), n.get("speaker", "")] + [o["text"] for o in n.get("options", [])]
        for t in texts:
            for fam in FAMILY_DEFAULTS:
                if re.search(r"\b%s\b" % fam, t):
                    errors.append("%s/%s: hard-coded family name %s" % (name, nid, fam))
            m = GENDERED.search(re.sub(r"\{[^}]*\}", "", t))
            if m:
                errors.append("%s/%s: gendered family word '%s'" % (name, nid, m.group(0)))
        for o in n.get("options", []):
            for k in ("next", "fail"):
                tgt = o.get(k)
                if tgt and tgt != "end" and tgt not in nodes:
                    errors.append("%s/%s: %s target %s missing" % (name, nid, k, tgt))
        for r in n.get("route", []):
            if r["next"] != "end" and r["next"] not in nodes:
                errors.append("%s/%s: route target %s missing" % (name, nid, r["next"]))
        if not n.get("options") and not n.get("route"):
            errors.append("%s/%s: dead end" % (name, nid))
    if d["start"] not in nodes:
        errors.append("%s: start missing" % name)
    return errors


# ------------------------------------------------------------------ fights
ENCOUNTERS = {
    "range": {
        "name": "The range on 47", "size": [12, 10], "night": False, "practice": True, "loan_weapon": "rifle",
        "kill_kind": "practice", "tiles": "concrete",
        "cover": [[6, 4, "half"], [7, 4, "half"], [3, 3, "full"], [4, 3, "full"]],
        "props": {"crate": [[6, 4], [7, 4], [3, 3], [4, 3]]},
        "party_cells": [[5, 8]], "allies": [],
        "enemies": [
            {"name": "Paper target, close", "look": "char_civilian", "cell": [5, 5], "hp": 20, "ap": 1, "skill": 0, "weapon": "fists", "dummy": True, "grain": "sees_red", "init": 1},
            {"name": "Target behind sandbags", "look": "char_civilian", "cell": [7, 3], "hp": 20, "ap": 1, "skill": 0, "weapon": "fists", "dummy": True, "grain": "sees_red", "init": 1},
            {"name": "Target behind the wall", "look": "char_civilian", "cell": [3, 2], "hp": 20, "ap": 1, "skill": 0, "weapon": "fists", "dummy": True, "grain": "sees_red", "init": 1}],
        "win": [["flag", "range_done"], ["log", "Range day with Arlo: all three targets down."]],
        "parley": [], "lose": [],
        "after": "arlo_range_after"},
    "pump_four": {
        "name": "Pump Four", "size": [14, 12], "night": False, "kill_kind": "self_defense",
        "tiles": "concrete",
        "cover": [[6, 5, "full"], [6, 6, "full"], [8, 5, "full"], [8, 6, "full"], [3, 8, "half"], [4, 8, "half"], [10, 3, "half"], [11, 3, "half"], [2, 4, "half"]],
        "props": {"car": [[3, 8]], "crate": [[10, 3], [11, 3], [2, 4]], "lamp": [[6, 5], [8, 5]]},
        "party_cells": [[3, 10]], "allies": [],
        "enemies": [
            {"name": "Siphon man", "look": "char_raider", "cell": [9, 4], "hp": 35, "ap": 5, "skill": 30, "weapon": "pistol", "strain": 35, "discipline": 3, "grain": "bolts", "leader": True, "init": 10},
            {"name": "Can carrier", "look": "char_worker", "cell": [11, 5], "hp": 35, "ap": 5, "skill": 25, "weapon": "knife", "strain": 40, "discipline": 3, "grain": "bolts", "init": 9}],
        "win": [["fuel", 5], ["log", "Pump Four: the fuel thieves are gone. The clerk filled your tank."]],
        "parley": [["log", "Pump Four: they took their cans and left."]],
        "lose": [["strain", "hero", 15], ["log", "Pump Four: you came to on the concrete. Bruised, not broken. They took the cans and your wallet."], ["money", -120]],
        "after": "pump_four_after"},
    "carjack": {
        "name": "Sylvan", "size": [14, 12], "night": True, "kill_kind": "self_defense",
        "tiles": "asphalt",
        "cover": [[5, 5, "full"], [6, 5, "full"], [9, 7, "half"], [3, 3, "half"], [10, 2, "half"]],
        "props": {"car": [[5, 5], [9, 7]], "tree": [[3, 3], [10, 2], [12, 9]]},
        "party_cells": [[4, 10], [5, 10], [3, 10]], "allies": ["teen", "elder"],
        "enemies": [
            {"name": "Man with a knife", "look": "char_raider", "cell": [7, 3], "hp": 45, "ap": 6, "skill": 35, "weapon": "knife", "strain": 30, "discipline": 5, "grain": "locks_up", "leader": True, "init": 11},
            {"name": "Man with a pry bar", "look": "char_worker", "cell": [8, 4], "hp": 35, "ap": 5, "skill": 25, "weapon": "tool", "strain": 50, "discipline": 3, "grain": "bolts", "init": 9},
            {"name": "Hungry kid", "look": "char_civilian", "cell": [6, 2], "hp": 30, "ap": 5, "skill": 20, "weapon": "fists", "strain": 55, "discipline": 2, "grain": "bolts", "init": 12}],
        "win": [["log", "Sylvan: the road is clear."]],
        "parley": [["log", "Sylvan: they let you pass."]],
        "lose": [["strain", "hero", 15], ["food", -2], ["log", "Sylvan: they took the bag and your shoes. You walked on in socks."]]},
    "night_attempt": {
        "name": "The garage", "size": [12, 10], "night": True, "kill_kind": "defense_of_others",
        "tiles": "concrete",
        "cover": [[4, 4, "full"], [5, 4, "full"], [8, 6, "half"], [2, 7, "half"]],
        "props": {"car": [[4, 4]], "crate": [[8, 6], [2, 7]]},
        "party_cells": [[2, 8], [3, 8], [1, 8]], "allies": ["partner", "teen", "elder"],
        "enemies": [
            {"name": "Thief with a bar", "look": "char_raider", "cell": [8, 2], "hp": 35, "ap": 5, "skill": 30, "weapon": "tool", "strain": 45, "discipline": 3, "grain": "bolts", "leader": True},
            {"name": "Lookout", "look": "char_worker", "cell": [10, 3], "hp": 30, "ap": 5, "skill": 25, "weapon": "knife", "strain": 50, "discipline": 3, "grain": "bolts"}],
        "win": [["log", "The night thieves are gone."]],
        "parley": [["log", "The night thieves backed off over the fence."]],
        "lose": [["food", -5], ["fuel", -4], ["strain", "hero", 10], ["log", "The thieves cleaned out part of the garage."]]},
}

# ------------------------------------------------------------------ world map
WORLDMAP = {
    "_source": "Node miles are rough road distances (hypothesis). Travel: foot 15 miles a day, bicycle 40, Old Iron 120 (f4.md).",
    "nodes": {
        "tvhwy": {"name": "TV Highway, Hillsboro", "pos": [640, 560], "map": "tvhwy", "blurb": "Where the flash caught you."},
        "home": {"name": "Thimbleberry Court", "pos": [760, 430], "map": "court", "blurb": "Home."},
        "school": {"name": "{teen.name}'s school", "pos": [960, 560], "dialogue": "school", "blurb": "{teen.name} was at practice."},
        "sorrel": {"name": "Sorrel House, Forest Grove", "pos": [330, 410], "dialogue": "sorrel", "blurb": "{elder.name}'s care home."},
        "hospital": {"name": "The hill hospital, Portland", "pos": [1400, 360], "dialogue": "hospital", "approach": "west_hills", "blurb": "{partner.name}'s shift. Across the West Hills."},
    },
    "links": {"tvhwy>home": 2.5, "home>school": 2.5, "tvhwy>school": 2.0, "home>sorrel": 7.0, "school>sorrel": 8.0, "tvhwy>sorrel": 6.0,
              "home>hospital": 17.0, "tvhwy>hospital": 16.0, "school>hospital": 17.0, "sorrel>hospital": 23.0},
}


# ------------------------------------------------------------------ local maps
def blank(w, h, ch="."):
    return [[ch] * w for _ in range(h)]


def court_map():
    rng = random.Random(11)
    W = H = 30
    g = blank(W, H)
    cx, cy = 15, 12
    for y in range(H):
        for x in range(W):
            d = ((x - cx) ** 2 + (y - cy) ** 2) ** 0.5
            if d <= 4.2:
                g[y][x] = "="
            elif d <= 5.3:
                g[y][x] = "-"
    for y in range(cy + 4, H):
        for x in (14, 15, 16):
            g[y][x] = "="
        g[y][13] = "-"
        g[y][17] = "-"
    houses = {"home": (22, 21), "pellow": (10, 6), "dunmore": (16, 4), "lisk": (22, 6), "varga": (25, 13), "achterberg": (7, 13), "quan": (9, 21)}
    for name, (hx, hy) in houses.items():
        g[hy][hx] = "H"
    for _ in range(40):
        x, y = rng.randrange(W), rng.randrange(H)
        if g[y][x] == "." and all(abs(x - hx) > 5 or abs(y - hy) > 5 for hx, hy in houses.values()) and abs(x - 15) > 3:
            g[y][x] = "T"
    for x, y in [(12, 8), (18, 8), (12, 16), (18, 16)]:
        g[y][x] = "l"
    for x, y in [(20, 17), (11, 9)]:
        g[y][x] = "c"
    return {"id": "court", "size": [W, H], "rows": ["".join(r) for r in g], "spawn": [15, 27],
            "houses": houses,
            "variants": {
                "cookout": {"night": False, "spawn": [17, 17],
                            "npcs": [
                                {"id": "arlo", "name": "Arlo Dunmore", "look": "char_trader", "cell": [16, 9], "dialogue": "cookout_arlo", "once": True},
                                {"id": "ruth", "name": "Ruth Pellow", "look": "char_elder", "cell": [12, 10], "dialogue": "cookout_ruth", "once": True},
                                {"id": "teo", "name": "Teo Lisk", "look": "char_survivor", "cell": [19, 11], "dialogue": "cookout_teo", "once": True},
                                {"id": "partner", "name": "{partner.name}", "look": "char_medic", "cell": [14, 14], "role": "partner", "line": "\"Go be social. I'm on the potato salad.\""},
                                {"id": "teen", "name": "{teen.name}", "look": "char_civilian", "cell": [17, 13], "role": "teen", "line": "\"I'm not watching the grill. I'm watching the grill.\""},
                                {"id": "child", "name": "{child.name}", "look": "char_civilian", "cell": [15, 15], "role": "child", "scale": 0.75, "line": "\"Can {dog.name} have a hot dog?\""}],
                            "objects": [{"id": "table", "name": "The long table", "prop": "crate", "cell": [15, 12], "line": "Potato salad, three kinds of chips, and a cooler with a hand-lettered sign: TAKE ONE."}],
                            "finish": {"needs": ["arlo", "ruth", "teo"], "event": "cookout_dog"}},
                "act1": {"night": True, "spawn": [15, 26],
                         "npcs": [
                             {"id": "ruth1", "name": "Ruth Pellow", "look": "char_elder", "cell": [11, 9], "line": "\"Check-on chain's running. Ask me if you need to know who's short.\""},
                             {"id": "hank", "name": "Hank Achterberg", "look": "char_worker", "cell": [9, 14], "line": "\"Farmhouse well behind us still pumps by hand. Just so you know.\""}],
                         "objects": [
                             {"id": "meeting", "name": "Ruth's garage: the lantern meeting", "prop": "lamp", "cell": [10, 8], "dialogue": "lantern_meeting", "cond": [["day_ge", 2], ["not_flag", "m2_done"]]},
                             {"id": "thaw", "name": "The Dunmores' dead freezer", "prop": "crate", "cell": [16, 8], "dialogue": "thaw", "cond": [["day_ge", 1]]},
                             {"id": "radio", "name": "The radio shelf", "prop": "crate", "cell": [21, 18], "dialogue": "relay_radio"},
                             {"id": "garage", "name": "Your garage", "prop": "none", "cell": [19, 19], "event": "garage_view"}],
                         "exits": [{"cell": [15, 29], "label": "Leave the court (world map)", "event": "worldmap"}]}}}


def tvhwy_map():
    rng = random.Random(5)
    W, H = 32, 22
    g = blank(W, H)
    for y in range(H):
        for x in range(W):
            if 8 <= y <= 12:
                g[y][x] = "="
            elif y in (7, 13):
                g[y][x] = "-"
            elif y < 7 and rng.random() < 0.15:
                g[y][x] = ","
    for x in range(14, 21):
        for y in range(14, 19):
            g[y][x] = "-"
    for (x, y) in [(5, 5), (11, 5), (27, 5), (8, 20), (27, 20)]:
        g[y][x] = "H"
    cars = [(2, 9), (6, 11), (9, 8), (12, 10), (16, 9), (19, 11), (23, 8), (26, 10), (29, 9), (4, 12), (21, 9)]
    for (x, y) in cars:
        g[y][x] = "c"
    for (x, y) in [(3, 7), (13, 13), (24, 7), (30, 13)]:
        g[y][x] = "l"
    return {"id": "tvhwy", "size": [W, H], "rows": ["".join(r) for r in g], "spawn": [12, 11],
            "variants": {
                "dayzero": {"night": True, "spawn": [12, 11],
                            "npcs": [
                                {"id": "dell", "name": "Dell Ranta", "look": "char_elder", "cell": [16, 16], "dialogue": "dz_pickup"},
                                {"id": "hollis", "name": "Hollis", "look": "char_trader", "cell": [20, 6], "dialogue": "dz_bikeshop"},
                                {"id": "rafael", "name": "A trapped driver", "look": "char_civilian", "cell": [25, 12], "dialogue": "dz_driver"},
                                {"id": "woman", "name": "A woman with a phone", "look": "char_survivor", "cell": [10, 13], "line": "\"No service. Not even 911. Is yours...? No. Okay.\""}],
                            "objects": [
                                {"id": "phone", "name": "Your phone", "prop": "none", "cell": [12, 10], "dialogue": "dz_phone"},
                                {"id": "sky", "name": "Look up at the sky", "prop": "none", "cell": [14, 12], "dialogue": "dz_sky"},
                                {"id": "pickup", "name": "Orange 1968 pickup", "prop": "car", "cell": [17, 17], "dialogue": "dz_pickup"},
                                {"id": "sedan", "name": "Crashed sedan", "prop": "car", "cell": [26, 12], "dialogue": "dz_driver"},
                                {"id": "bikes", "name": "Bike rack", "prop": "crate", "cell": [21, 6], "dialogue": "dz_bikeshop"}],
                            "exits": [{"cell": [31, 10], "label": "Read the signs, then head home", "event": "diagnose"},
                                      {"cell": [0, 10], "label": "Read the signs, then head home", "event": "diagnose"}]}}}


def main():
    errors = []
    dialogues = {}
    dialogues.update(content_act0.D)
    dialogues.update(content_act1.D)
    for name, d in dialogues.items():
        d["id"] = name
        errors += lint_dialogue(name, d)
        write("dialogue/%s.json" % name, d)
    for k, e in ENCOUNTERS.items():
        if e.get("after") and e["after"] not in dialogues:
            errors.append("encounter %s: after %s missing" % (k, e["after"]))
    write("encounters.json", ENCOUNTERS)
    write("worldmap.json", WORLDMAP)
    write("maps/court.json", court_map())
    write("maps/tvhwy.json", tvhwy_map())
    words = 0
    for d in dialogues.values():
        for n in d["nodes"].values():
            words += len(n.get("text", "").split())
            for o in n.get("options", []):
                words += len(o["text"].split())
    with open(os.path.join(OUT, "word_count.json"), "w") as f:
        json.dump({"dialogues": len(dialogues), "words": words}, f)
    print("dialogues %d, words %d" % (len(dialogues), words))
    if errors:
        print("\n".join(errors))
        sys.exit(1)


if __name__ == "__main__":
    main()
