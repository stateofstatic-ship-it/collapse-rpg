"""Stopped Clocks Day Zero and Act 1 dialogue (f4.md): the flash, the
diagnosis, M1 Gather, M2 The Week After, Thaw and the Profile knocks."""

D = {}

# ------------------------------------------------------------ Day Zero
D["dz_flash"] = {"start": "a", "nodes": {
    "a": {"speaker": "TV Highway, 5:12 pm", "text":
          "Stop-and-go traffic on TV Highway, low cloud, the light going. Then the overcast goes white from one horizon to the other, without a sound, like someone opened a door in the sky.\n\n"
          "Your engine dies. So does the radio, the dashboard, the car ahead of you and the one behind. Every brake light on the highway goes out at once. A few blocks north the light rail train glides to a stop and sits there, dark.\n\n"
          "The cloud is glowing now, a dull red going green at the edges. It will keep glowing for twelve minutes.",
          "options": [{"text": "Get out of the car.", "next": "b"}]},
    "b": {"speaker": "TV Highway", "text":
          "People are standing beside their cars, looking up, holding phones that don't do anything. Somewhere a car alarm is not going off, which is the strangest sound of all.\n\n"
          "Night is coming fast and there isn't a lit window anywhere. Your sight is down to two tiles.\n\n"
          "Read the signs before you decide what this is. Phones, cars, the sky. Then get home.",
          "options": [{"text": "Look around.", "next": "end"}]}}}

D["dz_phone"] = {"start": "a", "nodes": {
    "a": {"speaker": "Your phone", "route": [{"cond": [["clue", "phones"]], "next": "seen"}], "text":
          "Black. You hold the button and it does nothing. The woman next to you has a phone that lights up and shows no service, not even emergency calls. Half the phones on this block are dead; the rest can't find a tower.\n\nIt isn't the bank or the network. Something reached into the hardware itself.",
          "options": [{"text": "Noted.", "effects": [["clue", "phones"]], "next": "end"}]},
    "seen": {"speaker": "Your phone", "text": "Still black.", "options": [{"text": "Put it away.", "next": "end"}]}}}

D["dz_sky"] = {"start": "a", "nodes": {
    "a": {"speaker": "The sky", "route": [{"cond": [["clue", "sky"]], "next": "seen"}], "text":
          "The glow is fading to a dirty green. You look for the usual line of jets stacking up for PDX. There are no lights in the sky at all. No blast, no heat, no shaking. Whatever happened, it happened high.",
          "options": [{"text": "Noted.", "effects": [["clue", "sky"]], "next": "end"}]},
    "seen": {"speaker": "The sky", "text": "Green fading to nothing. No aircraft lights.", "options": [{"text": "Look away.", "next": "end"}]}}}

D["dz_pickup"] = {"start": "a", "nodes": {
    "a": {"speaker": "Dell Ranta", "route": [{"cond": [["clue", "old_truck"]], "next": "again"}], "text":
          "An old man in a feed-store cap is cranking a faded orange 1968 pickup in the gas station lot. It coughs twice and catches, loud as a tractor, the only engine running for a mile.\n\n"
          "\"Points and a carburetor,\" Dell says, patting the door. \"Nothing in it to kill. Every car built since I retired just died, didn't it?\"",
          "options": [
              {"text": "\"Something physical hit the electronics. Not the power plant. Everything.\"", "family": "know", "effects": [["clue", "old_truck"]], "next": "ride"},
              {"text": "\"Any chance you're going my way?\"", "family": "talk", "effects": [["clue", "old_truck"]], "next": "ride"}]},
    "ride": {"speaker": "Dell Ranta", "text": "\"Going home to Cornelius. I can drop you off on the way if you push me out of this lot. Battery's fine, starter's tired.\"",
             "options": [
                 {"text": "Push, and take the ride home.", "family": "fix", "gate": ["mechanics", 20], "effects": [["flag", "dell_ride"], ["log", "Dell Ranta gave you a ride home in a 1968 pickup."]], "fail": "push_fail", "next": "thanks"},
                 {"text": "\"Thanks. I'll walk. Get home safe.\"", "family": "talk", "effects": [["mercy", 0]], "next": "end"}]},
    "push_fail": {"speaker": "Dell Ranta", "text": "You push, but you push wrong and the clutch pops too early. It stalls. Dell gets it going on the second try with the help of two teenagers, and you're left standing in the exhaust. \"Sorry, friend. Got to go while she's warm.\" (+5 Strain.)",
                  "options": [{"text": "Walk, then.", "effects": [["strain", "hero", 5]], "next": "end"}]},
    "thanks": {"speaker": "Dell Ranta", "text": "\"Hop in when you're done looking around.\" When you leave TV Highway the pickup will take you home in one watch instead of two.",
               "options": [{"text": "Finish up first.", "next": "end"}]},
    "again": {"speaker": "Dell Ranta", "text": "The pickup idles, loud and unbothered.", "options": [{"text": "Back.", "next": "end"}]}}}

