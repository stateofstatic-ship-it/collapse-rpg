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
