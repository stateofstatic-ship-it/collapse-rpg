# Slice build cost, first measurement (2026-11-25)

The plan (tech.md, Phase 2) asks for cost per finished minute. This is the first data
point. Read it as a floor for agent-built gray-box work, not for the shipped game.

## Measured (established, from timestamps and file counts)

| Item | Value |
| --- | --- |
| Agent wall-clock, first file to signed builds | about 36 minutes (21:53 to 22:29 UTC) |
| Code | 5,779 lines: core rules 1,938, presentation 2,712, tests 441, content tools 688 |
| Content | 32 dialogues, 4,290 words, 3 fights, 2 tile maps, 5 world-map nodes |
| Art | none new: reused the device-test gray box |
| Compute and tokens | not measured in this session |
| Human review rounds | 0 so far |

## Play length (hypothesis: a bot time model, not a person)

The bot plays 4 personas x 4 seeds and charges 200 words a minute, 4 s a choice,
25 s a booking, 6 s a fight action and 15 s a menu. 16 of 16 runs finished M1 and M2.

| Persona | Family | Act 0 | Day Zero | Act 1 | Total |
| --- | --- | --- | --- | --- | --- |
| talker | 2.5 | 26.0 | 7.3 | 5.6 | 41.5 |
| fighter | 2.5 | 26.5 | 7.5 | 7.4 | 43.9 |
| go kit | 2.5 | 27.3 | 7.5 | 6.4 | 43.7 |
| skeptic | 1.0 | 24.9 | 7.2 | 6.4 | 39.4 |
| Design budget | 5 | 85 | 8 | 52 | 150 |

## What it says

- Cost: about 36 agent minutes for about 40 bot minutes of play, near 1 agent-hour
  per hour of gray-box play. Confidence: low. One sample, the bot's minutes are
  likely short of a real player's, and target art, review and fixes are not in it.
- Both acts are outside the pacing band. Act 1 runs 6 to 7 minutes against 52; Act 0
  runs 25 to 27 against 85. Day Zero is in band. The slice needs about 3.5x its
  Act 0 content and 8x its Act 1 content to reach band, so the cost per finished
  minute will rise as content, not code, becomes the bulk.
- Variance is low: every persona got the same M1 end on every seed (All Home). Either
  M1 is too easy or the bot's route is too fixed; real play will tell.
- The Go Kit persona ends with a running Rig but only 2 of 7 Bedrock, against 5 to 6
  for the talker and fighter: the vehicle competes with the fridge card, as intended.

## Next measurement

Prime's real play report (summary screen, Copy report) gives minutes per segment.
Fitting the bot's time model to that is the plan's mitigation for "bots pass pacing
that people miss".
