# Hearth & Furrow

A cozy farming and crafting sim inspired by Tudor farm life, around 1530. You take on a
run-down holding on priory land: sow field and garden crops, keep a cow, sheep and hens,
turn the harvest into bread, butter, cheese, ale and linen, sell at the village stalls,
get to know your neighbours and keep the feast days. Nothing here can kill your farm. The
two hazards (storms and blight) are forgiving and can be eased with a little planning.

Built with Godot 4.6 and GDScript. The display is 320x180 pixel art, scaled to 1280x720.

Status: **MVP thin slice** (tag `mvp-0.1`). Every system below is playable end to end, but
the art, sound and balance are first passes. See "Known gaps" and `docs/mvp-roadmap.md`.

## What is in the game

- **Crops**: six crops with two planting rules. Field crops (wheat, barley, peas, beans) are
  rain-fed and never need watering. Garden crops (flax, cabbage) must be watered daily.
  Seasons, weeds and a growth calendar apply.
- **Livestock**: a cow, a sheep and hens. Feed, pet and collect milk, fleece and eggs; more
  animals can be bought (up to four of a kind).
- **Gathering**: hazel coppice, brambles, stone outcrops, clay pits and reed beds regrow on
  a timer; apple trees can be picked or felled with the axe; fishing has a small minigame.
- **Crafting**: four processing chains over 11 stations (threshing floor, quern, bread oven,
  butter churn, cheese press, malting floor, brewing vat, retting tub, distaff, loom,
  workbench). Some jobs finish overnight. Bread, dairy, ale and linen.
- **Build mode**: place and remove crafting stations on the farm, paid for in logs, stone,
  clay and so on; removal refunds part of the cost.
- **Tools**: five tools (axe, hoe, watering can, sickle, fishing rod) in two tiers, wooden and
  iron-shod. The iron-shod tier covers a wider area, fells trees faster and eases fishing.
- **Time**: a clock with a 06:00 start, a 28-day-season calendar, four seasons, weekdays and
  a Saturday market (better prices). You pass out at 02:00 if you stay up.
- **Weather**: clear, rain and storm, with a forecast that is always right and a three-day
  outlook. Rain waters the soil. Storms can flatten ripe grain (wheat and barley; a flattened
  crop can still be salvaged for straw), and in a wet spell blight can threaten a grain crop
  grown on the same plot again and again. A warning gives you time to hoe the crop or reap
  early, rotation avoids it, there is no risk in the first week, and losses are capped.
- **Village**: a walkable village with six villagers on daily schedules (the reeve, chandler,
  blacksmith, alewife, miller and shepherd), friendship hearts, talking and gifts they love
  or dislike.
- **Shops**: five stalls buy and sell, with daily stock, seasonal seeds, tool upgrades,
  animals, station kits and diminishing returns when you sell a lot of one thing.
- **Story**: a prologue and three errands (miller, alewife, chandler) that teach the
  chains, each with a small standing favour once done.
- **Feasts**: May Day (spring 20) and Harvest Home (autumn 7). Bring what the village asks
  for; the better the table, the bigger the reward.
- **Interface**: HUD with clock, date, weather and purse, a hotbar, toasts and contextual
  prompts, and a pause menu with Pack, Journal, Folk, Almanack and Settings tabs. Keyboard
  and gamepad glyphs follow whichever you used last.
- **Saving**: one save slot, autosaved each morning, with a backup file; a title screen
  with Continue and New Game; text size, volume, fullscreen and relaxed-time settings.

## Running it

Requires Godot 4.6 (standard build, GDScript only).

```bash
godot --path . --editor     # open the editor
godot --path .              # run the game (starts at the title screen)
```

If `godot` is not on your `PATH`, give its full path instead. On the development machine it
lives at `~/.local/share/godot/4.6/godot`. The first run after a fresh clone may need
`godot --path . --headless --import` (run it twice) to build the import cache.

## Controls

Keyboard and gamepad (Xbox naming) are both bound in the Input Map; the on-screen hints
switch glyphs to whichever device you touched last.