D["dz_driver"] = {"start": "a", "route": [], "nodes": {
    "a": {"speaker": "A crashed sedan", "route": [{"cond": [["flag", "driver_done"]], "next": "done"}], "text":
          "A sedan coasted into a light pole when its steering assist died. The driver's door is crumpled shut and a young man inside is pinned at the knee, calling out in Spanish and then in English for anyone.",
          "options": [
              {"text": "Pry the door with the tools from your trunk.", "family": "fix", "gate": ["mechanics", 25],
               "effects": [["flag", "driver_done"], ["mercy", 3], ["strain", "hero", -3], ["log", "You pried Rafael Ochoa out of his car on TV Highway."]], "next": "freed",
               "fail": "pry_fail"},
              {"text": "Brace his leg and talk him through it while two others pull the door.", "family": "talk", "gate": ["medicine", 30],
               "effects": [["flag", "driver_done"], ["mercy", 3], ["log", "You and two strangers freed Rafael Ochoa on TV Highway."]], "next": "freed",
               "fail": "brace_fail"},
              {"text": "Leave him. Your family is out there.", "family": "sneak", "effects": [["flag", "driver_done"], ["flag", "left_driver"], ["strain", "hero", 6]], "next": "left"}]},
    "pry_fail": {"speaker": "A crashed sedan", "text": "The bar slips twice and the door doesn't move. A nurse coming off shift at the clinic down the road takes over and gets him out; you hold the light. It takes an hour. (A missed gate costs time, never the scene.)",
                 "options": [{"text": "Go.", "effects": [["flag", "driver_done"], ["mercy", 2], ["time", 1]], "next": "end"}]},
    "brace_fail": {"speaker": "A crashed sedan", "text": "You don't know how to brace it and he screams when they pull. He's out, though, and breathing. It takes an hour you didn't have.",
                   "options": [{"text": "Go.", "effects": [["flag", "driver_done"], ["mercy", 2], ["time", 1]], "next": "end"}]},
    "freed": {"speaker": "Rafael Ochoa", "text": "He's out, white-faced, holding your sleeve. \"Rafael. Ochoa. I live by the fairgrounds. If you need something, I'm the guy with the welding truck that doesn't work anymore.\"\n\nStrangers help at crashes. Most people, most of the time, do.",
              "options": [{"text": "Go.", "next": "end"}]},
    "left": {"speaker": "A crashed sedan", "text": "You walk on. Behind you, someone else stops. You don't look back to see if it was enough.", "options": [{"text": "Go.", "next": "end"}]},
    "done": {"speaker": "A crashed sedan", "text": "The sedan sits empty against the pole.", "options": [{"text": "Back.", "next": "end"}]}}}

D["dz_bikeshop"] = {"start": "a", "nodes": {
    "a": {"speaker": "Hollis, Spoke & Sprocket", "route": [{"cond": [["flag", "took_bike"]], "next": "done"}], "text":
          "The bike shop's owner is chaining the rack with a headlamp in his teeth. The headlamp is dead too, so he's using a match. \"Card reader's gone. Cash only, if you're buying. Three hundred for the commuter.\"",
          "options": [
              {"text": "Pay $300 in cash.", "family": "trade", "cond": [["cash", 300]], "effects": [["cash", -300], ["flag", "took_bike"], ["item", "bicycle", 1]], "next": "sold"},
              {"text": "\"I'll leave you my watch and my name. I'll pay you double next week.\"", "family": "talk", "gate": ["negotiation", 35],
               "effects": [["flag", "took_bike"], ["item", "bicycle", 1], ["tally", "hollis_pay", "Pay Hollis double for the bicycle"]], "next": "sold", "fail": "no"},
              {"text": "Wait until he turns his back and take one off the end of the rack.", "family": "sneak", "gate": ["stealth", 25],
               "effects": [["flag", "took_bike"], ["item", "bicycle", 1], ["mercy", -2], ["profile", 2]], "next": "stolen", "fail": "caught"},
              {"text": "Leave it.", "family": "talk", "next": "end"}]},
    "sold": {"speaker": "Hollis", "text": "\"Lights won't work. Brakes will.\" A bicycle covers 40 miles a day; feet cover 15.", "options": [{"text": "Go.", "next": "end"}]},
    "no": {"speaker": "Hollis", "text": "\"Sorry. Everybody's going to have a story tonight.\"", "options": [{"text": "Fair.", "next": "end"}]},
    "stolen": {"speaker": "Spoke & Sprocket", "text": "You walk it into the dark, then ride. Nobody shouts. That's the worst part.", "options": [{"text": "Go.", "next": "end"}]},
    "caught": {"speaker": "Hollis", "text": "\"Hey!\" He gets a hand on the seat. You let go. Nobody says anything else, but three people saw it. (Profile +2.)",
               "options": [{"text": "Go.", "effects": [["profile", 2]], "next": "end"}]},
    "done": {"speaker": "Spoke & Sprocket", "text": "The rack is chained and the shop is dark.", "options": [{"text": "Back.", "next": "end"}]}}}

