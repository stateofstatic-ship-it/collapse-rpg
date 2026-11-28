"""Act 0 dialogue for the slice (prep90.md tutorial beats, Pump Four, the Blow, the Eve).

Shipped strings use family tokens ({partner.name}, {teen.they}, ...), never
hard-coded family names or pronouns (bible lint rule). Neighbors are fixed NPCs.
"""

D = {}

# ------------------------------------------------------------ Labor Day cookout
D["cookout_intro"] = {"start": "a", "nodes": {
    "a": {"speaker": "Monday, September 6, 2027", "text":
          "Labor Day on Thimbleberry Court. Eleven driveways, one long table, and a wind out of the east that smells faintly of somebody else's fire.\n\n"
          "{partner.name} has a shift at the hill hospital tomorrow. {teen.name} is pretending not to watch the grill. {child.name} has the inhaler in a pocket, because the air index says Moderate and climbing. "
          "{dog.name} is under the table, waiting for a mistake.\n\nWalk the court. Talk to your neighbors. Tap a person once to see them, twice to go to them.",
          "options": [{"text": "Go out to the street.", "next": "end"}]}}}

D["cookout_arlo"] = {"start": "a", "nodes": {
    "a": {"speaker": "Arlo Dunmore", "text":
          "\"Saw you hauling those blue jugs in on Saturday. Six of them. You planning a camping trip, or is there something on the news I missed?\" He's smiling. He also keeps looking at your garage.",
          "options": [
              {"text": "\"Camping. The kids want to try the coast before it gets cold.\"", "family": "talk", "gate": ["guile", 15],
               "effects": [["log", "Arlo bought the camping story."]], "next": "lie"},
              {"text": "\"Honestly? The fires last year. I'd rather have water and not need it.\"", "family": "talk",
               "effects": [["trust", "dunmore", 1], ["profile", 3]], "next": "truth"},
              {"text": "\"Come by Saturday and I'll show you the filter setup. Costs less than you'd think.\"", "family": "talk", "gate": ["negotiation", 20],
               "effects": [["trust", "dunmore", 1], ["profile", 2], ["tally", "arlo_filter", "Show Arlo the water filter setup"]], "next": "invite"}]},
    "lie": {"speaker": "Arlo Dunmore", "text": "\"The coast. Huh. Bring me back some taffy.\" He lets it go. Your Profile stays where it was; your street knows a little less about you.",
            "options": [{"text": "Move on.", "next": "end"}]},
    "truth": {"speaker": "Arlo Dunmore", "text": "\"Smart. I've got a generator in the garage I've never run. Maybe you can tell me which end the gas goes in.\" He means it as a joke. It isn't, quite.\n\nTelling a household the plan gives Trust +1 and Profile +3.",
              "options": [{"text": "Move on.", "next": "end"}]},
    "invite": {"speaker": "Arlo Dunmore", "text": "\"Deal.\" A promise is a Tally now: dated, witnessed, and remembered. Keep it and your Word grows; break it and the street hears.",
               "options": [{"text": "Move on.", "next": "end"}]}}}

D["cookout_ruth"] = {"start": "a", "nodes": {
    "a": {"speaker": "Ruth Pellow", "text":
          "Ruth spent thirty-one years as a 911 dispatcher and still sits like she's waiting for the board to light. The oxygen line runs from her nose to a concentrator humming on her porch.\n\n"
          "\"If the power ever goes for more than a few hours, would you knock? The machine runs on the wall. The bottles in the closet give me two days, maybe.\"",
          "options": [
              {"text": "\"I'll knock. First thing. You have my word.\"", "family": "talk",
               "effects": [["tally", "ruth_knock", "Knock on Ruth's door if the power fails"], ["trust", "pellow", 1], ["word", 1]], "next": "promise"},
              {"text": "\"{partner.name} knows more about oxygen than I do. Let's put you on our list.\"", "family": "talk", "cond": [["buyin_role", "partner", 35]],
               "effects": [["tally", "ruth_knock", "Knock on Ruth's door if the power fails"], ["trust", "pellow", 1], ["buyin_role", "partner", 3]], "next": "promise"},
              {"text": "\"I can't promise that, Ruth. I'm not always home.\"", "family": "talk", "next": "decline"}]},
    "promise": {"speaker": "Ruth Pellow", "text": "\"Good. I ran the check-on chain for this street once. Maybe I will again.\" She writes your house number on a card and tucks it in her blouse pocket.",
                "options": [{"text": "Move on.", "next": "end"}]},
    "decline": {"speaker": "Ruth Pellow", "text": "\"Honest, at least.\" She looks back at the table. No promise, no Tally, nothing owed.",
                "options": [{"text": "Move on.", "next": "end"}]}}}

