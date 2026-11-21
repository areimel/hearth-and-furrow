# CLAUDE.md

Guidance for Claude Code (and any contributor) in this repository.

## Project

**Hearth & Furrow**: a cozy Tudor (c.1530) farming and crafting sim in Godot 4.6, GDScript, Forward+.
Viewport 320x180 scaled x4 (integer scaling), 16px tiles, nearest filtering. Main scene
`scenes/ui/title_screen.tscn`, which starts `scenes/levels/level.tscn`. The MVP thin slice is
complete (`docs/mvp-roadmap.md`). It was built on the MIT-licensed "Godot Valley" course project;
the player, house and fishing UI are still course art. Scope comes from the PRD
(`Hearth and Furrow_ Product Requirements ...md`); API detail is in `docs/contracts.md`.

## Commands

Godot is not on `PATH`. The binary here is `~/.local/share/godot/4.6/godot` (`GODOT=` overrides it in
`tools/check.sh`). Below, `godot` means that path.

```bash
godot --path . --editor                       # editor
godot --path .                                # run the game
godot --path . --headless --import            # rebuild the import cache (run it TWICE after moves/deletes)
tools/check.sh --quick                        # import, parse-check all scripts, 300-line limit, unit tests
tools/check.sh                                # + smoke runs (title screen, then level) of 300 frames
tools/check.sh --full                         # + 112-day year simulation; must print OK before a commit
godot --path . --headless res://tests/test_runner.tscn   # unit tests only (runs every tests/test_*.gd; no per-file filter)
godot --path . --headless --script res://tools/bake_village.gd   # regenerate scenes/world/village.tscn
godot --path . --headless --script res://tools/build_theme.gd    # regenerate scenes/ui/game_theme.tres
tools/make_placeholder_art.sh                 # regenerate graphics/placeholder/ (ImageMagick `convert`)
godot --path . res://tools/art/list_pending.tscn   # list placeholder textures and Content.validate() problems
godot --path . res://tools/screenshot.tscn -- --out /tmp/shots --scene res://scenes/levels/level.tscn --frames 90 --name farm
tools/wire_scene.py scenes/levels/level.tscn Name=res://scenes/world/x.tscn@.   # instance a scene without the editor
```

- `screenshot.tscn` needs a display. The default scene is the title screen, so pass `--scene` for the
  level. `--setup` takes comma-separated steps (`rain`, `storm`, `night`, `winter`, `plants`, `risks`,
  `menu`, `days:N` ...; see the header of `tools/screenshot.gd`). It writes the raw 320x180 PNG and a
  x4 copy; read the `_x4` file to look at it.
- **`godot --check-only --script` does NOT work** for scripts that touch autoloads (they are skipped).
  Use `tools/check.sh`: its parse-check loads every script inside the running project.
- Export presets exist (`Windows Desktop`, `Web`); exports go to the gitignored `exports/`.

## Layout

- `scripts/` by role: `autoload/` (services), `world/` (Level and its feature roots, grid, crops,
  day cycle, build mode), `actors/` (player, NPC, animals), `objects/` (placeables, crops, trees),
  `components/`, `ui/` (+ `ui/kit/` shared widgets, `ui/tabs/` menu tabs), `global/` (the enum
  class `G`), `vfx/`. `scenes/` mirrors it; scripts are not stored next to their scenes.
- `data/*.gd`: const tables, the only place content lives (items, crops, recipes, stations, animals,
  gatherables, NPCs, shops, quests, festivals, dialogue, tool tiers, audio, `Balance`).
  `resources/*.gd`: typed `Resource` classes. The `Content` autoload builds one from the other and
  validates the lot (`Content.validate()`, run by the tests).
- `tests/` (`test_*.gd` extending `TestCase`, run by `test_runner.tscn`), `tools/` (check, sims,
  generators, `village/` source for the baked village), `docs/` (contracts, roadmap),
  `graphics/placeholder/` (generated art), `ASSET_LICENSES.md` (the asset ledger).

## Architecture

**Autoloads** (order in `project.godot`; roles only, signatures in `docs/contracts.md`): `Content`
registry; `SaveManager` save file and providers; `Progress` flags and counters; `GameClock` time and the
day-end signals; `Calendar` derived date; `Weather` today, forecast and storms; `Inventory` slots and
hotbar; `Economy` coins and shop rules; `Relationships` hearts; `QuestManager`; `Settings` (class
`GameSettings`); `GameSession` new, continue and quit; `AudioDirector`. `G` (enums) and `Balance`
(`data/balance.gd`) are global classes, not autoloads: use them directly, never `preload` them.

**Content is data.** Ids are `StringName`s. Add a row to `data/*.gd` (and, for a new kind of thing, a
`resources/` field plus the `ContentBuilder` line) instead of branching on ids in code. One fact lives
in one place. `Content.validate()` enforces cross references and recipe chains.

**Level is the mediator** (`scripts/world/level.gd`). Under it sit `LevelFeature` roots (`FarmGrid`,
`Livestock`, `Workstations`, `Foraging`, `RiskSystem`, `PlayerState`) that own a save section via
`save_key`; `Level._ready()` starts them in tree order. Other children: `Villagers`, `Shops`,
`QuestGiver`, `FestivalDirector`, `BuildMode`, `DayCycle`, `Sky`, `TreeGrove` and the HUD and menus.
Add a feature by instancing its scene under Level (`tools/wire_scene.py`) and, if it saves, extending
`LevelFeature`.

**FarmGrid is the single authority on tiles**: terrain, tilled and wet soil, occupancy, village ground,
`is_tool_valid`, `is_buildable`. Do not test tiles anywhere else.