D["dz_diagnosis"] = {"start": "a", "nodes": {
    "a": {"speaker": "What is this?", "text":
          "You have seen: {clue_list}.\n\nSeveral collapses look alike for the first hour. What do the signs say?",
          "options": [
              {"text": "A pulse from high up. Something physical hit every circuit at once: old iron runs, new cars and phones died.", "cond": [["clue", "old_truck"]], "family": "know", "effects": [["flag", "diagnosed"]], "next": "right"},
              {"text": "A pulse from high up. Phones died in people's hands and there's nothing in the sky.", "cond": [["clue", "phones"], ["clue", "sky"]], "family": "know", "effects": [["flag", "diagnosed"]], "next": "right"},
              {"text": "A cyberattack on the grid.", "family": "know", "next": "wrong"},
              {"text": "A big blackout. It'll be back by morning.", "family": "know", "next": "wrong"}]},
    "wrong": {"speaker": "What is this?", "text": "That doesn't explain a dead phone in a stranger's hand, or a car with no wires to cut. You'll know soon enough. Everyone will.",
              "options": [{"text": "Keep looking.", "next": "end"}]},
    "right": {"speaker": "STOPPED CLOCKS", "text":
              "One silent flash above the clouds has killed the grid and most electronics for longer than a year. No outside help is coming; everywhere is here.\n\n"
              "What still works: Old Iron (points and carburetors, hand tools, bicycles) and whatever you sealed away. What doesn't: almost everything you bought after 1980.\n\n"
              "One doubt remains: is a war coming next? The Relay's ham operators will know, if you can hear them.\n\n"
              "Lesson perk gained: Light Discipline. Your household's light adds half the Profile, and the dark is a little less blind.",
              "options": [{"text": "Get home.", "effects": [["perk", "light_discipline"], ["flash_report"]], "next": "end"}]}}}

# ------------------------------------------------------------ M1 Gather
D["home_day0"] = {"start": "a", "nodes": {
    "a": {"speaker": "Thimbleberry Court", "text":
          "The court is dark and full of people standing in driveways with candles. Ruth has {child.name} and {dog.name} on her porch, the way the rally card said: if no one is home, go to Ruth's.\n\n"
          "{child.name} runs at you so hard you nearly go over.",
          "options": [{"text": "\"Everyone's coming home. I promise.\"", "effects": [["where", "child", "home"], ["tally", "promise_home", "Bring everyone home"]], "next": "check"}]},
    "check": {"speaker": "Thimbleberry Court", "route": [{"cond": [["where", "teen", "home"]], "next": "tess_here"}], "text": "{teen.name} isn't here. The school is two and a half miles. {elder.name} is in Forest Grove. {partner.name} is across the West Hills at the hill hospital.",
              "options": [{"text": "Check the garage.", "next": "garage"}]},
    "tess_here": {"speaker": "{teen.name}", "text": "{teen.name} is sitting on the front step with a dead phone in both hands. \"The card said come home. So I came home.\" The rally plan paid off before anything else did.",
                  "options": [{"text": "Check the garage.", "next": "garage"}]},
    "garage": {"speaker": "The garage", "text": "{garage_report}", "options": [{"text": "Plan the gather.", "next": "end"}]}}}

D["school"] = {"start": "a", "nodes": {
    "a": {"speaker": "{teen.name}'s school", "route": [{"cond": [["where", "teen", "home"]], "next": "gone"}], "text":
          "Two teachers are holding the doors with a clipboard and a lantern, releasing students only to a parent or a card. The reunification rules from October's drill are working, more or less.\n\n{teen.name} spots you from the gym steps.",
          "options": [{"text": "Sign {teen.name} out and go.", "family": "talk", "effects": [["where", "teen", "@hero"], ["log", "{teen.name} is with you."]], "next": "with"}]},
    "with": {"speaker": "{teen.name}", "text": "\"Everybody's saying it's a solar flare. It's not a solar flare, is it.\" {teen.name} is with you now and travels with you.",
             "options": [{"text": "\"Let's go.\"", "next": "end"}]},
    "gone": {"speaker": "{teen.name}'s school", "text": "\"Already home,\" the teacher says, checking the list by lantern. \"Followed the card.\"", "options": [{"text": "Good.", "next": "end"}]}}}