D["cookout_teo"] = {"start": "a", "nodes": {
    "a": {"speaker": "Teo Lisk", "text":
          "Teo teaches the ham radio night class at the community college and has a box fan with a furnace filter taped to it, which he swears is the best thing you can do for smoke.\n\n"
          "\"Air's going to get bad tomorrow. That's the last fan at the hardware store and it's mine. I'd sell it, though. Sixty bucks, or that camp stove of yours, or you owe me a Saturday on my roof.\"",
          "options": [
              {"text": "Pay $60.", "family": "trade", "cost_money": 60, "effects": [["flag", "clean_room"], ["trust", "lisk", 1]], "next": "deal"},
              {"text": "Trade the camp stove.", "family": "trade", "cond": [["item", "camp_stove"]], "effects": [["item", "camp_stove", -1], ["flag", "clean_room"], ["trust", "lisk", 1]], "next": "deal"},
              {"text": "\"A Saturday on your roof. Done.\"", "family": "trade", "effects": [["flag", "clean_room"], ["trust", "lisk", 1], ["tally", "teo_roof", "Spend a Saturday on Teo's roof"]], "next": "deal"},
              {"text": "\"We'll manage.\"", "family": "talk", "next": "nope"}]},
    "deal": {"speaker": "Teo Lisk", "text": "\"Shut one room, run the fan, keep the kid in there. The EPA calls it a clean room.\" He winks. \"And come to the class. Week two, four or six. A license gets you on the Air pins.\"",
             "options": [{"text": "Move on.", "next": "end"}]},
    "nope": {"speaker": "Teo Lisk", "text": "\"Your call.\" Tomorrow {child.name} will use two inhaler-days instead of one.",
             "options": [{"text": "Move on.", "effects": [["inhalers", -1]], "next": "end"}]}}}

D["cookout_dog"] = {"start": "a", "nodes": {
    "a": {"speaker": "Fireworks", "text":
          "Somebody's cousin lights a fountain at the end of the court. A big shepherd mix bolts its leash and comes straight down the sidewalk at {dog.name}, hackles up.\n\n{teen.name} is watching you, not the dogs.",
          "options": [
              {"text": "Throw your jacket over its head and hold on.", "family": "fix", "gate": ["fieldcraft", 20],
               "effects": [["habit", "steady hands"], ["mercy", 1]], "fail": "bitten", "fail_effects": [["strain", "hero", 8]], "next": "calm"},
              {"text": "Call {dog.name} back and step between them.", "family": "talk",
               "effects": [["habit", "step between"]], "next": "calm"},
              {"text": "Shove the shepherd hard into the hedge.", "family": "fight",
               "effects": [["habit", "hit first"], ["mercy", -1]], "next": "shove"}]},
    "calm": {"speaker": "Fireworks", "text": "The shepherd's owner arrives at a run, red-faced and apologizing. Nobody bleeds. {teen.name} files it away: when things break, this is what we do.",
             "options": [{"text": "Back to the table.", "next": "end"}]},
    "bitten": {"speaker": "Fireworks", "text": "The jacket slips and the dog gets a mouthful of your forearm before its owner drags it off. Nothing deep. Your heart takes longer to slow than your arm does. (+8 Strain.) A missed gate never dead-ends a scene.",
               "options": [{"text": "Back to the table.", "next": "end"}]},
    "shove": {"speaker": "Fireworks", "text": "It yelps and runs. The owner gives you a look you will see again. {teen.name} files it away too.",
              "options": [{"text": "Back to the table.", "next": "end"}]}}}

