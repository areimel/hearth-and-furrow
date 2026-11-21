# Hearth & Furrow: API reference

The contract between systems. Signatures are stable: extend, do not change. If you must change
one, add a new method or signal and update this file in the same commit. Working rules and
gotchas live in `CLAUDE.md`; this file is the reference. Field-level detail is in the doc
comments of each script. Last checked against the code at `mvp-0.1`.

## 1. Conventions
- Ids are `StringName` literals (`&"wheat_sheaf"`), never display names. Content is data: add
  rows to `data/*.gd` and never write `if id == ...` branches. One fact lives in one place (an
  item's price is only on its item row).
- Enums: `G` (`scripts/global/game_enums.gd`): `Season`, `Weekday`, `WeatherKind`, `CropKind`
  (FIELD rain-fed, GARDEN needs watering), `ToolKind`, `ItemCategory`, `GiftReaction`,
  `QuestState`, `RAW_CATEGORIES`. Only append members: values are saved as ints.
- Tuning numbers: `Balance` (`data/balance.gd`, a global class: write `Balance.X`, do not
  preload it). Per-item and per-crop numbers live on their own rows.
- Typed GDScript, tabs, scripts under 300 lines (`tools/check.sh` fails above that), doc comment
  on every public member.
- Never mutate resources returned by `Content`; keep runtime state in your own service.
- Tests extend `TestCase` (`check`, `eq`, `near`; `before_each()` resets state through
  `SaveManager.new_game()`). Any `ERROR` line in a test log fails `tools/check.sh`, so do not
  exercise unknown-id paths in tests.

## 2. Ids (source of truth: `data/`)
| Kind | Ids |
|---|---|
| Tools (`<tool>_<tier>`) | `axe_` `hoe_` `watering_can_` `sickle_` `fishing_rod_` x `wooden` / `iron_shod` |
| Seeds | `wheat_seed` `barley_seed` `pea_seed` `bean_seed` `flax_seed` `cabbage_seed` |
| Crop yields | `wheat_sheaf` `barley` `peas` `beans` `flax` `cabbage` |
| Animal products | `milk` `fleece` `egg` |
| Materials | `log` `hazel_rod` `stone` `clay` `reed` |
| Forage / fish | `blackberry` `hazelnut` `apple` / `trout` |
| Intermediates | `grain` `straw` `flour` `malt` `barm` `flax_fibre` `linen_thread` |
| Goods / upgrade | `bread` `butter` `cheese` `ale` `linen` / `linen_sack` (+6 backpack slots) |
| Crops (own namespace) | `wheat` `barley` `peas` `beans` (FIELD), `flax` `cabbage` (GARDEN) |
| Gatherables | `hazel` `bramble` `stone` `clay` `reeds` |
| Stations | `threshing_floor` `quern` `bread_oven` `churn` `cheese_press` `malting_floor` `brewing_vat` `retting_tub` `distaff` `loom` `workbench` |
| Recipes | `thresh_wheat` `grind_flour` `bake_bread` `churn_butter` `press_cheese` `malt_barley` `brew_ale` `ret_flax` `spin_thread` `weave_linen` `sew_linen_sack` |
| Animals | `cow` `sheep` `chicken` |
| Tool tiers | `wooden`, `iron_shod` |
| NPCs / shops | `reeve` `chandler` `blacksmith` `alewife` `miller` `shepherd` (shops: all but `reeve`) |
| Quests | `prologue` `errand_miller_wheat` `errand_alewife_barley` `errand_chandler_linen` |
| Festivals | `may_day` (spring 20) `harvest_home` (autumn 7) |
| Places | markers in group `Place` in `village.tscn` (`tests/test_village.gd` parses this row, so keep one backticked id each): `church` `manor` `alehouse` `chandlery` `smithy` `mill` `shepherd_hut` `village_green` `market_cross` `pasture` (the test adds the farm_gate and feast_ground markers itself) |
| Flags | `prologue_done` `miller_fair_measure` `alewife_barm_share` |

Chains (`data/recipes.gd` `CHAINS`, checked by `Content.validate()`): bread `wheat_sheaf` ->
`thresh_wheat` -> `grain` -> `grind_flour` -> `flour` (+`barm`) -> `bake_bread`; dairy `milk` ->
`churn_butter`, or `milk` -> `press_cheese` (overnight); ale `barley` -> `malt_barley` (overnight)
-> `brew_ale` (overnight) -> `ale` + `barm`; linen `flax` -> `ret_flax` (overnight) ->
`spin_thread` -> `weave_linen` -> `sew_linen_sack`.

Art: rows store texture paths. A missing file under `res://graphics/placeholder/` (items
`<item_id>.png`, crops `crop_<id>.png`, animals `animal_<id>.png`, stations `<station_id>.png`)
is expected until generated: `ContentBuilder` shows a magenta 16x16 stand-in and lists it in
`Content.pending_placeholders()`. Any other missing path is a `validate()` error.

## 3. Resources (`resources/*.gd`, built by `ContentBuilder`; fields documented in each file)
`ItemData` (`is_tool() is_seed() is_giftable() is_sellable()`), `CropData` (`grows_in(season)`,
`frame_for_age(age)`), `RecipeData`, `StationData`, `AnimalData`, `GatherableData`
(`yields_for(season, day_of_season)`, `needs_tool()`), `NPCData` (`reaction_to(item)`,
`location_at(hour, weekday, season, raining)`), `NPCScheduleEntry`, `ShopData`, `ToolTierData`,
`QuestData`, `QuestCondition` (kinds `have_item deliver_item flag counter talk_to hearts met days
probe`; fields incl. `targets`, helpers `ids()`, `accepts(item)`), `QuestReward` (kinds `coins
item flag friendship friendship_all`; `describe()`), `QuestRewardTier`, `FestivalData`
(`is_running_at(hour)`, `total_asked()`, `tier_index(count)`; `asks`, `tiers`, `gather_place`,
`spot_prefix`, `note`, `announce`, `reminder`).

## 4. Autoloads (load order = `project.godot` order)
**Content** (`content.gd`): read-only registry built by `ContentBuilder.build_all()`
(`content_story_rows.gd` builds quest and festival rows) and checked by `ContentValidator`. An
unknown id `push_error`s once and returns `null`.
- `item(id)`, `has_item(id)`, `items()`, `items_with_tag(tag)`, `items_in_category(cat)`
- `tool_item(kind: G.ToolKind, tier)`, `tool_tier(id)`, `tool_tiers()` (by rank), `tool_kinds()`
- `crop(id)`, `crops()`, `crop_for_seed(item_id)` (null quietly for non-seeds)
- `recipe(id)`, `recipes()`, `recipes_for_station(id)`, `recipes_producing(item)`, `recipes_using(item)`
- `station(id)`, `stations()`, `animal(id)`, `has_animal(id)`, `animals()`, `gatherable(id)`,
  `has_gatherable(id)`, `gatherables()`, `npc(id)`, `npcs()`, `shop(id)`, `shops()`
- `quest(id)`, `quests()`, `festival(id)`, `festivals()`, `festival_on(season, day)` (null quietly)
- `validate() -> Array[String]`, `pending_placeholders()`, `chains()`

**SaveManager**: `SAVE_VERSION`, `save_path` (default `user://save_1.json`), `autosave_enabled`
(false until `GameSession` turns it on), `migrations`, `last_message`, `restored_from_backup`.
- `register(key, provider)`, `unregister(key)`, `is_registered(key)`, `pending_keys()`, `discard_pending()`
- `save_game() -> Error`, `load_game() -> Error`, `autosave() -> Error` (no-op unless enabled),
  `snapshot() -> Dictionary`, `peek_summary() -> {day_index, date, saved_at}` (`{}` if unreadable),
  `migrate(data, target := SAVE_VERSION)`, `backup_path()`
- `has_save()` (file or `.bak`), `delete_save() -> Error`, `new_game()` (every provider's `reset()`)
- signals `saved(path)`, `loaded(path)`, `new_game_started`, `backup_restored`

**Progress** (key `progress`): story flags and counters shared by quests, recipes and tiers.
- `set_flag(f)`, `clear_flag(f)`, `has_flag(f)` (empty flag is true), `flags()`
- `add_count(key, n) -> int`, `count(key)`, `record(verb, id, n)` -> key `"<verb>.<id>"`. Verbs:
  `crafted harvested gathered caught sold bought gifted sowed refunded`. Systems must record them.
- signals `flag_set(f)`, `flag_cleared(f)`, `counter_changed(key, value)`

**GameClock** (key `clock`): inert until `start()`. Fields `day_index hour minute time_scale running paused`.
- `start()`, `stop()`, `set_paused(b)`, `is_ticking()`, `advance_minutes(n)`, `advance_day()`
- `total_minutes()`, `day_progress()` (0 at 6:00, 1 at 24:00), `time_string()`
- signals `minute_passed(hour, minute)` (every `Balance.TICK_MINUTES`), `hour_passed(hour)`,
  `day_ending(day)`, `day_passed(day)`, `passed_out` (at 26:00, clock stopped), `running_changed(b)`

**Calendar** (no state, derived from `GameClock.day_index`; `day = -1` means today)
- `season(day)`, `day_of_season(day)` (1..28), `year(day)`, `weekday(day)`, `today()`,
  `is_market_day(day)` (Saturday), `festival_today(day)`, `day_index_for(year, season, dos)`
- `season_name(s)`, `weekday_name(w)`, `date_string(day)`; `begin_day(day)` (GameClock only)
- signals `season_changed(season)`, `year_changed(year)`, `festival_day(festival)`

**Weather** (key `weather`): `today`, `forecast` (`G.WeatherKind`), `world_seed`. The forecast is always right.
- `is_raining()` (rain or storm), `is_stormy()`, `is_wet_spell()` (rain or storm on 3 of the last 4
  days, today included), `outlook(days) -> Array[int]` (true kinds, tomorrow first), `outlook_text()`
- `roll_next_day()`, `roll_for_day(day)` (no storm before `Balance.STORM_FREE_DAYS`, none on
  consecutive days), `set_today(kind)`, `set_forecast(kind)`; `begin_day(day)` (GameClock only)
- signals `weather_changed(today, forecast)`, `storm_warning(day)`

**Inventory** (key `inventory`): flat slots, `0..9` hotbar, `10..` backpack (24, +6 per linen
sack, max 36).
- `size()`, `is_hotbar_slot(i)`, `slot_id(i)`, `slot_count(i)`, `slot_item(i)`, `is_slot_empty(i)`
- `count(id)`, `has(id, n)`, `space_for(id)`, `can_add(id, n)`
- `add(id, n) -> int` leftover, `remove(id, n) -> bool` (all or nothing), `remove_at(i, n) -> int`
- `move(from, to)` (merge else swap), `swap(a, b)`, `split(i) -> int` (new index or -1)
- `selected_hotbar_index`, `select_hotbar(i)`, `cycle_hotbar(step)`, `selected_id()`, `selected_item()`
- `expand_backpack(n) -> int`, `use_capacity_item(i) -> bool`
- signals `changed`, `slot_changed(i)`, `hotbar_selection_changed(i)`, `item_added(id, n)`,
  `item_removed(id, n)`, `capacity_changed(backpack_capacity)`

**Economy** (key `economy`): `coins`; `add_coins(n)`, `spend(n) -> bool`, `can_afford(n)`.
- Shops are `ShopData` rows (`data/shops.gd`). Wares: `item` / `animal:<id>` / `tool_upgrade:<ToolKind>` /
  `station:<id>` (a kit of build materials), with optional `price`, daily `stock`, `seasons`,
  `sowable`, `unlock`, `requires`. Ware ids default to `<kind>:<target>` (`item:wheat_seed`). Buy
  rules (`cats` / `tags` / `ids` + `factor`) say what the keeper pays for. The goods logic is in `ShopDeals`.
- `shop_buy_price(shop, entry)`, `shop_sell_price(shop, item_id)` (price of the next unit),
  `shop_sell_quote(shop, item_id, amount)`, static `Economy.unit_demand(sold_so_far)`, `shop_stock_left(shop, entry)` (-1 unlimited)
- `shop_block_reason(shop, entry) -> String`, `shop_buy(shop_id, entry_id) -> String` ("" bought, else
  the refusal; all or nothing), `shop_sell(shop_id, item_id, amount, slot := -1) -> int` coins earned
- `price_of(id)`, `buy_price(id)`, `sell_price(id)`, `sell_multiplier()` (market-day bonus); `buy(id, n)`
  exists for tests only (use `shop_buy`)
- Selling more than `Balance.DEMAND_FULL_PRICE_UNITS` of an item in a day pays `DEMAND_STEP` less
  per extra unit (floor `DEMAND_FLOOR`). Stock sold and demand per day are saved (`sold_today`,
  `demand_today`) and reset in `day_ending`.
- signals `coins_changed(coins, delta)`, `item_bought(id, n, coins)`, `item_sold(id, n, coins)`

**Relationships** (key `relationships`): points 0..1000, hearts = points / 100.
- `points(npc)`, `hearts(npc)`, `add_points(npc, n)`, `talk(npc) -> bool` (first today: +20),
  `talked_today`, `has_met`, `gifted_today`, `begin_day(day)` (GameClock only)
- `gift(npc, item) -> G.GiftReaction`: removes the item unless `ALREADY_GIFTED` / `NOT_GIFTABLE`
- signals `points_changed`, `hearts_changed`, `talked`, `gifted(npc, item, reaction)`

**QuestManager** (key `quests`; sections also hold `steps`, `step_days`, `start_days`, `perk_days`)
- `state(id)`, `is_active(id)`, `is_complete(id)`, `active_quests()`, `can_start(id)`, `start(id) -> bool`,
  `start_auto_quests()`, `current_step(id)`, `condition_progress(id, i)`, `condition_required(id, i)`,
  `is_ready(id)`, `complete(id) -> bool` (consumes `deliver_item`s, grants rewards), `refresh()` (runs on
  Inventory / Progress / Relationships / day changes)
- `register_probe(key, callable)`, `unregister_probe(key)`: numbers reported by the world
  (`sown.<crop>`, `watered.<crop>`), read by `probe` conditions
- `perk_available(id)`, `can_claim_perk(id)`, `claim_perk(id)`, `grant(reward, npc_ids := [])`
- signals `quest_started`, `objective_progress(id, index, current, required)`, `step_advanced(id, step)`,
  `quest_ready`, `quest_completed`
- A `sequential` quest's conditions are steps done in order (finished steps latch, item conditions
  excepted); `auto` quests start on a new game; `perk` is a daily favour once complete.

**Settings** (autoload name `Settings`, class `GameSettings`, file `scripts/autoload/game_settings.gd`):
persisted to `user://settings.cfg`. Keys `text_size` ("normal"/"large"), `pause_in_menus`,
`relaxed_time`, `master_volume`, `music_volume`, `sfx_volume`, `fullscreen`.
- `get_value(key, fallback)`, `set_value(key, value)`, `load_file()`, `save()`, `apply_all()`,
  `has_bus(key)`; `GameSettings.instance(tree)` finds `/root/Settings` or creates one (menus, tests)
- signal `changed(key)`

**GameSession**: `in_game`, `start_new()`, `continue_game() -> Error`, `save_and_quit()`,
`quit_to_title()`. Continue loads before the level exists. It turns on autosave, shows a "Saved"
toast after the morning fade-in, and wires nodes in group `GameMenu` (signals
`save_and_quit_requested` / `quit_requested`). The main scene is `scenes/ui/title_screen.tscn`; a level booted
directly (tests, `tools/`) has `in_game == false` and never autosaves.

**AudioDirector**: table `data/audio.gd` (`SFX` events `pickup coins quest bell` -> `{path, volume_db,
pitch_min, pitch_max}`; `MUSIC` by `G.Season`, `MUSIC_FALLBACK`).
- `play(event)` (unknown events ignored), `music_for_season(season)`. Listens to Inventory, Economy,
  QuestManager and GameClock; pickups are rate-limited. The level's `Sounds` node still plays the music.

## 5. World (scene-owned; everything under `Level`)
**Level** (`level.gd`, group `Level`, the mediator): `farm_grid`, `player`, `day_cycle`, `sky`,
`build_mode`; `crops() animals() stations() npcs() gatherables()` (containers under `Objects/`),
`target_cell()`, `is_building()`, `can_place_at_target()`, `show_placement_preview(texture, tint)`,
`hide_placement_preview()`. The player only emits signals (`do_action`, `tool_use`) that the
scene connects to Level.

**LevelFeature** (`level_feature.gd`, `extends Node`): base of the feature roots under Level
(`FarmGrid`, `Livestock`, `Workstations`, `Foraging`, `RiskSystem`, `PlayerState`). Set `save_key`
in the scene. It finds `level`, registers and unregisters its save section, and holds a section
that arrives before `start()`. `Level._ready()` calls `start()` on its LevelFeature children in
tree order, so list a feature after those whose ground it relies on (FarmGrid, Livestock,
Workstations, Foraging, then RiskSystem and PlayerState). Override `_on_level_ready()`,
`_restore(data)`, `_clear()`, `_new_game_setup()` and `to_dict()`; never `from_dict()` / `reset()`.
Other scene-owned saved nodes register themselves: `TreeGrove` (`trees`), `FestivalDirector` (`festivals`).

**FarmGrid** (key `farm`: `tilled`, `wet`, `crops`): the single authority on tiles. Cells are
`Vector2i`, `floor(pos / Balance.TILE_SIZE)`.
- `cell_of(pos)`, `get_target_grid(pos, dir)`, `is_water`, `is_farmable`, `is_tilled`, `is_wet`,
  `till`, `water`, `water_all`, `dry_all`, `tilled_cells`, `wet_cells`
- `is_tool_valid(action, cell)` (action is a `G.ToolKind` or `PlayerActions.SOW`; false for any cell
  holding a `Placeable`), `update_highlight(pos, dir, action, tier := null)`, `highlight_cell(cell, valid)`
- `occupy(cell, node)`, `release(cell)`, `occupant(cell)`, `is_occupied`, `is_free_for_placement`,
  `is_buildable(cell)` (free, dry, outside house and village, untilled)
- `in_village(cell)`: the village's walkable cells; there water, farmable, buildable are false.
  `is_walkable_land(cell)`: ground without water or collision, outside the village.
- `crop_field: CropField`.

**CropField**: `sow(cell, crop_id) -> Crop`, `crop_at(cell)`, `crops()`, `ripe_crops()`,
`reap(cell) -> int`, `remove(cell)`, `resolve_day()`, signal `crop_reaped(cell, crop_id)`.
**Crop**: `crop_id cell age weeds blighted blight_warning`, `is_ripe() is_flattened() flatten()
clear_weeds() yield_amount() collect() info_text() to_dict() from_dict()`. GARDEN crops do not
grow on a dry day, FIELD crops do.

**RiskSystem** (key `risks`): forgiving storm and blight (grain only). No risk before
day `Balance.RISK_FREE_DAYS`, never both on one crop, losses capped.
`recent_losses()`, `advice()` (reeve hint), `previous_crop(cell)` (rotation memory), `is_risk_free()`.
The storm acts in `day_ending` on a snapshot of crops ripe at dawn; blight warns during a wet spell,
turns the crop blighted next morning unless hoed (`Crop.clear_weeds()` cures the warning) or reaped.
**WorldSky**: `base_tint(progress)` (day gradient x eased `Balance.SEASON_TINTS`; storm dims and
adds rain), `is_raining()`, static `sway_material`.

**Livestock** (key `livestock`, `Animal` scenes under `Objects/Animals`): `animals()`, `count(id)`,
`can_add(id)`, `add_animal(id) -> Animal`, `pen_center()`. New games start with `Balance.STARTER_HERD`;
at most `max_per_species` each. Animals subscribe to `day_ending` themselves. **Animal**: `mood fed_today
petted_today product_ready`, `feed() collect() pet()`, `prompt_text()`; care rules are data
(`verb`, `collect_verb`, `feed_seasons` on `data/animals.gd`, `Balance.ANIMAL_MOOD_*`).

**Workstations** (key `stations`): `stations()`, `station_at(cell)`, `place(id, cell)`,
`build(id, cell)` (pays the cost; null if unaffordable), `can_afford_build(id)`, `can_remove(cell)`
(no job, no output), `remove(cell)`, `refund_of(id)` (`Balance.BUILD_REFUND_SHARE`, rounded down).
New games start with `Balance.STARTER_STATIONS` in a yard. **Station** (`extends Placeable`):
`Station.create(id)`, `is_working() has_output() job_count() has_free_slot() jobs() can_start(recipe)
inputs_missing(recipe) start_job(recipe) collect()`, signals `changed job_finished collected
interaction_requested`. Overnight jobs finish in `day_ending`; leftovers stay in `output`.

**Foraging** (key `foraging`): spawns `Gatherable`s into `level.gatherables()`, scattered (seeded
from `Weather.world_seed`, fallback 1530) onto land the player can walk to. `nodes()`,
`count_ready(id)`, `node_at(cell)`, `place(id, cell)`, `scatter(id, count, rng)`,
`scatter_area(marker, rng)`. A `Marker2D` in group `ForageArea` with metadata `gatherable_id`, `count`,
optional `radius` adds nodes on a new game. Placement rules on the row: `any_grass`, `near_water`.
**Gatherable** (`extends Placeable`): `Gatherable.create(id)`, `gather() -> bool`, `is_ripe()`,
`roll_yields()`, `prompt_text()`; regrows after `regrow` days; a row's optional `tool` gates it.

**Trees and tools**: `AppleTree` (`apple_tree.gd`; group `Axe_able`): `health felled stump_days`,
`hit(action, dir, tier)`, `fell(bonus_logs)`, `regrow()`, `apple_count()`, `pick_apples()`,
`AppleTree.hits_to_fell(tier)`. Felling gives `Balance.TREE_LOGS + tier.bonus_logs` logs; apples are
picked by hand and regrow in `Balance.APPLE_SEASONS`. `TreeGrove` is the one `trees` provider.
Tier rows (`data/tool_tiers.gd`, `ToolTierData`): `area` (cells per swing, only `ToolTiers.AREA_KINDS`:
hoe, can, sickle), `power`, `bonus_logs`, `fishing_ease`. `PlayerActions.tier_of(item)` (null for
non-tools), `PlayerActions.for_item(item)`, `ToolArea.cells(action, tier, origin, step)` (each cell is
validated alone). `Player.start_fishing(ease_factor := 1.0)`.

**Build mode** (`Level.build_mode`): `Mode {OFF, PLACE, REMOVE}`, `start_placing(id)`, `start_removing()`,
`exit()`, `perform()`, `target_valid()`, `active()`, signal `mode_changed`. The `build` action opens
`BuildMenu` (`open_menu()`, signals `station_chosen`, `remove_chosen`). While active it sets
`Player.action_override` (a `Callable` that takes the `action` button); other modes can use the same
hook. Refunds go through `Loot.give(..., &"refunded")`.

**Villagers** (group `Villagers`): `npc(id)`, `all()`, `register_option(npc_id, text, callback,
condition := Callable())` (Trade, errands), `set_line_override(provider)` (`provider(npc_id) ->
Array[String]`, empty falls through; `Callable()` clears), `gather_at(place_id, spot_prefix)`,
`release()`. **Places** (static): `all has marker position_of route path_between spots`;
`position_of` is `Vector2.ZERO` for an unknown place. **Village**: walkable grid, `path_between`.
**Shops**: `open(shop_id) -> bool`, `is_open_today()` (festival `shops_closed`); registers a "Trade"
option for every shopkeeper. **QuestGiver**: registers giver options, starts auto quests on a new
game, toasts, registers field probes; words in `data/dialogue_quests.gd`. **FestivalDirector**
(key `festivals`): `today() tomorrow() running() given() total_given() can_give() present() sync()
begin() contribute() contribute_all() mark_attended() resolve() open_table()`, signals `announced
feast_started contributed feast_resolved`. A feast runs `start..end` hours, resolves at the end hour or
on `day_ending`, only the best tier reached pays, and only if the player came. Words live in
`data/dialogue_feasts.gd`. **PlayerState** (key `player`): `{highlighter_on, pos, facing}`.
**DayCycle** (group `DayCycle`): `end_day(passed_out := false)` is the only entry for bed and pass-out;
`busy`, `DayCycle.is_transitioning(tree)`, signals `transition_started`, `transition_finished`.
**GridSearch** (static): `chebyshev`, `ring`, `nearest`, `nearest_block`, `flood`, `shuffle`,
`cells_to_pairs`, `pairs_to_cells`.
Time pauses behind open screens only while `pause_in_menus` is on; the day transition always pauses it.

## 6. Actors and interaction
- Player, NPC and animal live in `scripts/actors/` + `scenes/actors/`; `bed.gd` and `house.gd` in
  `scripts/objects/`. `Player` fields: `input_locked`, `highlighter_on`, `action_item`, `action_override`;
  signals `tool_use`, `do_action`, `interact_focus_changed`. After a `UIScreen` swallows an `action`
  press, `action` is ignored until released.
- **Interactable** (`Area2D`): `@export prompt_text`, `enabled`, signals `interacted(player)`,
  `prompt_changed(text)`. Every interactable keeps `prompt_text` current (Station "Open <name>" /
  "Collect", NPC "Talk", Animal its verb, Gatherable its verb, Tree "Pick apples", Bed "Sleep"). Disable
  the Interactable rather than showing an empty prompt.
- **NPC** always talks by default. "Give <item>" is a dialogue choice while the selected item is giftable
  and no gift was given today; registered options are always reachable. `scheduled_place()`,
  `hold_at()`, `release_hold()`, `say(lines)`. **Emote**: `pop(n)` with `HEART HAPPY FLAT SAD`.
- **Loot** (static): `give(tree, item_id, amount, verb) -> int` (Inventory + Progress + toast, "Your pack
  is full" on overflow; an empty verb records no Progress), `has_all(cost)`, `missing(cost)`,
  `shortfall(cost)`, `take(cost)`, `deliver(tree, items, verb)` (leftovers stay with the giver). Use it for
  every grant or charge of items.
- **Placeable** (`StaticBody2D`): `setup(grid_coord, level, parent)`, `remove()`; base of Station and
  Gatherable.

## 7. UI kit and screens
- **Theme** (`tools/build_theme.gd` -> `scenes/ui/game_theme.tres`, colours in `UIPalette`): no script sets
  a font colour or size. Use type variations: `HeaderLabel`, `SmallLabel` (scaled by Large text),
  `HudLabel`, `NoteLabel`, `HintLabel`, `AccentLabel`, `WarnLabel`, `GoodLabel`, `CountLabel` /
  `CountShortLabel`, `ListEntry` / `ListEntryGrey`, `TabButton` / `TabButtonRaised`.
  `UIText.label(text, variation, wrap_width)`, `UIText.coins(n)` ("12 coins"), `price(n)` ("12c"),
  `minutes(n)`.
- **UIScreen** (`Control`, group `UIScreen`): `open()`, `close()`, `is_open`, signals `opened` `closed`,
  `build_modal(width) -> PanelFrame`, static `any_open(tree)`. Closes itself on `ui_cancel` or `menu`.
  Screens: `CraftingScreen.open_for(station)`, `ShopScreen.open_for(shop_id)` / `show_tab(Tab)`,
  `BuildMenu`, `FestivalScreen.open_for(director, feast)`, `DialogueBox.show_dialogue(npc, lines,
  options)`, `GameMenu` (tabs listed in its `TABS`; a tab scene extends `MenuTab`).
- **List and detail**: `ListDetail.new(list_width, detail, max_rows)` (`.menu` is a `ListMenu`: `set_entries`,
  `set_entry_greyed`, signals `entry_selected` `entry_focused` `cancelled`) beside `DetailPane.show_info(title,
  desc, facts, needs, note, makes)`. Also `ItemGrid`, `ItemSlot`, `ItemRow`, `HeartsRow`, `IconLabel`,
  `PanelFrame`, `Toast.show_message(tree, text, icon)`, `Prompt`, `ScreenLocator.find_or_create(tree, group,
  scene, fallback_parent)`.
- **TabStrip** reads its back and forward actions itself while visible and emits `tab_stepped(index)`; owners
  call `select()`. Q/E (`tool_backward` / `tool_forward`) step tabs in GameMenu, ShopScreen and Almanack.
- **Glyphs**: `InputGlyphs.controller_connected` means "the pad was used last"; `note_event(event)` (from
  `HUD._input`) flips it and the HUD calls `refresh_glyphs()` on group `InputGlyphs.GROUP` (`KeyHints`,
  `TabStrip`, `Prompt`, `DialogueBox`). Pad icons come from the action's InputMap binding.
- **Almanack** pages: Almanack (forecast and `Weather.outlook_text()`, `RiskSystem.advice()`, next feast),
  Discoveries, Lore (notes from `QuestData.note`, `FestivalData.note`, `data/almanack.gd` `CHAINS`).
  **Journal**: each active or complete quest with live `n/m` conditions, rewards and (once done) its perk.
- **Input map** (checked by `tests/test_input_map.gd`): move `left right up down` (WASD, stick, d-pad);
  `action` Space / A; `tool_backward` / `tool_forward` Q E / LB RB; `hotbar_1..10` keys 1..0; `highlighter`
  H / X; `build` M / Y; `menu` Esc / Start; `day_change` Tab (keyboard only, debug builds only); `ui_*`
  arrows, WASD, d-pad, stick; accept Enter / KP Enter / Space / A, cancel Esc / B.

## 8. Day-end order (`GameClock.advance_day()` is the only way a day ends)
The caller (bed, `passed_out` handler, debug key, via `DayCycle.end_day`) plays the transition, then
`advance_day()` runs synchronously:
1. `day_ending(old_day)`: resolve the finished day with *today's* state still current (`Weather.today`,
   watered tiles, season). Listeners must not depend on each other's order: FarmGrid (grow or pause
   crops, weeds, then clear watering), RiskSystem (storm on the dawn snapshot), stations (finish overnight
   jobs), animals (produce if fed), trees, gatherables (regrow), Economy (restock), festivals (resolve).