D["sorrel"] = {"start": "a", "nodes": {
    "a": {"speaker": "Sorrel House, Forest Grove", "route": [{"cond": [["not_where", "elder", "sorrel"]], "next": "gone"}], "text":
          "The care home is lit by battery lanterns and the night nurse is alone with thirty-one residents. She won't release anyone without papers. \"I'm sorry. I've got people on oxygen and no power. I can't have families just taking whoever they want.\"\n\n{elder.name} is in the lobby in a coat, with a bag packed.",
          "options": [
              {"text": "Show the power of attorney from Paper Day.", "family": "talk", "cond": [["flag", "poa"]], "effects": [["where", "elder", "@hero"], ["log", "Sorrel House released {elder.name} on the power of attorney."]], "next": "out"},
              {"text": "\"You've got thirty-one people and one pair of hands. One less is one less.\"", "family": "talk", "gate": ["negotiation", 35],
               "effects": [["where", "elder", "@hero"]], "next": "out", "fail": "wait"},
              {"text": "Walk {elder.name} out the side door past the night desk.", "family": "sneak", "gate": ["stealth", 30],
               "effects": [["where", "elder", "@hero"], ["profile", 1]], "next": "out_sneak", "fail": "caught"},
              {"text": "Come back in the morning when the day staff arrive.", "family": "talk", "next": "wait"}]},
    "out": {"speaker": "{elder.name}", "text": "\"Took you long enough.\" {elder.name} hugs you with one arm and grips a cane with the other. \"Linemen's card's in my wallet. Thirty-eight years. If they ever restart anything around here, they'll want somebody who remembers how.\"",
            "options": [{"text": "Go.", "effects": [["flag", "lineman_card"]], "next": "end"}]},
    "out_sneak": {"speaker": "{elder.name}", "text": "\"Like old times,\" {elder.name} whispers, delighted, and nearly trips on the threshold. Out in the dark: \"Linemen's card's in my wallet. Somebody'll want it.\" Note: {elder.name} walks one tile per AP and slows a bicycle to 25 miles a day.",
                  "options": [{"text": "Go.", "effects": [["flag", "lineman_card"]], "next": "end"}]},
    "caught": {"speaker": "Night nurse", "text": "\"No.\" She is in the hallway with her arms folded. \"Come back with the day staff, or with papers.\" (+5 Strain.)",
               "options": [{"text": "All right.", "effects": [["strain", "hero", 5]], "next": "wait"}]},
    "wait": {"speaker": "Sorrel House", "text": "You sleep in a lobby chair beside {elder.name}. In the morning the day staff release residents to anyone with a matching surname. You lose the night.",
             "options": [{"text": "Go, in the morning.", "effects": [["wait_morning"], ["where", "elder", "@hero"], ["flag", "lineman_card"]], "next": "end"}]},
    "gone": {"speaker": "Sorrel House", "text": "{elder.name}'s room is empty and the bed is made.", "options": [{"text": "Back.", "next": "end"}]}}}