D["cookout_end"] = {"start": "a", "nodes": {
    "a": {"speaker": "Sunday, September 12", "text":
          "By Sunday the smoke has thinned to a brown edge on the horizon. {partner.name} spreads the hospital's surge-drill checklist on the kitchen table: one kit and one plan for every hazard, the way the state's 2 Weeks Ready asks.\n\n"
          "The family adopts the Bedrock as its first shared goal: Water, Pantry, Warmth, Medicine, Circle, Plan and Skills. The fridge card will name one gap each week.\n\n"
          "From here, each week has three blocks: Weeknights, Saturday and Sunday. Orders ship two Mondays out. October 17 is the Last Truck.",
          "options": [{"text": "Open the week planner.", "next": "end"}]}}}

# ------------------------------------------------------------ Pump Four (week 4)
D["pump_four"] = {"start": "a", "nodes": {
    "a": {"speaker": "Tanager Fuel, Cornelius", "text":
          "Saturday, October 2. You stop for gas with {teen.name} in the passenger seat. At pump four two men from out of town have a hose down the underground tank port and a row of red cans. The clerk is on the phone, hiding behind the counter.\n\n"
          "One of them sees you see him. He lifts his shirt enough to show a pistol grip. \"Keep driving.\"",
          "options": [
              {"text": "\"Police are four minutes out and the camera got your plates. Walk away now and it's just a bad day.\"", "family": "talk", "gate": ["negotiation", 45], "calm": True,
               "effects": [["habit", "talk it down"], ["mercy", 1], ["log", "You talked down the fuel thieves at Pump Four."]], "next": "talked"},
              {"text": "Drive away and call it in.", "family": "sneak",
               "effects": [["habit", "walk away"], ["log", "You left Pump Four and called it in."]], "next": "left"},
              {"text": "Get out of the car.", "family": "fight", "effects": [["habit", "stand your ground"], ["battle", "pump_four"]], "next": "end"},
              {"text": "Strike first, before he can draw.", "family": "fight", "effects": [["habit", "hit first"], ["flag", "struck_first"], ["battle", "pump_four"]], "next": "end"}]},
    "talked": {"speaker": "Tanager Fuel", "text": "A long second. Then the hose comes out of the port and they leave the cans. The clerk gives you a free fill-up and a look of something close to awe. {teen.name} doesn't say anything all the way home.",
               "options": [{"text": "Home.", "effects": [["fuel", 5]], "next": "end"}]},
    "left": {"speaker": "Tanager Fuel", "text": "You pull out slowly. In the mirror one of them raises a can at you like a toast. The police arrive in nineteen minutes. They're gone.",
             "options": [{"text": "Home.", "next": "end"}]}}}

D["pump_four_after"] = {"start": "a", "nodes": {
    "a": {"speaker": "Tanager Fuel", "text": "Sirens, finally. A deputy takes your statement on the hood of your car. \"You did fine,\" he says, in a voice that means he has seen people not do fine. {teen.name} is shaking a little and trying to hide it.",
          "options": [{"text": "Home.", "next": "end"}]}}}

