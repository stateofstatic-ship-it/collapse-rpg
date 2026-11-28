# Stopped Clocks vertical slice (gray box)

Phase 2 of the plan: Act 0 "The Long Autumn" (condensed to 8 weeks), Day Zero, and
Act 1 "Gather" of Stopped Clocks (F4), in Godot 4.7.2 with GL Compatibility, a 0.67
world render scale and a 30 fps cap. Art is the device-test gray box, not target art.

## Play it

- **Android:** install `stopped-clocks-slice.apk` (debug-signed, package
  `com.collapserpg.slice`, installs beside the device-test apps).
- **Linux:** `chmod +x stopped-clocks-slice.x86_64 && ./stopped-clocks-slice.x86_64`.
- Touch: tap once to preview a move or target, tap again to commit. Keyboard: arrows
  or WASD move, Enter confirms; in a fight Tab cycles foes, F/G quick or aimed shot,
  C Call Out, B Take a Breath, Enter ends the turn.
- Camera on the town map and in fights: pinch to zoom, drag one finger to look
  around, twist two fingers to turn the map a quarter turn. With a mouse: wheel
  zooms, drag pans, Q / R (or [ / ]) turn, + / - zoom, Home finds you. The buttons
  on the right do the same. Buildings, trees and cars fade when they hide you,
  a fighter or the tile you picked.
- The game saves after every dialogue and on **Save**. At the end, the summary screen
  shows a report with **Copy report**: paste it back so real play minutes per segment
  can be compared with the bot's estimate.

## What is in it

- Family setup: names, roll, gender, pronouns, heritage preset, the kids' word for
  each adult; hero attributes, two specialties, job and traits.
- Thimbleberry Court is a cul-de-sac: one road in, a turnaround circle, nine
  one-story houses with driveways, cars, lawns, fenced back yards, Douglas firs and
  fall maples. Houses are 3D renders, one image per map turn, with the garage and
  front door facing the street: `pip install bpy`, then
  `python3 tools/render_houses.py [samples] [look ...]` (assets/houses/, Cycles on
  the CPU, about 6 s per image at 32 samples; run `godot --headless --import` after).
  Yard props come from `python3 tools/make_suburb.py` (assets/suburb.png); the
  layout and every door and task spot come from `tools/make_content.py`, which
  fails the build if any spot is blocked or unreachable.
- Act 0 street: each week starts on your street, not in a menu. Walk to places to
  do things: your car (shopping runs), garage (projects, Go Kit), mailbox (the
  news board), bus stop (classes, work, trips out), front door (family, the fridge
  card, end the week, or every activity as one list). An orange "!" marks this
  week's task, and each one teaches a system: week 2 Ruth's phone chain (skill
  checks) and Quan's card (Medicine), week 3 Arlo's practice range (the fight
  screen, cover, aimed shots), week 5 finding your child and the dog in the dark
  after the storm (sight radius), week 6 Teo's shielding bag (sealing gear in the
  garage), week 7 the blackout drill (rally cards), week 8 Inez's radio (the news
  board). Porch visits build trust with each household.
- Act 0 planner: weekly blocks, money and a card limit, lead-time orders, the
  fridge card (Bedrock 7), the Signal Board with checks and a posterior, four set
  scenes (cookout walk, Pump Four, the Blow, the Eve).
- Prep for vehicles: buy the Rig ('90s 4x4) or Old Iron (1968 truck), load it by
  weight, harden it (tarp, battery off, ferrite chokes, inline suppressors with an
  Electronics 50 gate that can backfire, a surge plug that does nothing), Seal the
  Spares in a shielded bag, Power Kit. A tarp gives nothing to small gear inside.
- Day Zero: the flash rolls every device (post-2005 vehicles 95% Dead, all other
  unshielded electronics 75%, Old Iron 10%, panels and sealed gear 5%; survivors are
  Worn), then a dark walk off TV Highway at 2 tiles of sight.
- Act 1: six-hour watches, a world map with foot, bicycle and running-vehicle travel,
  M1 Gather (school, Sorrel House, the West Hills, the hospital), night knocks set by
  Profile, the daily household ledger, M2 the lantern meeting, Day 7.
- Fights: AP, cover, quick and aimed shots, Call Out, Take a Breath, morale, parley,
  and every downed foe resolved as treat or leave.

## Checks

```
godot --headless --path . -s tests/smoke.gd          # core rules
godot --headless --path . -s tests/bot.gd -- --seeds=4   # 4 personas x seeds, pacing model
python3 tools/make_content.py                         # rebuild content JSON and lint dialogue
```
Screenshots: `godot --path . -- --shot=<family|planner|court|tvhwy|worldmap|battle|garage|summary|hub|hub3|hub7|blow|drill|range|board>:<out.png>`.
Weekly task check: `HUB_TEST=1 godot --path . -- --bot --shot=hub:/tmp/h.png` prints `HUBTEST {...}` with every task true.
