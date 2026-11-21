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
