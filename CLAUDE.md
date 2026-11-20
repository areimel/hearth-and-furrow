# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project

A Godot 4.6 (GDScript, Forward+ renderer) top-down farming sim built from Kristian Koch's "Godot Valley" course and then extended. The Godot project name is `StardewValley`; the main scene is `scenes/levels/level.tscn`. Viewport is 1280x720 with nearest-neighbour texture filtering (pixel art, 16px tiles).

## Commands

There is no build step, test suite, or linter. Everything runs through the Godot editor/binary (4.6+), which is not on `PATH` on this machine — ask for its location if you need to run it.

```bash
godot --path . --editor            # open the editor
godot --path .                     # run the game (main scene)
godot --path . --headless --import # re-import assets / regenerate .godot cache
godot --path . --headless --check-only --script res://scripts/level.gd   # parse-check one script
godot --path . --headless --export-release "Windows Desktop"             # presets: "Windows Desktop", "Web"
```

Exports go to `exports/` (gitignored).

## Layout quirks

- **Live code is under `scripts/`**, mirrored by scene in `scenes/` (`scenes/ui/shop_ui.tscn` ↔ `scripts/ui/shop_ui.gd`). Scripts are not kept next to their scenes.
- **Stale duplicates — do not edit:** `global/data.gd`, `global/enums.gd`, root `mouse.gd`, and `scenes/characters/player.gd` are leftovers. Nothing references them; the autoloads point at `scripts/global/`.
- `*.tscn<digits>.tmp` files in `scenes/` are editor crash leftovers that happen to be tracked. Ignore them.
- `premade/` holds course-supplied starter snippets/resources, not live code.
- Every script/asset has a sibling `.uid` / `.import` file. Keep them together when moving or renaming, and prefer doing moves in the editor so `uid://` references in `.tscn` files stay valid.
- `.tscn` files are large (`level.tscn` ≈ 2.8k lines, mostly tile data). Grep for the node/connection you need rather than reading them whole.
- The README's TODO list marks Save/Load and In-Game Menu as done via upstream PRs; neither exists in this checkout.

## Architecture

### Autoloads (`project.godot`)

- `Enum` (`scripts/global/enums.gd`) — every enum: `Tool`, `Seed`, `Item`, `Machine`, `State`, `Style`, `Shop`, `Fish`, `KEYBOARD`.
- `Data` (`scripts/global/data.gd`) — the single source of both **static config** (plant/fish/machine/style tables, costs, texture preloads, balance constants like `PLAYER_SPEED`, `BLOB_*`) and **mutable game state** (`ITEMS_AMOUNT` inventory, `unlocked_styles`, `unlocked_machines`, `FORECAST_RAIN`, `TARGET_HIGHLIGHTER`, `ControllerConnected`).

Almost every `Data` table is a dictionary keyed by an `Enum` value. Adding an enum member means adding a matching entry to each table that is indexed by it (e.g. a new `Machine` needs `MACHINE_SCENE`, `MACHINE_PREVIEW_TEXTURES`, `MACHINE_TEXTURES`, `MACHINE_UPGRADE_COST`), otherwise lookups fail at runtime. Enum order is load-bearing: values are cycled with `posmod(current + 1, count)` and stored as ints.

`Data.shop_connection[shop]['tracker']` holds a *reference* to `unlocked_styles` / `unlocked_machines`; buying an item appends to the tracker, which is what unlocks it for the player. An item is "for sale" when it is in `'all'` but not in the tracker.

### Level as mediator

`scripts/level.gd` (root of `level.tscn`) owns the world and is the hub for nearly all gameplay. The player never touches the world directly — it emits signals (`tool_use`, `do_action`, `build`, `change_machine`, `day_change`, `diagnose`, `close_shop`) that are connected to `Level` in the scene file.

Tool flow: player presses `action` → `do_action` → `Level.is_tool_valid()` (the single authority on whether a tool can be used on a tile) → fires the tool one-shot animation → an animation method track calls `Player.tool_use_emit()` → `tool_use` → `Level._on_player_tool_use()` applies the effect.