D["west_hills"] = {"start": "a", "nodes": {
    "a": {"speaker": "The West Hills", "text":
          "The hill hospital is on the far side of the West Hills. The highway tunnel is a dark throat full of dead cars and people walking with their hands on the wall. The light rail tunnel beside it is darker and three miles long.",
          "options": [
              {"text": "Walk the rail tunnel in the dark. Shorter, and nobody else is in there.", "family": "sneak", "gate": ["stealth", 30],
               "effects": [["flag", "via_tunnel"], ["log", "You walked the dark rail tunnel under the West Hills."]], "next": "end", "fail": "tunnel_bad"},
              {"text": "Take the old road over the top through Sylvan.", "family": "fight", "effects": [["flag", "via_sylvan"]], "next": "sylvan"},
              {"text": "Go the long way round by Cornell Road. Two more watches, nobody on it.", "family": "talk", "effects": [["time", 2], ["strain", "hero", 4]], "next": "end"}]},
    "tunnel_bad": {"speaker": "The rail tunnel", "text": "Halfway in you lose the wall, then your nerve. You come out the way you went in an hour later, shaking, and take the long road. (+8 Strain, a watch lost.)",
                   "options": [{"text": "Over the top, then.", "effects": [["strain", "hero", 8], ["time", 1]], "next": "sylvan"}]},
    "sylvan": {"speaker": "Sylvan", "route": [{"cond": [["profile_lt", 0]], "next": "end"}], "text":
               "At the top of the hill three men have a dead minivan across the road and are going through a stopped car's trunk while its owner sits on the curb. One has a pry bar. One has a knife. The third looks at you and says, \"Bag. Shoes. Keep walking.\"",
               "options": [
                   {"text": "\"Three of you, one tired person with nothing worth a fight. You don't want this.\"", "family": "talk", "gate": ["negotiation", 45], "calm": True,
                    "effects": [["mercy", 1], ["log", "You talked your way through the Sylvan carjackers."]], "next": "talked", "fail": "fight_now"},
                   {"text": "Hand over the bag and walk on.", "family": "trade", "effects": [["food", -2], ["strain", "hero", 6], ["log", "You paid the Sylvan carjackers with your bag."]], "next": "paid"},
                   {"text": "Fight.", "family": "fight", "effects": [["battle", "carjack"]], "next": "end"}]},
    "fight_now": {"speaker": "Sylvan", "text": "\"Wrong answer.\" The one with the pry bar steps in.", "options": [{"text": "Fight.", "effects": [["battle", "carjack"]], "next": "end"}]},
    "talked": {"speaker": "Sylvan", "text": "The leader holds your eyes for a long moment, then jerks his head. You walk past. The car's owner walks with you, very fast.", "options": [{"text": "On to the hospital.", "next": "end"}]},
    "paid": {"speaker": "Sylvan", "text": "They take the bag and the two days of food in it and let you pass. It is the cheapest thing that could have happened. It doesn't feel cheap.", "options": [{"text": "On to the hospital.", "next": "end"}]}}}

D["hospital"] = {"start": "a", "nodes": {
    "a": {"speaker": "The hill hospital", "route": [{"cond": [["not_where", "partner", "hospital"]], "next": "gone"}], "text":
          "The generators carried the hospital for eleven hours and then the transfer switch, a box of dead circuit boards, stopped passing their power. Staff are bagging ventilated patients by hand in shifts.\n\n"
          "{partner.name} finds you at the ambulance bay, gloves still on. \"You came over the hill? Are the kids... okay. Okay.\" A breath. \"I have fourteen patients who can't breathe without someone squeezing a bag.\"",
          "options": [
              {"text": "\"Then I'll squeeze a bag. One shift, and then we go home together.\"", "family": "fix", "gate": ["medicine", 20],
               "effects": [["time", 1], ["buyin_role", "partner", 10], ["flag", "night_ward"], ["where", "partner", "@hero"], ["log", "Night Ward: you took a bagging shift. Two nurses will remember the street that helped."]], "next": "ward", "fail": "ward_fail"},
              {"text": "\"The kids need you. We need you. Please come home.\"", "family": "talk", "cond": [["buyin_role", "partner", 50]],
               "effects": [["where", "partner", "@hero"], ["strain", "partner", 10]], "next": "comes"},
              {"text": "\"Come home now.\"", "family": "talk", "gate": ["negotiation", 50], "effects": [["where", "partner", "@hero"], ["strain", "partner", 15]], "next": "comes", "fail": "stays"},
              {"text": "\"Stay. Do the work. Come home when you can.\"", "family": "talk", "effects": [["flag", "partner_stays"], ["buyin_role", "partner", 5], ["flag", "accounted_partner"]], "next": "stays"}]},
    "ward": {"speaker": "Night Ward", "text": "Squeeze, release, count. Six hours of it, in a corridor lit by headlamps from the shielded supply locker. Some patients die anyway; most don't. At the end of it {partner.name} peels off the gloves and says, \"Okay. Home.\"",
             "options": [{"text": "Home.", "next": "end"}]},
    "ward_fail": {"speaker": "Night Ward", "text": "You try. Your hands don't know the rhythm and a charge nurse moves you to carrying water instead. It still helps. {partner.name} comes with you at the end of the shift.",
                  "options": [{"text": "Home.", "effects": [["time", 1], ["where", "partner", "@hero"]], "next": "end"}]},
    "comes": {"speaker": "{partner.name}", "text": "{partner.name} hands the bag to someone else and doesn't look back, which costs more than it looks like it does.", "options": [{"text": "Home.", "next": "end"}]},
    "stays": {"speaker": "{partner.name}", "text": "\"Day seven. I'll walk home on day seven, whatever happens.\" It's a promise. You both know what promises cost now.",
              "options": [{"text": "Go home without {partner.name}.", "effects": [["flag", "partner_stays"], ["flag", "accounted_partner"]], "next": "end"}]},
    "gone": {"speaker": "The hill hospital", "text": "{partner.name} isn't here anymore.", "options": [{"text": "Back.", "next": "end"}]}}}

