# Hearth & Furrow — MVP roadmap

Thin slice of every row in the PRD's MVP column (§4.1). Tick a line when its branch is merged
into `develop`. Verify any merge with `tools/check.sh`.

Rules for contributors (human or agent):
- Only the integrator edits `project.godot`, `scenes/levels/level.tscn`, `scenes/characters/player.tscn`.
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
- [ ] 31. Docs

## Deferred past MVP
Rent, item quality tiers, Guild Rolls, chests, heart-event cutscenes, Dialogue Manager addon,
Steam/GodotSteam, three save slots, replacing the non-commercial Sprout Lands water tiles.