2. The clock moves to `old_day + 1`, 6:00.
3. `Calendar.begin_day()`: `season_changed`, `year_changed`, `festival_day`.
4. `Weather.begin_day()`: `today = forecast`, new forecast, `weather_changed`.
5. `Relationships.begin_day()`: daily talk and gift limits reset.
6. `day_passed(new_day)`: set up the new morning (rain waters all soil, blight resolves, NPCs pick schedule
   entries, HUD, quest refresh, festival setup).
7. `SaveManager.autosave()`, last, so the save holds the rolled-over morning.
Never call `advance_day()` from inside a `day_ending` or `day_passed` handler.

## 9. Save contract
- Every stateful service implements `to_dict()`, `from_dict(data)`, `reset()` and calls
  `SaveManager.register(&"<key>", self)` in `_ready()`. Scene-owned state registers when its scene loads and
  unregisters on exit (LevelFeature does this). Keys: `clock progress weather inventory economy
  relationships quests farm livestock stations foraging risks player trees festivals`.
- `from_dict` must accept `{}` and missing keys, must not start the clock and must not rely on `reset()`
  having run first. Store ids and plain values, never node or resource references. `Vector2i`,
  `StringName`, ints and typed arrays survive via `JSON.from_native`; still cast with `int()`.
- File: `{"save_version", "saved_at", "sections": {key: dict}}`. A missing section calls `reset()`. Changing a
  section's shape: bump `SAVE_VERSION` and add a step to `SaveManager.migrations` (step `v` upgrades v to v+1).
- Writes go to `<path>.tmp`, then rename; the previous valid save is copied to `<path>.bak`. A damaged main
  file loads the backup (`restored_from_backup`); a newer `save_version` returns `ERR_FILE_UNRECOGNIZED`.
- Late providers: `load_game()` keeps sections nobody has registered yet and delivers each inside
  `register()`, so a scene-owned provider must tolerate `from_dict()` during its own `_ready()` (see
  `LevelFeature`). `new_game()` drops pending sections.

## 10. Tools (`tools/`)
- `check.sh [--quick|--full]`: the gate (see `CLAUDE.md`). `parse_check` loads every script inside the
  running project; `year_sim` + `sim_farmer` play 112 days through public APIs and check the economy bands in
  `data/balance.gd`; `screenshot` captures a scene with `--setup` steps; `art/list_pending` prints
  placeholders and validation problems; `village/*` + `bake_village.gd` generate `scenes/world/village.tscn`;
  `build_theme.gd` writes the theme; `make_placeholder_art.sh` writes `graphics/placeholder/`;
  `wire_scene.py` instances scenes into a `.tscn`.