D["home_return"] = {"start": "a", "nodes": {
    "a": {"speaker": "Thimbleberry Court", "text": "{home_report}", "options": [{"text": "Continue.", "next": "end"}]}}}

# ------------------------------------------------------------ Nights and knocks
D["knock_ruth"] = {"start": "a", "nodes": {
    "a": {"speaker": "Ruth Pellow", "text":
          "Ruth's bottles are running down. She is calm about it in the way dispatchers are calm. \"Day two. I've got maybe a day.\"",
          "options": [
              {"text": "Run her concentrator off the power station.", "family": "fix", "cond": [["working", "power_station"]],
               "effects": [["trust", "pellow", 1], ["keep_tally", "ruth_knock"], ["flag", "ruth_powered"], ["profile", 2], ["log", "Your power station runs Ruth's oxygen at night. The hum carries."]], "next": "powered"},
              {"text": "Ask {partner.name} what can be done.", "family": "know", "cond": [["where", "partner", "home"]],
               "effects": [["trust", "pellow", 1], ["keep_tally", "ruth_knock"], ["log", "{partner.name} set Ruth's flow low and found her a seat in the Guard's water-point medical tent."]], "next": "dana"},
              {"text": "Sit with her, and keep the chain going.", "family": "talk", "effects": [["keep_tally", "ruth_knock"], ["trust", "pellow", 1]], "next": "sit"}]},
    "powered": {"speaker": "Ruth Pellow", "text": "The concentrator hums back to life on your battery. \"That's the best sound I've heard in two days.\" Every neighbor on the court can hear it too.", "options": [{"text": "Good night.", "next": "end"}]},
    "dana": {"speaker": "Ruth Pellow", "text": "\"Your {partner.name}'s a good one.\" She will make it. Not everyone on oxygen in this valley will.", "options": [{"text": "Good night.", "next": "end"}]},
    "sit": {"speaker": "Ruth Pellow", "text": "You sit with her until the lantern burns low. She tells you about the night of the '96 flood, when the board lit up from end to end. \"We got through that too.\"", "options": [{"text": "Good night.", "next": "end"}]}}}

D["knock_neighbors"] = {"start": "a", "nodes": {
    "a": {"speaker": "A knock", "text": "Two knocks tonight. The Achterbergs need water for formula. Marisol Quan wants to know whether it's true you have a whole garage of food. People talk; your Profile tells them where to knock.",
          "options": [
              {"text": "Give the Achterbergs two water-days.", "family": "trade", "cond": [["led", "water", 2]], "effects": [["water", -2], ["trust", "achterberg", 1], ["mercy", 2]], "next": "b"},
              {"text": "Tell them the Guard has a water point on Cornell Road.", "family": "know", "cond": [["clue", "guard_water"]], "effects": [["trust", "achterberg", 1]], "next": "b"},
              {"text": "\"We're stretched too. I'm sorry.\"", "family": "talk", "next": "b"}]},
    "b": {"speaker": "A knock", "text": "Marisol is still on the step.",
          "options": [
              {"text": "\"We've got enough to get by, same as you. Come to the meeting and we'll pool what we can.\"", "family": "talk", "gate": ["guile", 25], "effects": [["profile", -3]], "next": "end", "fail": "end"},
              {"text": "\"Yes. And if we share it smart, it'll last the street a week.\"", "family": "talk", "effects": [["trust", "quan", 1], ["profile", 3]], "next": "end"}]}}}

D["knock_strangers"] = {"start": "a", "nodes": {
    "a": {"speaker": "A knock", "text": "Three strangers at the door after dark: a man, a woman, a boy of about twelve. They walked from Beaverton. Someone told them this house has food.",
          "options": [
              {"text": "Give them three food-days and directions to the Guard water point.", "family": "trade", "cond": [["led", "food", 3]], "effects": [["food", -3], ["mercy", 4], ["profile", 2]], "next": "end"},
              {"text": "Through the door: \"Nothing here. Try the church on Baseline.\"", "family": "talk", "effects": [["mercy", -1]], "next": "end"}]}}}

D["night_attempt"] = {"start": "a", "nodes": {
    "a": {"speaker": "Night", "text": "{dog.name} growls at the back fence at two in the morning. Two shapes are working the garage door with a bar. Your Profile drew them here: a house that's Marked gets tried.",
          "options": [
              {"text": "Turn on a light and shout that you're armed.", "family": "talk", "gate": ["negotiation", 30], "effects": [["profile", 2]], "next": "fled", "fail": "fight"},
              {"text": "Go out and stop them.", "family": "fight", "effects": [["battle", "night_attempt"]], "next": "end"},
              {"text": "Let them have the garage. Lock the house.", "family": "sneak", "effects": [["food", -5], ["fuel", -4], ["strain", "hero", 8]], "next": "end"}]},
    "fled": {"speaker": "Night", "text": "Feet on gravel, then nothing. In the morning there are pry marks on the door and a dropped glove.", "options": [{"text": "Back to bed.", "next": "end"}]},
    "fight": {"speaker": "Night", "text": "They don't run.", "options": [{"text": "Fight.", "effects": [["battle", "night_attempt"]], "next": "end"}]}}}