# ------------------------------------------------------------ The Blow (week 5)
D["the_blow"] = {"start": "a", "nodes": {
    "a": {"speaker": "Saturday, October 9", "text":
          "The wind comes up the valley at three in the afternoon and doesn't stop. By five the transformers on Baseline are popping blue one after another. The court goes dark.\n\n"
          "It's a dress rehearsal nobody scheduled.",
          "options": [{"text": "Light a lantern.", "next": "rally"}]},
    "rally": {"speaker": "The Blow", "route": [{"cond": [["flag", "rally_cards"]], "next": "rally_cards"}], "text":
              "Everyone ends up in the kitchen eventually, but it takes {teen.name} two hours to get home from a friend's, and nobody knew where anyone was.\n\n(No rally cards. Paper Day makes them, and a rehearsal makes them work.)",
              "options": [{"text": "Next.", "next": "ruth"}]},
    "rally_cards": {"speaker": "The Blow", "text":
                    "The rally card is on the fridge: if the power goes and phones don't, call; if phones go, come home; if home's not safe, the Baseline Branch library. {teen.name} is through the door in twenty minutes. It works because it's written down.\n\nThe rally plan is rehearsed.",
                    "options": [{"text": "Next.", "effects": [["flag", "rally_rehearsed"], ["buyin", 3]], "next": "ruth"}]},
    "ruth": {"speaker": "Ruth Pellow's porch", "text": "Ruth's concentrator is silent. Through the window you can see her switching to a bottle by flashlight.",
             "options": [
                 {"text": "Knock, like you promised.", "cond": [["tally", "ruth_knock"]], "family": "talk",
                  "effects": [["keep_tally", "ruth_knock"], ["trust", "pellow", 1], ["flag", "street_chain"], ["log", "Ruth starts the check-on chain by lantern. The street chain is formed."]], "next": "chain"},
                 {"text": "Knock anyway.", "cond": [["not_tally", "ruth_knock"]], "family": "talk",
                  "effects": [["trust", "pellow", 1], ["flag", "street_chain"]], "next": "chain"},
                 {"text": "She has bottles. Stay in.", "family": "sneak", "effects": [["break_tally", "ruth_knock"]], "next": "arlo"}]},
    "chain": {"speaker": "Ruth Pellow", "text": "\"Knew you would.\" She has a clipboard already. By nine o'clock, every house on the court has been knocked on twice and the Achterbergs' newborn has a warm room at the Quans'. Ruth runs it like a dispatch board.",
              "options": [{"text": "Next.", "next": "arlo"}]},
    "arlo": {"speaker": "Arlo Dunmore's garage", "text": "There's an engine running in Arlo's garage. The door is down. You can smell it from the sidewalk.",
             "options": [
                 {"text": "Bang on the door and get him to open it. Generators kill people in shut garages.", "family": "know",
                  "effects": [["trust", "dunmore", 1], ["mercy", 2], ["log", "You got Arlo's garage door open before the CO got him."]], "next": "arlo_ok"},
                 {"text": "Not your business.", "family": "sneak", "next": "arlo_bad"}]},
    "arlo_ok": {"speaker": "Arlo Dunmore", "text": "He comes out gray-faced and dizzy. \"I didn't know,\" he keeps saying. He'll come knocking to borrow fuel next week, and you'll both know why you'd say yes.",
                "options": [{"text": "Morning comes.", "next": "shortfall"}]},
    "arlo_bad": {"speaker": "Arlo Dunmore", "text": "The ambulance comes at two in the morning, lights and no siren. He lives. He doesn't know you smelled it.",
                 "options": [{"text": "Morning comes.", "next": "shortfall"}]},
    "shortfall": {"speaker": "Sunday, October 10", "text": "The power comes back at ten. The fridge card has a new line on it, in {partner.name}'s handwriting: what would we have done on day three?\n\nThe Blow is the Signal Board's first threat. It has passed.",
                  "options": [{"text": "Back to the planner.", "next": "end"}]}}}

# ------------------------------------------------------------ The Eve
D["eve"] = {"start": "a", "nodes": {
    "a": {"speaker": "Sunday, October 31", "text":
          "Halloween. The court at dusk: pumpkins, a few kids in costumes, Ruth handing out full-size bars because \"you only get so many Halloweens.\" "
          "Every thread on the Signal Board is loud this week, and none of them has happened yet.\n\n"
          "The Last Pin: name the thread you believe. Being right is worth family Buy-in +5. Being wrong costs nothing.",
          "options": [{"text": "Pin a thread.", "next": "end"}]}}}

D["breakfast"] = {"start": "a", "nodes": {
    "a": {"speaker": "Monday, November 1, 2027", "text":
          "Breakfast. {partner.name} is late for the early shift and eating standing up. {elder.name} called from the care home in Forest Grove to complain about the oatmeal. {teen.name} is texting under the table. {child.name} wants to know why the sky looked green in a dream.\n\n"
          "\"I'll be home by seven,\" you say, and grab your keys, and the day is ordinary all the way to dusk.",
          "options": [{"text": "Drive to work.", "next": "end"}]}}}


# ------------------------------------------------------------ weekly street tasks
# Each Act 0 week puts one hands-on task on the street map that teaches a mechanic.

# Split the Blow so the dark search happens between the outage and the night.
_blow = D["the_blow"]
D["the_blow_after"] = {"start": "rally", "nodes": {k: v for k, v in _blow["nodes"].items() if k != "a"}}
D["the_blow_after"]["nodes"]["shortfall"]["options"] = [{"text": "Back to the street.", "next": "end"}]
D["the_blow"] = {"start": "a", "nodes": {
    "a": dict(_blow["nodes"]["a"], text=_blow["nodes"]["a"]["text"] + "\n\nThen {teen.name} shouts from the hall: {child.name} went out the back after {dog.name} when the lights died. Neither of them came back.",
              options=[{"text": "Grab a light and go find them.", "next": "end"}])}}