**Tool flow**: `Player` handles `action` (interact with the nearest `Interactable` first, else the
selected hotbar item) -> emits `do_action` -> `Level._on_player_do_action` plays the tool animation only if
`FarmGrid.is_tool_valid` holds on some targeted cell -> an animation method track calls
`Player.tool_use_emit()` -> `tool_use` -> `Level._on_player_tool_use` applies the effect to every cell of
`ToolArea.cells(...)` (axe: `hit()` on `Axe_able` nodes in front). Seeds use the pseudo action
`PlayerActions.SOW`. Build mode takes over the button through `Player.action_override`.

**Interaction**: anything usable is an `Interactable` (`Area2D`); keep its `prompt_text` current and
disable it rather than blanking it. NPCs talk by default; extra dialogue options come from
`Villagers.register_option`. **Items given or charged go through `Loot`** (`give`, `take`, `missing`,
`deliver`), which also records `Progress`, toasts and handles a full pack.

**UI kit**: screens extend `UIScreen` (`open`/`close`, closes on `ui_cancel`/`menu`, pauses time unless the
setting is off). List screens are `ListDetail` + `DetailPane`; tabs are `TabStrip`; menu tabs extend
`MenuTab` and are listed in `GameMenu.TABS`. The theme (`game_theme.tres`, regenerated by
`tools/build_theme.gd` from `UIPalette`) is the only source of fonts and colours: **use theme type
variations (`HeaderLabel`, `WarnLabel`, ...); never set colours, fonts or sizes in scripts.** Key hints
use `InputGlyphs`.

**Day end**: bed or 02:00 pass-out -> `DayCycle.end_day` (transition) -> `GameClock.advance_day()`:
`day_ending` (resolve the old day), clock to 6:00, Calendar, Weather, Relationships, `day_passed`,
`SaveManager.autosave()`. Listeners of one signal must not depend on each other. Details and the
order are in `docs/contracts.md` section 8.

**Save contract**: each stateful service or feature has `to_dict`/`from_dict`/`reset` and registers
under a key; `from_dict({})` must work and ids and plain values only are stored. Changing a section's
shape means bumping `SAVE_VERSION` and adding a migration. One slot, `user://save_1.json` with `.bak`.

## Conventions

- Typed GDScript, **tabs**, doc comment on public members, one class per file with `class_name` when
  it is referenced elsewhere. **Scripts stay under 300 lines** (`check.sh` reports `OVER:`).
- Rule of three: extract a shared component when something repeats a third time; do not merge things
  that only look alike.
- Tests extend `TestCase` (`check`, `eq`, `near`), are named `test_*`, and reset state in `before_each`
  (`SaveManager.new_game()`). Any `ERROR` line in a test log fails the gate.
- Every script and asset has a sibling `.uid` / `.import`; they travel with the file. Prefer moving files in
  the editor, or move both and run `--import` twice.
- `.tscn` files are large (`level.tscn` is about 2.9k lines, mostly tiles): grep for the node or
  connection you need; never read them whole.
- Commit in small steps with imperative subjects (`feat:`, `fix:`, `docs:`, `chore:`); run
  `tools/check.sh --full` first.

## Gotchas

- **Never push.** `origin` is the upstream course repo (`RezaTaheri01/godot-valley`). Work on branches
  and worktrees; do not touch `main`.
- After moving or deleting files, the first `--import` prints stale-cache errors. Run it twice.
- `await` inside a node that a test frees leads to "resumed after instance is gone": use deferred calls
  or an `is_instance_valid` guard.
- A level booted directly (tests, tools, `--scene`) has `GameSession.in_game == false`: unprompted
  dialogue and the "Saved" toast stay quiet and autosave stays off.
- Tests must use the level's own feature nodes (`level.get_node("Livestock")`, `Workstations`, ...).
  Adding a second copy registers a second provider under the same save key.
- Physics nudges positions by sub-pixels: compare with a tolerance (`near`), not `==`.
- Editing a `.tscn` by hand: add an `ext_resource` and a `[node ...]` block (see
  `tools/wire_scene.py`, which is idempotent). Prefer the script for instancing.
- `scenes/world/village.tscn` and `resources/village_tileset.tres` are **generated** by
  `tools/bake_village.gd` from `tools/village/*`. Edit those and re-bake; a re-bake overwrites editor edits.
- Time is paused behind open screens only while `pause_in_menus` is on; the clock never runs until the
  Level calls `GameClock.start()`.
- The `day_change` action (Tab) only works in debug builds.
- `tests/test_village.gd` parses the `| Places` row of `docs/contracts.md` (one backticked id per place). Keep that row's format when editing the doc.
- `tools/make_placeholder_art.sh` is the only writer of `graphics/placeholder/`; never hand-edit those PNGs.
  The `Ninja Adventure` asset folder is addressed with built path strings (`data/paths.gd`): do not prune
  it by grepping for file names.

## Licensing and IP rules

- Every shipped asset needs a row in `ASSET_LICENSES.md` in the same commit that adds it. Prefer CC0,
  then CC-BY, and keep the licence text beside the pack.
- **No Mana Seed** assets: its licence forbids AI-assisted projects. **Nothing new from Sprout Lands**
  (non-commercial; only its water tiles remain, to be replaced). Do not derive art from either.
- Keep the `LICENSE` attribution to Reza Taheri intact.
- IP rule: the game is "inspired by Tudor farm life". Never name any TV series, broadcaster or
  presenter in code, data, docs, commits or art.
- Anything not confirmed from the repo goes in the ledger as unverified, not as fact.
