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
- The game saves after every dialogue and on **Save**. At the end, the summary screen
  shows a report with **Copy report**: paste it back so real play minutes per segment
  can be compared with the bot's estimate.

## What is in it

- Family setup: names, roll, gender, pronouns, heritage preset, the kids' word for
  each adult; hero attributes, two specialties, job and traits.
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
Screenshots: `godot --path . -- --shot=<family|planner|court|tvhwy|worldmap|battle|garage|summary>:<out.png>`.