# Week 2: Ruth's check-on chain teaches gates, Make Do, family help and a delivery quest.
D["ruth_chain"] = {"start": "a", "nodes": {
    "a": {"speaker": "Ruth Pellow", "text":
          "Ruth waves you up onto the porch. She has an index-card box on her knees.\n\n"
          "\"The check-on chain. If the power goes, every house gets a knock inside a day. It only works if somebody walks it once so people believe in it. "
          "I need a list of who runs on a plug: oxygen, insulin, a CPAP. And I need this card in Marisol Quan's hand. She stopped answering the door for me.\"",
          "options": [
              {"text": "\"Let me organize the whole list.\"", "family": "talk", "gate": ["leadership", 25],
               "effects": [["trust", "pellow", 1], ["flag", "chain_list"]], "fail": "org_fail", "next": "org"},
              {"text": "\"{partner.name} can tell you who's on what. Nurses know.\"", "family": "talk", "cond": [["buyin_role", "partner", 30]],
               "effects": [["trust", "pellow", 1], ["flag", "chain_list"], ["buyin_role", "partner", 2]], "next": "family"},
              {"text": "\"I'll carry the card to Marisol.\"", "family": "talk", "next": "card"},
              {"text": "\"Not this week, Ruth.\"", "family": "talk", "next": "later"}]},
    "org": {"speaker": "Ruth Pellow", "text":
            "You have the list on two cards before her tea goes cold.\n\n"
            "[How it works] That option was a skill check. Checks never roll dice: if your skill meets the number, it works. "
            "If you are a little short, MAKE DO lets you push through anyway and costs Strain. A family member standing with you can Assist.",
            "options": [{"text": "\"And the card for Marisol?\"", "next": "card"}]},
    "org_fail": {"speaker": "Ruth Pellow", "text":
                 "You get halfway and lose track of who is on what. Ruth takes the cards back, kindly.\n\n"
                 "[How it works] You were too far short of that skill check, so it failed. Night Class or practice raises a skill; Make Do covers small gaps at a Strain cost.",
                 "options": [{"text": "\"At least let me carry the card.\"", "next": "card"}]},
    "family": {"speaker": "Ruth Pellow", "text":
               "{partner.name} rattles off half the street from memory. Ruth writes fast.\n\n"
               "[How it works] Some options only appear when a family member trusts you enough. That is Buy-in: time together raises it.",
               "options": [{"text": "\"And the card for Marisol?\"", "next": "card"}]},
    "card": {"speaker": "Ruth Pellow", "text":
             "She presses a card into your hand: a phone tree, three names, a time to knock. \"West side, the house with the wind chimes. Tap her door.\"\n\n"
             "[How it works] A task now sits in your Journal. The gold marker on the map shows where it goes.",
             "options": [{"text": "Take the card.", "effects": [["flag", "quan_card"], ["quest", "quan_card", "open"], ["log", "Ruth's card: take it to Marisol Quan's door."]], "next": "end"}]},
    "later": {"speaker": "Ruth Pellow", "text": "\"The street will still be here next week. Probably.\"",
              "options": [{"text": "Leave.", "next": "end"}]}}}

D["quan_card"] = {"start": "a", "nodes": {
    "a": {"speaker": "Marisol Quan", "text":
          "The door opens on the chain. Marisol is in scrubs from the overnight shift at the plant, and there is a hum from the back bedroom you recognize: a CPAP.\n\n\"Ruth sent you? She still does this?\"",
          "options": [
              {"text": "\"She does. If the power goes, somebody knocks here inside a day.\"", "family": "talk",
               "effects": [["trust", "quan", 1], ["flag", "quan_done"], ["quest", "quan_card", "done"]], "next": "ok"},
              {"text": "\"That's your CPAP running. Do you have a battery for it?\"", "family": "know", "gate": ["medicine", 20],
               "effects": [["trust", "quan", 2], ["flag", "quan_done"], ["quest", "quan_card", "done"]], "fail": "ok",
               "fail_effects": [["trust", "quan", 1], ["flag", "quan_done"], ["quest", "quan_card", "done"]], "next": "cpap"}]},
    "ok": {"speaker": "Marisol Quan", "text": "She takes the card. \"Tell Ruth I'm sorry about the door.\"\n\nTask done. Trust with the Quans went up. Trusting households share, warn and help when it matters.",
           "options": [{"text": "Back to the street.", "next": "end"}]},
    "cpap": {"speaker": "Marisol Quan", "text": "Her shoulders drop. \"No. I've been meaning to.\" You talk her through a deep-cycle battery and an inverter for ten minutes on the step.\n\nNoticing what someone needs is worth more Trust than delivering the card.",
             "options": [{"text": "Back to the street.", "next": "end"}]}}}