World state lives in TileMapLayers under `Layers/` rather than in script data:
- `WaterGrassLayer` — terrain, with tile custom data `water` and `farmable`.
- `SoilLayer` — hoed tiles; `WetSoilLayer` — watered tiles (cleared each day).
- `TargetLayer` — the green/red target highlight.

`Level` additionally tracks `planted_cells` and `machine_cells` (grid coords) to block overlapping placement. Grid coords are `floor(pos / Data.TILE_SIZE)`; the targeted cell is the player's cell plus `animation_direction`.

### Day cycle

`Timers/DayTimer` (120s) drives the `CanvasModulate` colour and music volume in `Level._process`. A day ends only when the player triggers it (`day_change` input or the bed) → `day_restart()` runs the shader transition → `level_reset()`: each plant grows if its cell is in `WetSoilLayer` or decays otherwise, wet soil is cleared, trees regrow apples, and `raining` takes yesterday's `Data.FORECAST_RAIN` (rain waters all soil). The TV in the house displays the forecast.

### Player state machine

`scripts/characters/player.gd` switches input handling on `current_state` (`Enum.State`: `DEFAULT`, `FISHING`, `BUILDING`, `SHOP`, `HOUSE`). Other nodes set this state from outside: `house.gd` on entering/leaving the house area, `Level.open_shop()`, and the fishing minigame. Animation is an `AnimationTree` with a movement state machine plus a tool state machine fired through a OneShot; movement is locked while a tool animation plays.

### Duck-typed interactions

There are few base classes; behaviour is discovered by method name or group:
- `interact(player)` + a `can_interact` property — anything the player can use with `action` when in range (shop NPCs via `ShopCharacter`, bed, TV).
- `hit(tool, dir)` — anything in group `Axe_able` (trees) or `Sword_able` (blobs). Scarecrow projectiles call `hit(Enum.Tool.SWORD, …)` too.
- `grow(watered, damage)` — plants; blobs call `grow(false, dmg)` to damage them.
- Groups in use: `Player`, `Objects`, `Tree`, `Plants`, `Sword_able`, `Axe_able`, `Enemy`, `ShopCharacters`.

Spawned scenes follow a `setup(...)` convention: the instance positions itself, adds itself to the given parent, and wires its own signals to callables passed in (see `plant.gd`, `machine.gd`).

### Machines

`Machine` (`scripts/machines/machine.gd`) is the base class for sprinkler, fisherman and scarecrow. Subclasses override `setup(grid_coord, level, parent)` to connect their signals to `Level` methods, then call `super`. Each machine connects to `Level.delete_machine` and frees itself when the emitted coord matches its own. `fisherman.gd` only completes setup if a neighbouring tile is water.

### Plants

`PlantResource` (`resources/plant_res.gd`) holds per-plant growth state (`age`, `death_count`) and is populated from `Data.PLANT_DATA`. A `plant.tscn` instance pairs with a `plant_info` UI panel that it frees alongside itself. Harvest happens when any body enters a fully grown plant's area.

### Physics layers

1 Terrain, 2 Player, 3 Objects, 4 Characters, 5 Enemy, 6 Interact, 7 Plant, 8 Machine.

### Input

Gameplay uses custom actions (`left/right/up/down`, `action`, `tool_forward`, `tool_backward`, `seed_forward`, `style_toggle`, `build`, `day_change`, `diagnose`, `highlighter`), each bound to both keyboard and gamepad. The on-screen key hints (`scripts/ui/keyboard_control_hint_ui.gd`, `key_hint.gd`) swap between `Data.KEYBOARD_KEYS` and `Data.KEYBOARD_CONTROLLER` icons based on `Data.ControllerConnected`, and are refreshed through the player's `update_control_ui` signal — emit it whenever the current tool/seed/machine/style/mode changes.
