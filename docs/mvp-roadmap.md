# Hearth & Furrow — MVP roadmap

Thin slice of every row in the PRD's MVP column (§4.1). Tick a line when its branch is merged
into `develop`. Verify any merge with `tools/check.sh`.

Rules for contributors (human or agent):
- Only the integrator edits `project.godot`, `scenes/levels/level.tscn`, `scenes/actors/player.tscn`.
- Scripts stay under 300 lines. Something repeated three times becomes a shared component.
- Content is data: add rows to `data/*.gd`, not branches to code.
- Never push: `origin` is the upstream course repo.

## Wave 0 — setup
- [x] 1. Track PRD, agent docs, roadmap
- [x] 2. Headless check + test tooling (`tools/check.sh`, `tests/`)

## Wave 1 — spine
- [x] 3. Remove legacy course content
- [x] 4. 320x180 pixel-perfect display and theme
- [x] 5. Content registry and typed data resources
- [x] 6. Game clock, calendar, day-end pipeline
- [x] 7. Slot inventory, hotbar-driven player, UI kit
- [x] 8. Split level into farm grid, world state, mediator

## Wave 2 — systems
- [x] 9. Six Tudor crops (field/garden rules, weeds)
- [x] 10. Placeholder art + ASSET_LICENSES.md
- [x] 11. Livestock: cow, sheep, chickens
- [x] 12. Gathering nodes and two tool tiers
- [x] 13. Weather, forecast, seasonal palette
- [x] 14. Storm and blight risks with mitigation
- [x] 15. Stations and timed recipes
- [x] 16. Bread, dairy, ale, linen chains
- [x] 17. Coin economy and buy/sell shops
- [x] 18. Village district
- [x] 19. Six villagers with schedules
- [x] 20. Friendship, gifts, dialogue

## Wave 3 — story, UI, persistence
- [x] 21. Quests: prologue + three errands
- [x] 22. May Day and Harvest Home feasts
- [x] 23. HUD
- [x] 24. Pause menu tabs
- [x] 25. Crafting and shop screens
- [x] 26. Save/load, autosave, title menu
- [x] 27. Audio

## Wave 4 — hardening
- [x] 28. Full-year headless simulation
- [x] 29. Review findings fixed
- [x] 30. Balance and controller pass
- [x] 31. Docs

## Deferred past MVP
Rent, item quality tiers, Guild Rolls, chests, heart-event cutscenes, Dialogue Manager addon,
Steam/GodotSteam, three save slots, replacing the non-commercial Sprout Lands water tiles.

## Status at mvp-0.1 (2026-11-20)
All 31 items above are done; `mvp-0.1` names the thin slice. Shipped: six
crops with field and garden rules, a cow, sheep and hens, gathering nodes, four processing chains over
11 stations, build mode, two tool tiers, clock, calendar and seasons, weather with a forecast and two
forgiving risks (storm and blight), a village with six villagers, friendship and gifts, five shops, the
prologue and three errands, two feasts, the HUD and pause menu, and save/load with a title screen.
`README.md` describes the game, `CLAUDE.md` the working rules, `docs/contracts.md` the APIs. Unreferenced
course art and audio were pruned (about 2.8 MB, 48 files plus their import sidecars; see git history). Verification is
`tools/check.sh --full`: unit tests, headless smoke runs and a scripted 112-day year simulation, all green.
It is a first pass: nobody has played a full day by hand, and the art, sound and balance are placeholders
or first guesses.

## Next
Gaps found by the PRD review (MVP column):
- Structures beyond stations: fences, pens, coops and a dairy shelf are not buildable yet.
- Audio: one music loop for all seasons; sound effects are existing sounds at other pitches.

Deferred past MVP (from the list above): rent, item quality tiers, Guild Rolls, chests, heart-event
cutscenes, the Dialogue Manager addon, Steam/GodotSteam, three save slots, and replacing the
non-commercial Sprout Lands water tiles (a blocker for any paid release).

Verification:
- No hands-on gamepad or Steam Deck test yet. Nobody has played a full day by hand: everything was
  verified by tests, the scripted 112-day simulation and simulated key input.

Art and assets:
- Placeholders are listed in `ASSET_LICENSES.md`. The sheep is a recoloured cow and the sickle reuses
  the course's sword animation. Course art, audio and the font have no recorded licence.
- The three asset packs can be thinned, which is the owner's decision: Sprout Lands (41 of 43 files
  unreferenced) and Tiny Swords (392 of 410 files unreferenced). Do not prune Ninja Adventure by file
  name, its paths are built from strings.
- `audio/rain.mp3` has no path reference (the level embeds its own copy of the rain and music streams).

Balance:
- Prices, yields and pacing are a first pass. The targets are encoded in `data/balance.gd` and enforced by
  `tests/test_balance.gd` and `tools/year_sim.gd`; retune against `tools/check.sh --full` after real play.
