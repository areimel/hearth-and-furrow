# Hearth & Furrow — data and service contracts

Read this before building any system. Signatures here are stable: extend, don't change.
If you need a change, add a new method/signal and note it in your PR.

## Conventions
- Ids are `StringName` literals (`&"wheat_sheaf"`). Never use display names as keys.
- Content is data: add rows to `data/*.gd` const tables, never `if id == ...` branches.
  One fact lives in one place (an item's price is only on its item row).
- Shared enums: `G` (`scripts/global/game_enums.gd`): `Season`, `Weekday`, `WeatherKind`,
  `CropKind`, `ToolKind`, `ItemCategory`, `GiftReaction`, `QuestState`, `RAW_CATEGORIES`.
  Only append enum members (values are saved as ints). Do not use legacy `Enum`/`Data`.
- Tuning numbers: `const Balance := preload("res://data/balance.gd")` (slots, stack size,
  day hours, tick speed, weather weights, risk factors, prices bonus, friendship points,
  new-game loadout).
- Typed GDScript, tabs, files under 300 lines, doc comment on every public member.
- Never mutate resources returned by `Content`; keep runtime state in your own service.
- Tests: `tests/test_*.gd` extending `TestCase`; reset state with `SaveManager.new_game()`
  in `before_each()`. Any `ERROR` line in the test log fails `tools/check.sh`, so do
  not exercise unknown-id paths in tests.

## Ids (source of truth: `data/`)
| Kind | Ids |
|---|---|
| Tools (`<tool>_<tier>`) | `axe_`, `hoe_`, `watering_can_`, `sickle_`, `fishing_rod_` × `wooden` / `iron_shod` |
| Seeds | `wheat_seed` `barley_seed` `pea_seed` `bean_seed` `flax_seed` `cabbage_seed` |
| Crop yields | `wheat_sheaf` `barley` `peas` `beans` `flax` `cabbage` |
| Animal products | `milk` `fleece` `egg` |
| Materials | `log` `hazel_rod` `stone` `clay` `reed` |
| Forage / fish | `blackberry` `hazelnut` `apple` / `trout` |
| Intermediates | `grain` `straw` `flour` `malt` `barm` `flax_fibre` `linen_thread` |
| Goods / upgrade | `bread` `butter` `cheese` `ale` `linen` / `linen_sack` (+6 backpack slots) |
| Crops (own namespace) | `wheat` `barley` `peas` `beans` (FIELD) · `flax` `cabbage` (GARDEN) |
| Stations | `threshing_floor` `quern` `bread_oven` `churn` `cheese_press` `malting_floor` `brewing_vat` `retting_tub` `distaff` `loom` `workbench` |
| Recipes | `thresh_wheat` `grind_flour` `bake_bread` `churn_butter` `press_cheese` `malt_barley` `brew_ale` `ret_flax` `spin_thread` `weave_linen` `sew_linen_sack` |
| Animals | `cow` `sheep` `chicken` |
| Tool tiers | `wooden` → `iron_shod` |
| NPCs | `reeve` `chandler` `blacksmith` `alewife` `miller` `shepherd` |
| Quests | `prologue` `errand_miller_wheat` `errand_alewife_barley` `errand_chandler_linen` |
| Festivals | `may_day` (spring 20) `harvest_home` (autumn 7) |
| Places (schedule/feast `location`) | `manor` `village_green` `market_cross` `chandlery` `smithy` `alehouse` `mill` `pasture` `shepherd_hut` |
| Flags | `prologue_done` |

Chains (`data/recipes.gd` `CHAINS`, checked by `Content.validate()`):
bread `wheat_sheaf → thresh_wheat → grain → grind_flour → flour (+barm) → bake_bread → bread`;
dairy `milk → churn_butter → butter`, `milk → press_cheese (overnight) → cheese`;
ale `barley → malt_barley (overnight) → malt → brew_ale (overnight) → ale + barm`;
linen `flax → ret_flax (overnight) → flax_fibre → spin_thread → linen_thread → weave_linen → linen → sew_linen_sack → linen_sack`.

Art: rows store texture *paths*. A missing path under `res://graphics/placeholder/`
(items `<item_id>.png`, crops `crop_<id>.png`, animals `animal_<id>.png`, stations
`<station_id>.png`) is expected until generated; Content shows a magenta 16×16 stand-in
and lists it in `pending_placeholders()`. Any other missing path is a `validate()` error.

## Resources (`resources/*.gd`, built by Content; fields documented in each file)
`ItemData` (`is_tool() is_seed() is_giftable() is_sellable()`), `CropData` (`grows_in(season)`,
`frame_for_age(age)`), `RecipeData`, `StationData`, `AnimalData`, `NPCData`
(`reaction_to(item)`, `location_at(hour, weekday, season, raining)`), `NPCScheduleEntry`,
`QuestData`, `QuestCondition` (kinds `have_item deliver_item flag counter talk_to hearts`),
`QuestReward` (kinds `coins item flag friendship`), `FestivalData`, `ToolTierData`.

## Autoloads (load order = this order; `Enum`/`Data` legacy come first)
**Content** — read-only registry. Unknown id → `push_error` once, returns `null`.
- `item(id) -> ItemData`, `has_item(id)`, `items()`, `items_with_tag(tag)`, `items_in_category(cat)`
- `tool_item(kind: G.ToolKind, tier) -> ItemData`, `tool_tier(id)`, `tool_tiers()` (by rank), `tool_kinds()`
- `crop(id)`, `crops()`, `crop_for_seed(item_id)` (null quietly for non-seeds)
- `recipe(id)`, `recipes()`, `recipes_for_station(id)`, `recipes_producing(item)`, `recipes_using(item)`
- `station(id)`, `stations()`, `animal(id)`, `has_animal(id)`, `animals()`, `npc(id)`, `npcs()`
- `quest(id)`, `quests()`, `festival(id)`, `festivals()`, `festival_on(season, day)` (null quietly)
- `validate() -> Array[String]`, `pending_placeholders()`, `chains()`, `placeholder_texture()`

**SaveManager** — `SAVE_VERSION`, `save_path` (default `user://save_1.json`), `autosave_enabled` (false).
- `register(key, provider)`, `unregister(key)`, `is_registered(key)`
- `save_game() -> Error`, `load_game() -> Error`, `autosave() -> Error` (no-op unless enabled)
- `has_save()`, `delete_save() -> Error`, `new_game()` (calls every provider's `reset()`)
- signals `saved(path)`, `loaded(path)`, `new_game_started`

**Progress** (save key `progress`) — story flags + counters, shared by quests/recipes/tiers.
- `set_flag(f)`, `clear_flag(f)`, `has_flag(f)` (empty flag → true), `flags()`
- `add_count(key, n) -> int`, `count(key)`, `record(verb, id, n)` → key `"<verb>.<id>"`;
  verbs: `crafted harvested gathered caught sold bought gifted`. Systems MUST record these.
- signals `flag_set(f)`, `flag_cleared(f)`, `counter_changed(key, value)`

**GameClock** (save key `clock`) — inert until `start()`. Fields `day_index hour minute time_scale running paused`.
- `start()`, `stop()`, `set_paused(b)`, `is_ticking()`, `advance_minutes(n)`, `advance_day()`
- `total_minutes()`, `day_progress()` (0 at 6:00 → 1 at 24:00), `time_string()` ("13:40")
- signals `minute_passed(hour, minute)` (every 10-min tick), `hour_passed(hour)`, `day_ending(day)`,
  `day_passed(day)`, `passed_out` (at 26:00, clock stopped), `running_changed(b)`

**Calendar** (no state; derived from `GameClock.day_index`; `day = -1` means today)
- `season(day)`, `day_of_season(day)` (1..28), `year(day)` (1-based), `weekday(day)`, `today()`
- `is_market_day(day)` (Saturday), `festival_today(day) -> FestivalData`, `day_index_for(year, season, dos)`
- `season_name(s)`, `weekday_name(w)`, `date_string(day)`; `begin_day(day)` (GameClock only)
- signals `season_changed(season)`, `year_changed(year)`, `festival_day(festival)`

**Weather** (save key `weather`) — `today`, `forecast` (G.WeatherKind), `world_seed`. Forecast is always right.
- `is_raining()` (rain or storm), `is_stormy()`, `roll_next_day() -> int`, `roll_for_day(day) -> int`
- `set_today(kind)`, `set_forecast(kind)`; `begin_day(day)` (GameClock only)
- signal `weather_changed(today, forecast)`

**Inventory** (save key `inventory`) — flat slots; `0..9` hotbar, `10..` backpack (24, +6 per sack, max 36).
- `size()`, `is_hotbar_slot(i)`, `slot_id(i)`, `slot_count(i)`, `slot_item(i)`, `is_slot_empty(i)`
- `count(id)`, `has(id, n)`, `space_for(id)`, `can_add(id, n)`
- `add(id, n) -> int` leftover, `remove(id, n) -> bool` (all-or-nothing), `remove_at(i, n) -> int`
- `move(from, to)` (merge else swap), `swap(a, b)`, `split(i) -> int` new index or -1
- `selected_hotbar_index`, `select_hotbar(i)`, `cycle_hotbar(step)`, `selected_id()`, `selected_item()`
- `expand_backpack(n) -> int`, `use_capacity_item(i) -> bool`, `reset()` (new-game loadout)
- signals `changed`, `slot_changed(i)`, `hotbar_selection_changed(i)`, `item_added(id, n)`,
  `item_removed(id, n)`, `capacity_changed(backpack_capacity)`

**Economy** (save key `economy`) — `coins`.
- `add_coins(n)`, `spend(n) -> bool`, `can_afford(n)`
- `price_of(id)` (item or animal row), `buy_price(id)`, `sell_price(id)`, `sell_multiplier()` ← market-day hook
- `buy(id, n) -> bool` (coins → Inventory), `sell(id, n) -> int` coins earned (records `sold.<id>`)
- signals `coins_changed(coins, delta)`, `item_bought(id, n, coins)`, `item_sold(id, n, coins)`
- Shops (`data/shops.gd` → `ShopData`; `Content.shop(id)`, `Content.shops()`): wares are
  `item` / `animal:<id>` / `tool_upgrade:<ToolKind>` / `station:<id>` (a kit of build materials),
  with optional price, daily `stock`, `seasons`, `sowable`, `unlock`, `requires` (paid conversion).
  Buy rules (`cats`/`tags`/`ids` + `factor`) say what the keeper pays for.
  Ware ids default to `<kind>:<target>` (e.g. `item:wheat_seed`, `tool_upgrade:1`).
- `shop_buy_price(shop, entry)`, `shop_sell_price(shop, item_id)` (base x factor x market-day),
  `shop_stock_left(shop, entry)` (-1 unlimited), `shop_block_reason(shop, entry) -> String`,
  `shop_buy(shop_id, entry_id) -> String` ("" = bought, else the refusal; all-or-nothing),
  `shop_sell(shop_id, item_id, n) -> int`. Stock sold per day is saved under `economy`
  (`sold_today`) and restocks in `GameClock.day_ending`. Goods logic lives in `ShopDeals`.

**Relationships** (save key `relationships`) — points 0..1000, hearts = points/100.
- `points(npc)`, `hearts(npc)`, `add_points(npc, n)`, `talk(npc) -> bool` (first today: +20)
- `talked_today(npc)`, `has_met(npc)`, `gifted_today(npc)`
- `gift(npc, item) -> G.GiftReaction` (removes the item from Inventory unless ALREADY_GIFTED/NOT_GIFTABLE)
- `begin_day(day)` (GameClock only); signals `points_changed`, `hearts_changed`, `talked`, `gifted(npc, item, reaction)`

**QuestManager** (save key `quests`)
- `state(id) -> G.QuestState`, `is_active(id)`, `is_complete(id)`, `active_quests()`, `can_start(id)`
- `start(id) -> bool`, `condition_progress(id, index) -> int`, `is_ready(id)`, `complete(id) -> bool`
  (consumes `deliver_item`s, grants rewards), `refresh()` (auto on Inventory/Progress/Relationships change)
- signals `quest_started(id)`, `objective_progress(id, index, current, required)`, `quest_ready(id)`, `quest_completed(id)`

## Shops UI and feature root
- `ShopScreen` (`scenes/ui/shop_screen.tscn`, group `ShopScreen`, extends `UIScreen`):
  `open_for(shop_id) -> bool`, `show_tab(ShopScreen.Tab.BUY | SELL)`. Q/E (`tool_backward` /
  `tool_forward`, shoulder buttons) switch tabs; accept buys/sells one; Shift (pad X) + accept
  sells the stack; cancel closes.
- `Shops` (`scenes/world/shops.tscn`, add as a child of Level): `open(shop_id) -> bool`,
  `is_open_today()` (festival `shops_closed`). On ready it calls `Villagers.register_option(
  keeper, "Trade", open.bind(shop_id), is_open_today)` for every shop if a `Villagers` node
  (group `Villagers`) exists (retried once a frame later), else does nothing.
- Kit additions: `ItemRow`, `ScreenLocator.find_or_create(tree, group, scene, fallback_parent)`,
  `ListMenu.set_entry_greyed(i, bool)`, `UIScreen.build_modal(width) -> PanelFrame`.

## Day-end order (`GameClock.advance_day()` is the only way a day ends)
Whoever ends the day (bed, `passed_out` handler, debug key) plays its transition, then calls
`GameClock.advance_day()`, which runs synchronously:
1. `day_ending(old_day)` — resolve the finished day using *today's* state, which is still
   current: `Weather.today`, watered tiles, `Calendar.season()`. Listeners must be
   independent of one another (no ordering among them is guaranteed):
   farm grid (grow/pause crops, weeds, storm/blight if `Weather.is_stormy()`, then clear
   watering), stations (finish `overnight` jobs and jobs whose minutes elapsed), livestock
   (produce if fed), shops (restock).
2. Clock moves to `old_day + 1`, 6:00.
3. `Calendar.begin_day()` → `season_changed` / `year_changed` / `festival_day`.
4. `Weather.begin_day()` → `today = forecast`, new forecast, `weather_changed`.
5. `Relationships.begin_day()` → daily talk/gift limits reset.
6. `day_passed(new_day)` — set up the new morning: farm waters all soil if
   `Weather.is_raining()`, NPCs pick schedule entries, HUD refreshes, festival setup.
7. `SaveManager.autosave()` — last, so the save holds the fully rolled-over morning.
Never call `advance_day()` from inside a `day_ending`/`day_passed` handler.

## Save contract
- Every stateful service implements `to_dict() -> Dictionary`, `from_dict(data)`, `reset()`
  and calls `SaveManager.register(&"<key>", self)` in `_ready()`. Scene-owned state (farm
  grid, placed stations, animals) registers when its scene loads and unregisters on exit.
- `from_dict` must accept `{}` and missing keys (use defaults); it must not start the clock.
- Store ids and plain values only, never node/resource references. `Vector2i`, `StringName`,
  ints and typed arrays survive exactly (`JSON.from_native`); still cast with `int()` defensively.
- File: `{"save_version", "saved_at", "sections": {key: dict}}`. Missing section → `reset()`.
  Changing a section's shape: bump `SAVE_VERSION` and add a `match` case in `_migrate()`.

## World services (scene-owned; additions by the core-loop branch)
- The legacy `Enum`/`Data` autoloads are gone: tile size, player speed and tree health live in `Balance`.
- **Level** (group `Level`): `farm_grid`, `player`, `day_cycle`, `sky`, `crops() animals() stations() npcs() gatherables()`,
  `target_cell()`, `can_place_at_target()`, `place_at_target(scene) -> Placeable`,
  `show_placement_preview(texture)`, `hide_placement_preview()`.
- **DayCycle** (group `DayCycle`): `end_day(passed_out := false)` (the only entry for bed/pass-out), `busy`,
  `DayCycle.is_transitioning(tree)`, signals `transition_started`, `transition_finished`.
- **WorldSky**: `base_tint(progress) -> Color` is the hook for seasonal palettes; `is_raining()`.
- **FarmGrid** (save key `farm`: `tilled`, `wet`, `crops`): `is_tool_valid(action, cell)` where action is a
  `G.ToolKind` or `PlayerActions.SOW`; `crop_field: CropField`.
- **CropField**: `sow(cell, crop_id) -> Crop`, `crop_at(cell)`, `crops()`, `ripe_crops()`, `reap(cell) -> int`,
  `remove(cell)`, `resolve_day()`. **Crop**: `crop_id age weeds blighted is_ripe() is_flattened() flatten()
  clear_weeds() yield_amount() info_text() to_dict() from_dict()`.
- **Loot.give(tree, item_id, amount, verb) -> int**: Inventory + Progress + toast ("Pack is full" on overflow).
- **Player**: `input_locked`, `highlighter_on`, `action_item`, signal `interact_focus_changed(Interactable)`.
  An Interactable's prompt text is metadata `prompt_text` on it or its parent (default "Use").
## Gathering nodes (feature `foraging`)
Rows in `data/gatherables.gd` (`hazel bramble stone clay reeds`) -> `GatherableData`
(`yields_for(season, day_of_season)`, `needs_tool()`); `Content.gatherable(id)`, `gatherables()`.
Yield rows: `{item, min, max, seasons?, from_day?}`; optional `tool` (G.ToolKind, default none) makes the
prompt read "Needs an axe" until a matching tool is in the pack.
- `Gatherable` (`scenes/objects/gatherable.tscn`, extends `Placeable`, claims its FarmGrid cell):
  `Gatherable.create(id)` then `setup(cell, level, level.gatherables())`; `gather() -> bool`,
  `is_ripe()`, `roll_yields()`, `prompt_text()`, `to_dict()/from_dict()`. Gathering delivers to
  Inventory (leftover stays in `pending`), calls `Progress.record(&"gathered", item, n)`, depletes,
  and regrows after `regrow_days` `GameClock.day_ending`s. Prompt is meta `prompt_text` on its Interactable.
- `Foraging` (`scenes/world/foraging.tscn`): instance as a child of `Level`. Spawns into
  `level.gatherables()`, scatters (seeded from `Weather.world_seed`, fallback 1530) two frames after
  ready, registers save key `foraging`. API: `nodes()`, `count_ready(id)`, `node_at(cell)`,
  `place(id, cell)`, `scatter(id, count, rng)`, `scatter_area(marker, rng)`.
- Extra spawn areas: a `Marker2D` in group `ForageArea` with metadata `gatherable_id`, `count` and
  optional `radius` (pixels, default 48) gets that many nodes on a new game.
- Placement rules (`place` in the row): `any_grass`, `near_water` (orthogonally next to water).

## Tool tiers, trees and building
- **Tier rows** (`data/tool_tiers.gd`, `ToolTierData`): `area` (cells per swing, only for `ToolTiers.AREA_KINDS`: hoe, can, sickle),
  `power` (axe damage per hit against `Balance.APPLE_TREE_HEALTH`), `bonus_logs`, `fishing_ease`. `PlayerActions.tier_of(item) -> ToolTierData`
  (null for non-tools). `ToolArea.cells(action, tier, origin, step) -> Array[Vector2i]`: the cells a swing covers; each is validated on its own
  with `FarmGrid.is_tool_valid`, invalid ones are skipped. `FarmGrid.update_highlight(pos, dir, action, tier := null)` shows all of them.
  `is_tool_valid` is now false for any cell holding a `Placeable`.
- **Axe_able** `hit(action, dir, tier: ToolTierData = null)`. **AppleTree** (`scripts/objects/tree.gd`): `health felled stump_days`, `hit()`, `fell(bonus_logs)`,
  `regrow()`, `apple_count()`, `AppleTree.hits_to_fell(tier)`, `to_dict()/from_dict()`. Felling gives `Balance.TREE_LOGS + tier.bonus_logs` logs
  (`Loot`, verb `gathered`); the stump regrows after `Balance.TREE_REGROW_DAYS` evenings (`GameClock.day_ending`); apples regrow only in
  `Balance.APPLE_SEASONS`. **TreeGrove** (script of `Objects/Trees`) is the one `trees` save provider (`{"trees": {node name: state}}`).
- **Fishing**: `Player.start_fishing(ease_factor := 1.0)` multiplies the minigame's catch speed and divides its lose speed.
- **Building**: `FarmGrid.is_buildable(cell)` (free, dry, outside the house, untilled, unoccupied) is what `Level.can_place_at_target()` and
  `Workstations.build()` check. `Workstations.can_remove(cell)` (exists, no job, no output) and `refund_of(station_id) -> Dictionary`
  (`Balance.BUILD_REFUND_SHARE` of each cost item, rounded down). New games start with only `Balance.STARTER_STATIONS`.
- **BuildMode** (`Level.build_mode`, `Level.is_building()`): `Mode {OFF, PLACE, REMOVE}`, `start_placing(id)`, `start_removing()`, `exit()`, `perform()`,
  `target_valid()`, signal `mode_changed`. The `build` action opens **BuildMenu** (group `BuildMenu`, `open_menu()`, signals `station_chosen(id)`,
  `remove_chosen`); `build` / `ui_cancel` leave build mode. While active `Player.action_override` (a Callable) takes the `action` button; any
  future mode can use the same hook. `Level.show_placement_preview(texture, tint := PREVIEW_TINT)`; `FarmGrid.highlight_cell(cell, valid)`.
  Refunds go through `Loot.give(..., &"refunded")`.

## Weather and crop risks (feat/weather-risks)
- **Weather** additions: `outlook(days := 3) -> Array[int]` (true kinds, tomorrow first), `outlook_text() -> String`,
  `is_wet_spell() -> bool` (rain/storm on 3 of the last 4 days, today included; history saved under `past`),
  signal `storm_warning(day)` (emitted by `begin_day` when tomorrow is a storm, and by `set_forecast(STORM)`).
  `roll_for_day` never yields a storm before day 3 or on the day after a raw storm roll.
- **WorldSky**: `base_tint` multiplies the day gradient by the eased seasonal tint (`Balance.SEASON_TINTS`); storms add
  darkness, lightning and slanted rain; `WorldSky.sway_material` is the shared crop sway shader material.
- **RiskSystem** (`scenes/world/risk_system.tscn`, add as a child of Level; save key `risks`): `recent_losses() -> int`
  (crops lost in the last 7 days), `advice() -> String` (reeve hint), `previous_crop(cell) -> StringName`,
  `is_risk_free() -> bool`. Order independence: the storm acts in `day_ending` on a snapshot of crops ripe at dawn
  (taken on `weather_changed`), so growth order is irrelevant; blight acts on `day_passed` (morning, after growth):
  a spotted crop (`Crop.blight_warning`) turns blighted next morning unless hoed. A warned crop also gets one weed so the
  existing hoe check (`weeds > 0`) accepts it; `Crop.clear_weeds()` cures the warning.
- **CropField**: signal `crop_reaped(cell, crop_id)` feeds the rotation memory. **Crop**: `blight_warning`.

## Save/load, title and session (roadmap 26)
- **SaveManager additions**: `snapshot() -> Dictionary` (every provider's `to_dict()`), `peek_summary() -> {day_index, date, saved_at}`
  (cheap look for the title; `{}` if unreadable), `migrate(data, target := SAVE_VERSION)` + `migrations: Dictionary[int, Callable]`
  (step `v` upgrades version v to v+1), `backup_path()`, `pending_keys()`, `discard_pending()`, `last_message`,
  `restored_from_backup`, signal `backup_restored`. `has_save()` is true if the file or its `.bak` exists.
- **Writes** go to `<path>.tmp` then rename; the previous valid save is copied to `<path>.bak`. A damaged main file (bad JSON, missing
  `sections`) loads the backup and sets `restored_from_backup`; a newer `save_version` returns `ERR_FILE_UNRECOGNIZED` (no fallback).
- **Late providers**: `load_game()` keeps sections nobody has registered yet and delivers each inside `register()`. So a scene-owned
  provider must tolerate `from_dict()` being called from its own `_ready()` before it is fully set up (stash it and apply once ready;
  see `Livestock` and `Workstations`). `new_game()` drops pending sections. Do not rely on `reset()` having run first.
- **GameSession** (autoload): `start_new()`, `continue_game() -> Error`, `save_and_quit()`, `quit_to_title()`, `in_game`. Continue loads
  *before* the level exists. It enables `SaveManager.autosave_enabled`, adds a `PlayerState` provider (key `player`: highlighter) to the
  Level, shows a "Saved" toast after the morning fade-in, and hooks any node with signals `save_and_quit_requested` /
  `quit_requested` (group `GameMenu`) to `save_and_quit()` / `quit_to_title()` (no save).
- **Boot**: main scene is `scenes/ui/title_screen.tscn`. Scenes that boot straight into the level (tests, `tools/*`) never enable autosave.

## Quests (additions by the quests branch)
- **QuestData** new fields: `sequential` (conditions are steps done in order; finished steps
  latch, item conditions excepted), `auto_start`, `note` (Almanack), `chain`, `crops`
  (crop ids the errand needs; drives the giver's out-of-season line), `perk_text`,
  `perk_gives`, `perk_takes` (daily favour once complete), `has_perk()`.
- **QuestCondition** new kinds: `met` (met >= amount villagers), `days` (days since the
  quest, or the current step, began), `probe` (a number reported by a registered world
  probe, e.g. `sown.wheat`, `watered.cabbage`). New field `targets` (COUNTER: summed
  counters; feast asks: accepted items), helpers `ids()`, `accepts(item)`.
- **QuestReward** new kind `friendship_all`; new field `text`; `describe() -> String`
  ("50 coins", "6 Seed Barley", "Friendship: Ned Miller"; flags describe as "" unless `text`).
- **QuestManager** additions: `current_step(id) -> int`, `condition_required(id, i) -> int`,
  `start_auto_quests() -> Array[StringName]`, `register_probe(key, callable)`,
  `unregister_probe(key)`, `perk_available(id)`, `can_claim_perk(id)`, `claim_perk(id) -> bool`,
  `grant(reward, npc_ids := [])`, signal `step_advanced(quest_id, step)`.
  Save section `quests` gains `steps`, `step_days`, `start_days`, `perk_days` (old saves load).
- Journal rendering: for every active/complete quest show `title`, `description` and its
  conditions with `condition_progress(id, i)` / `condition_required(id, i)`. For a
  `sequential` quest show only conditions `0..current_step(id)` (earlier ones ticked, the
  current one live). `note` belongs in the Almanack.
- Almanack chain notes: `data/almanack.gd` `CHAINS` (chain id -> text).
- **QuestGiver** (`scenes/world/quest_giver.tscn`, one child of Level): registers giver
  options via `Villagers.register_option`, starts auto quests on a new game, plays hand-offs,
  toasts, and registers the field probes. Quest words live in `data/dialogue_quests.gd`.
- Flags set by quests: `prologue_done`, `miller_fair_measure`, `alewife_barm_share`.

## Feasts (additions by the feasts branch)
- **FestivalData** new fields: `note` (Almanack), `gather_place` + `spot_prefix` (villagers
  stand on the child markers `spot_*` of `feast_ground`, else at `location`), `announce`,
  `reminder`, `asks: Array[QuestCondition]` (DELIVER_ITEM, `targets` = accepted items,
  `amount` wanted, `text`), `tiers: Array[RewardTier]` (`min_count`, `text`, `rewards`,
  `describe()`); helpers `is_running_at(hour)`, `total_asked()`, `tier_index(count)`.
  Feast words live in `data/dialogue_feasts.gd`.
- **FestivalDirector** (`scenes/world/festival_director.tscn`, one child of Level; save key
  `festivals`): `today()`, `tomorrow()`, `running()`, `given(f, ask)`, `total_given(f)`,
  `can_give(f, ask)`, `present()`, `sync()`, `begin(f)`, `contribute(ask) -> int`,
  `contribute_all() -> int`, `mark_attended()`, `resolve(quiet := false) -> int`,
  `open_table()`; signals `announced(text)`, `feast_started(id)`,
  `contributed(id, ask, amount)`, `feast_resolved(id, tier)`.
  Feast runs `start_hour..end_hour`; resolves at the end hour or on `day_ending` (sleep);
  only the highest tier reached pays, and only if the player came (table, greeting or gift).
- **FestivalScreen** (`scenes/ui/festival_screen.tscn`, group `FestivalScreen`): opened by
  the feast table; instanced under `Menus` on demand if the HUD has none.

## UI kit and screens (ui-consistency)
- **Theme** (`tools/build_theme.gd` -> `scenes/ui/game_theme.tres`): no script sets a font colour or size. Use type
  variations: `HeaderLabel`, `SmallLabel` (resized by Large text), `HudLabel`, `NoteLabel` (wrapped body), `HintLabel` (dim
  helper text), `AccentLabel` (small rust), `WarnLabel` (shortfalls, refusals), `GoodLabel` (gains, ready), `CountLabel` /
  `CountShortLabel` (slot corner number), `ListEntry` / `ListEntryGrey`, `TabButton` / `TabButtonRaised`. The small ones derive
  from `SmallLabel`, so Large text scales them. `UIText.label(text, variation, wrap_width)` makes a themed (and wrapped) Label.
- **UIText**: `coins(n)` for sentences ("12 coins"), `price(n)` for tight rows and toasts ("12c"), `minutes(n)`, `label(...)`.
- **List + detail screens**: `ListDetail.new(list_width, detail, max_rows)` (`.menu` is the ListMenu) beside a `DetailPane`
  (`show_info(title, desc, facts, needs, note, makes)`; `needs` is counted against the Inventory, empty parts hide).
  CraftingScreen, ShopScreen (buy side and sell side), BuildMenu and FestivalScreen use them with `UIScreen.build_modal`.
- **TabStrip** reads its back / forward actions itself while visible and emits `tab_stepped(index)`; owners
  (GameMenu, ShopScreen, AlmanackTab) connect it and call `select()`. `set_hint_actions` changes glyphs and keys together.
- **Glyphs**: `InputGlyphs.controller_connected` means "the pad was used last". `InputGlyphs.note_event(event)` (called from
  `HUD._input`) flips it and returns true on a change; HUD then calls `refresh_glyphs()` on group `InputGlyphs.GROUP`
  (`KeyHints`, `TabStrip`, `Prompt`, `DialogueBox` join it). Pad icons come from the InputMap binding of the action (faces,
  shoulders, triggers, sticks, d-pad, start/back); an action with no pad binding shows its key. Keyboard-only actions
  need no entry.
- **Menu scenes**: `scenes/ui/game_menu.tscn` (class `GameMenu`), `scenes/ui/title_screen.tscn` (class `TitleScreen`).
- **Journal**: each quest shows title, giver, description, conditions with live `n/m`, "Ready to hand in - see <giver>",
  `QuestReward.describe()` rewards and, once complete, `perk_text`. A sequential quest shows steps `0..current_step`.
- **Almanack** has three pages: Almanack (forecast saying + `Weather.outlook_text()` + `RiskSystem.advice()` when a RiskSystem
  is in the tree, next feast with its asks or reminder), Discoveries, and Lore (`QuestData.note` for started quests,
  `FestivalData.note` for feasts of this season or already past, `data/almanack.gd` CHAINS for chains whose final good was crafted).