| Action | Keyboard | Gamepad |
|---|---|---|
| Move | W A S D | Left stick or D-pad |
| Use tool / sow / interact / talk | Space | A |
| Previous / next hotbar item | Q / E | LB / RB |
| Pick hotbar slot | 1 2 3 4 5 6 7 8 9 0 | (use LB / RB) |
| Build mode (menu to place or remove stations) | M | Y |
| Tile highlighter (shows the target tile and crop info) | H | X |
| Pause menu, and close screens | Esc | Start |
| Menu navigate | Arrow keys or W A S D | D-pad or left stick |
| Menu accept | Enter, Numpad Enter or Space | A |
| Menu back | Esc | B |
| Switch tabs (menu, shop) | Q / E | LB / RB |
| Sell a whole stack in a shop | Shift + accept | X + accept |
| Skip to the next day (debug builds only) | Tab | none |

## First ten minutes

The prologue quest ("A Holding of One's Own", from Thomas Ashby the reeve) starts by itself
and walks you through the basics. Its steps, in order:

1. Till the soil with the hoe and sow 4 wheat seed (the seeds are in the hotbar).
2. Sow a cabbage and water it with the can.
3. Sleep in the bed, and see a new day in.
4. Reap a ripe crop with the sickle (crops need several days to ripen; the Almanack lists what can be sown this season).
5. Thresh a wheat sheaf for grain at the threshing floor.
6. Grind grain to flour at the quern.
7. Meet the village: talk to four neighbours.

The reward is 50 coins, barley and flax seed, and the reeve's goodwill; it also unlocks
the three errands. Check the Journal tab for progress and the Almanack for the forecast.

## Verifying changes

There is no editor-only workflow: everything runs headless.

```bash
tools/check.sh --quick   # import, parse-check every script, size check, unit tests
tools/check.sh           # as --quick, plus smoke runs of the title screen and the level
tools/check.sh --full    # as above, plus a scripted 112-day year simulation
```

Each prints `OK` at the end when all stages pass. Set `GODOT=/path/to/godot` to override
the binary. See `CLAUDE.md` for the rest of the tooling.

## Known gaps and deferred features

- **Placeholder art.** Many item, crop, animal and station sprites are generated stand-ins
  (`graphics/placeholder/`, listed in `ASSET_LICENSES.md`). The sheep is a recoloured cow,
  and the sickle reuses the course's sword animation.
- **Placeholder audio.** One music loop plays in every season; sound effects are existing
  tool and step sounds at other pitches. All audio came from the course and has no licence
  record.
- **Not yet hands-on tested** on a real gamepad or the Steam Deck, and nobody has played a
  complete in-game day by hand: it was verified by tests, a scripted 112-day simulation and
  simulated key input.
- **Not buildable yet**: fences, pens, coops and a dairy shelf. Only crafting stations can
  be built.
- **Balance is a first pass.** Targets are encoded in `data/balance.gd` and the year simulation.
- **Deferred**: rent, item quality tiers, guild rolls, chests, heart-event cutscenes, the
  Dialogue Manager addon, Steam/GodotSteam support, three save slots.
- **Licensing blockers for a paid release.** The water tiles come from the Sprout Lands free
  pack, which is non-commercial only and must be replaced. Other course art, audio and fonts
  have no recorded licence. Details in `ASSET_LICENSES.md`.

## Credits and licences

- Code: MIT, see `LICENSE`. This game grew from the **Godot Valley** project by Reza Taheri
  (MIT), itself built from a Godot course; the original copyright notice must stay in
  `LICENSE`. The player sprite, the house tiles and the fishing UI are still course art.
- Main art spine: the Ninja Adventure asset pack by Pixel-boy and AAA (CC0).
- Other assets (Tiny Swords decorations, Sprout Lands water tiles, course graphics, audio
  and the UI font) and their licence status are tracked file by file in `ASSET_LICENSES.md`.

## For contributors

`CLAUDE.md` is the working guide for people and AI sessions: architecture, commands,
conventions and gotchas. `docs/contracts.md` is the API reference and `docs/mvp-roadmap.md`
tracks scope. The original product requirements are in
`Hearth and Furrow_ Product Requirements for a Cozy Tudor Farming Sim in Godot.md`.