# Week 3: Arlo's range day teaches the fight screen with a practice lane.
D["arlo_range"] = {"start": "a", "nodes": {
    "a": {"speaker": "Arlo Dunmore", "text":
          "Arlo is loading a hard case into his trunk. \"Bought a rifle when they started talking about the wind season. Never fired it. The range out on 47 rents lanes. Come with? I'll cover the fee.\"",
          "options": [
              {"text": "\"Let's go.\"", "family": "fight", "effects": [["battle", "range"]], "next": "end"},
              {"text": "\"Not my thing, Arlo.\"", "family": "talk", "next": "no"}]},
    "no": {"speaker": "Arlo Dunmore", "text": "\"Suit yourself.\" He'll ask again.", "options": [{"text": "Leave.", "next": "end"}]}}}

D["arlo_range_after"] = {"start": "a", "nodes": {
    "a": {"speaker": "Arlo Dunmore", "text":
          "\"You've done that before,\" Arlo says, which you haven't.\n\n"
          "[How it works] Every action costs Action Points (AP). Quick shots are cheap; aimed shots cost more and hit more often. "
          "Cover between you and a target cuts the odds. Tap a foe to see the exact chance before you commit. A hit 40 points under the odds is a solid hit for half again the damage.\n\n"
          "Firearms +3. Real fights also have Call Out (make them back down) and Parley (let them leave).",
          "options": [{"text": "Drive home.", "effects": [["skill", "hero", "firearms", 3], ["trust", "dunmore", 1]], "next": "end"}]}}}

# Week 6: Teo's shielding bag teaches sealing and the garage.
D["teo_bag"] = {"start": "a", "nodes": {
    "a": {"speaker": "Teo Lisk", "text":
          "Teo is on his ladder again. He climbs down holding a silver pouch. \"Shielding bag. I sealed spares for the radio club and had one left. "
          "Anything sealed in here should ride out a pulse that kills everything plugged in. Want it?\"",
          "options": [
              {"text": "\"Yes. Show me how.\"", "family": "talk", "effects": [["flag", "seal_bag"], ["trust", "lisk", 1], ["flag", "teo_bag_given"]], "next": "how"},
              {"text": "\"Not yet.\"", "family": "talk", "next": "end"}]},
    "how": {"speaker": "Teo Lisk", "text":
            "\"Small electronics only. Fold the top twice, tape it, test it with your phone: no signal, good seal.\"\n\n"
            "[How it works] In your garage, tap a device under Seal to put it in the bag. Sealed gear almost always survives the flash; unsealed electronics usually do not. "
            "Vehicles load by weight, and hardening steps lower the chance the engine dies.",
            "options": [{"text": "Go to your garage.", "effects": [["garage"]], "next": "end"}]}}}

# Week 8: Inez's radio teaches the Signal Board.
D["inez_radio"] = {"start": "a", "nodes": {
    "a": {"speaker": "Inez Varga", "text":
          "Inez has her handheld radio on the porch rail and a notebook full of call signs. \"The hams hear things before the news does. Want to listen in for an hour?\"",
          "options": [
              {"text": "\"Show me.\"", "family": "talk", "effects": [["checks", 3], ["trust", "varga", 1], ["flag", "inez_radio"]], "next": "how"},
              {"text": "\"Another time.\"", "family": "talk", "next": "end"}]},
    "how": {"speaker": "Inez Varga", "text":
            "\"Half of it is noise. The trick is which stories hold up when you check them.\"\n\n"
            "[How it works] The Signal Board lists the news about seven possible disasters. Each look tells you if a story holds up. "
            "Stories that hold up raise the odds for that disaster. You get 3 extra looks tonight.",
            "options": [{"text": "Open the Signal Board.", "next": "end"}]}}}