# ------------------------------------------------------------ M2 The Week After
D["lantern_meeting"] = {"start": "a", "nodes": {
    "a": {"speaker": "The lantern meeting", "text":
          "Day {day}. Eleven households in Ruth's garage, one lantern, too many opinions. Water first: the taps {tap_state}. Then food, then who watches the street at night.\n\n"
          "Everyone keeps looking at you. Some of that is Trust. Some of it is Profile.",
          "options": [
              {"text": "Lay It Out: with three households already behind you, propose a common pantry and a watch rota.", "family": "talk", "cond": [["trust_count", 2, 3]],
               "effects": [["flag", "common_pantry"], ["quest", "m2", "done", "common_pantry"], ["food", 6], ["log", "M2: Common Pantry. The street pools its food and keeps a night watch. Cohesion +2."]], "next": "pantry"},
              {"text": "Propose a common pantry and a watch rota.", "family": "talk", "gate": ["leadership", 40], "cond": [["not_flag", "common_pantry"]],
               "effects": [["flag", "common_pantry"], ["quest", "m2", "done", "common_pantry"], ["food", 6], ["log", "M2: Common Pantry."]], "next": "pantry", "fail": "no_pantry"},
              {"text": "Build rain catchment off every downspout on the court.", "family": "fix", "gate": ["homestead", 35], "cond": [["led", "components", 2]],
               "effects": [["components", -2], ["flag", "catchment"], ["water", 22], ["quest", "m2", "done", "catchment"], ["log", "M2: rain catchment on the court, 22 water-days stored."]], "next": "catch"},
              {"text": "Offer the Achterbergs' farmhouse well your fuel for its hand pump: a well share.", "family": "trade", "cond": [["led", "fuel", 5]],
               "effects": [["fuel", -5], ["flag", "well_share"], ["quest", "m2", "done", "well_share"], ["log", "M2: Well Share. Ten gallons a month from the Achterberg well."]], "next": "well"},
              {"text": "Tell them about the Guard water point on Cornell Road.", "family": "know", "cond": [["clue", "guard_water"]],
               "effects": [["water", 10], ["standing", "guard", 3], ["quest", "m2", "done", "guard_point"], ["log", "M2: the street walks to the Guard water point."]], "next": "guard"},
              {"text": "Keep quiet. Your family's stores are your family's.", "family": "sneak",
               "effects": [["quest", "m2", "done", "house_alone"], ["profile", 10], ["log", "M2: House Alone. Profile +10."]], "next": "alone"}]},
    "no_pantry": {"speaker": "The lantern meeting", "text": "It falls apart over whose freezer counts. Nobody leaves angry, but nobody leaves agreed. Try another way, or go it alone.",
                  "options": [
                      {"text": "Fall back on the catchment idea.", "family": "fix", "gate": ["homestead", 35], "cond": [["led", "components", 2]],
                       "effects": [["components", -2], ["flag", "catchment"], ["water", 22], ["quest", "m2", "done", "catchment"]], "next": "catch"},
                      {"text": "Go it alone.", "family": "sneak", "effects": [["quest", "m2", "done", "house_alone"], ["profile", 10]], "next": "alone"}]},
    "pantry": {"speaker": "Ruth Pellow", "text": "Ruth writes it on the back of a calendar: who gives what, who watches when. \"I ran a dispatch board for thirty-one years,\" she says. \"I can run a pantry.\"\n\nCommon Pantry: the court shares food and keeps a watch. It is the first step toward a Court Charter.",
               "options": [{"text": "Good.", "next": "end"}]},
    "catch": {"speaker": "The lantern meeting", "text": "By Day 6 every downspout on the court runs into a barrel or a trash can. November in the valley is wet; for once that's good news.", "options": [{"text": "Good.", "next": "end"}]},
    "well": {"speaker": "Hank Achterberg", "text": "\"Pump's from 1952. Never needed power in its life.\" Ten gallons a month for your fuel, and a farmhouse that knows your name.", "options": [{"text": "Good.", "next": "end"}]},
    "guard": {"speaker": "The lantern meeting", "text": "The Talbert Guard runs a water point at the Cornell Road fire station: a hardened pump, two soldiers, a census clipboard. They want names. They give water.", "options": [{"text": "Good.", "next": "end"}]},
    "alone": {"speaker": "The lantern meeting", "text": "You say little and leave early. By the next night, the whole court has decided what it thinks your garage holds.", "options": [{"text": "Home.", "next": "end"}]}}}

D["thaw"] = {"start": "a", "nodes": {
    "a": {"speaker": "Thaw", "route": [{"cond": [["flag", "thaw_done"]], "next": "done"}], "text":
          "Every freezer on the court has been dead since Day 0. On Day 2 the meat is still cold. By Day 4 it won't be. That's two deer, a side of beef and the Quans' entire freezer of dumplings.",
          "options": [
              {"text": "Smoke, salt and can it, street-wide, in the Dunmores' driveway.", "family": "fix", "gate": ["homestead", 25],
               "effects": [["flag", "thaw_done"], ["food", 8], ["trust", "quan", 1], ["trust", "dunmore", 1], ["log", "Thaw: the street smoked and canned its freezers. Food-days +8."]], "next": "smoked", "fail": "half"},
              {"text": "Talk the court into one shared smokehouse and a share for everyone who brings meat.", "family": "talk", "gate": ["negotiation", 35],
               "effects": [["flag", "thaw_done"], ["food", 5], ["trust", "achterberg", 1], ["trust", "quan", 1]], "next": "shared", "fail": "half"},
              {"text": "Grill what you can tonight and let the rest go.", "family": "talk", "effects": [["flag", "thaw_done"], ["food", 2], ["strain_all", -3]], "next": "grill"}]},
    "smoked": {"speaker": "Thaw", "text": "Smoke hangs over the court for two days and every kid smells like a campfire. The cans line Ruth's garage shelves.", "options": [{"text": "Good.", "next": "end"}]},
    "shared": {"speaker": "Thaw", "text": "Marisol and Hank build a smokehouse out of a garden shed and a woodstove. Everyone who brought meat gets a share.", "options": [{"text": "Good.", "next": "end"}]},
    "half": {"speaker": "Thaw", "text": "You lose half of it to spoilage, but half is something.", "options": [{"text": "Fine.", "effects": [["flag", "thaw_done"], ["food", 3]], "next": "end"}]},
    "grill": {"speaker": "Thaw", "text": "A block party in a blackout. For one night it's almost a holiday. (Everyone -3 Strain.)", "options": [{"text": "Good.", "next": "end"}]},
    "done": {"speaker": "Thaw", "text": "The freezers stand open and empty in the driveways.", "options": [{"text": "Back.", "next": "end"}]}}}

D["relay_radio"] = {"start": "a", "nodes": {
    "a": {"speaker": "The radio", "route": [{"cond": [["flag", "heard_relay"]], "next": "done"}], "text": "{radio_state}",
          "options": [
              {"text": "Listen to the Evening Net.", "cond": [["any", ["working", "shortwave"], ["working", "handheld_radio"]]],
               "effects": [["flag", "heard_relay"], ["clue", "guard_water"], ["standing", "relay", 5], ["log", "The Relay's Evening Net: no ground bursts anywhere. The Guard has water at Cornell Road. Bald Peak asks for runners."]], "next": "net"},
              {"text": "Put it down.", "next": "end"}]},
    "net": {"speaker": "The Relay, Evening Net", "text":
            "A woman's voice, calm and dry, reading traffic in turn: \"This is net control at Bald Peak. No reports of ground bursts anywhere on this net or the ones we relay. Repeat, no ground bursts. The Talbert Guard is running water at the Cornell Road fire station. Hospitals need runners. Next station.\"\n\n"
            "The war doubt lifts a little. Nobody else on the court knows this yet.",
            "options": [{"text": "Write it down.", "next": "end"}]},
    "done": {"speaker": "The radio", "text": "Static, and then the net again at eight.", "options": [{"text": "Off.", "next": "end"}]}}}

D["day7"] = {"start": "a", "nodes": {
    "a": {"speaker": "Day 7", "route": [{"cond": [["flag", "partner_stays"], ["not_where", "partner", "home"]], "next": "dana_walks"}], "text": "A week. The court is still here.",
          "options": [{"text": "Read the week.", "effects": [["end_act"]], "next": "end"}]},
    "dana_walks": {"speaker": "Day 7", "text": "{partner.name} walks up the court at dusk, exactly when promised, thinner, with a bag of hospital dressings over one shoulder. \"Told you.\"",
                   "options": [{"text": "Read the week.", "effects": [["where", "partner", "home"], ["end_act"]], "next": "end"}]}}}
