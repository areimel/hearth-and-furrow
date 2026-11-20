# Product Requirements Document: *Hearth & Furrow* (working title), a cozy Tudor farming and crafting sim

**Bottom line:** Stick with Godot. Use Godot 4.7.x stable with GDScript for gameplay, and build *Hearth & Furrow* as a data-driven, 16×16-tile, SNES-style top-down sim. Gameplay is driven by Tudor processing chains (grain → malt → ale, flax → linen, milk → cheese). The structure follows Stardew-style daily and seasonal loops, with no stamina meter and a forgiving model of crop and livestock failure. Ship to Windows, Linux and Steam Deck through Steam using GodotSteam.

## TL;DR
- **Engine: Godot is the right choice.** It is MIT-licensed and free, exports natively to Linux and Steam Deck, and its 2D tooling (TileMapLayer, integer scaling) fits pixel-art farming sims well. Godot 4.7.2 (18 August 2026) is the current stable release, and 4.8 was still in beta as of 18 November 2026. Write gameplay in GDScript. C# exports to desktop without problems, but it costs you the web export and adds a .NET toolchain you don't need. The only serious challenger is Phaser + Electron, which would reuse your TypeScript, but Steam integration on that route is the weakest link.\[1\]
- **Design:** the progression engine is Tudor processing chains, documented historically and shown on screen in BBC Two's *Tudor Monastery Farm* (2013). The calendar runs from Lady Day (25 March, the Tudor New Year) through haymaking, Lammas, harvest, Michaelmas and Christmastide, with feast days from Thomas Tusser's 16th-century husbandry manual as festivals. Risk follows history: J.Z. Titow's study of the Bishop of Winchester's estate records found that bad harvests came about one year in eight. The forgiving design gives warnings, mitigations and partial yields, and never permanent ruin.
- **Art:** start with CC0 16×16 packs (Kenney, Ninja Adventure) so the licensing is clean, and add Mana Seed (SNES-style, commercial use allowed, no GenAI) as the main stylistic anchor.\[2\]\[3\] Treat LPC (32×32, CC-BY-SA/GPL) and Sprout Lands Free (non-commercial only) with care. Render at 320×180 with "expand" aspect and integer scaling, which maps exactly to 1280×800 on the Steam Deck and 1920×1080 on PC. Call the game "inspired by Tudor farm life", never by the BBC series name.

---

## 1. Overview and vision

**Vision statement.** A warm, forgiving life on a small English farm around 1500–1560. You turn raw land, hazel, wool, milk and grain into progressively better goods and tools. You become part of a village that runs on the rhythm of the plough, the saints' days and the market.

**Elevator pitch.** "Stardew Valley meets a living-history documentary. Plough with oxen, malt barley for the alewife, card and spin your own wool, and celebrate Plough Monday with your neighbours, all in lush SNES-era pixel art. There's no stamina bar and no grind for its own sake: every new craft unlocks the next."

**Inspiration and IP note.** The direct inspiration is BBC Two's *Tudor Monastery Farm* (the user's "Tudor Farm"). It was a six-part series broadcast 13 November–18 December 2013, made by Lion Television and filmed at the Weald and Downland Open Air Museum in Sussex.\[4\] Historian Ruth Goodman and archaeologists Peter Ginn and Tom Pinfold lived as lay tenant farmers on monastic land around 1500, and a Christmas special aired on 31 December 2013.\[5\] The game must be presented as *inspired by Tudor rural life*. It should not use the series title, the BBC name or logo, or the presenters' names or likenesses in the game, store page or marketing. Historical facts and practices are not copyrightable; the show's branding, footage and specific presentation are protected.

**Design pillars**
1. **Authentic.** Every crop, tool, craft and feast has a real Tudor counterpart, with light simplification. A small in-game "Almanack" can explain the history behind each item.
2. **Cozy and forgiving.** No hunger, no stamina, no permadeath. Setbacks have visible causes, advance warning, mitigations, and always leave a partial yield.
3. **Craft-driven progression.** The main motivation is turning raw resources into processed goods that unlock better tools and buildings, in the spirit of Minecraft's tech tree but grounded in history.
4. **Rhythm of the year.** The calendar of work and feasts is the game's structure, the way the seasons are in Harvest Moon/Story of Seasons.

---

## 2. Target audience and platforms

| Item | Requirement |
|---|---|
| Primary audience | Cozy/farm-sim players (Stardew, Story of Seasons, Kynseed); history enthusiasts and fans of living-history TV |
| Secondary audience | Crafting/automation fans who enjoy production chains |
| Platforms | Windows x86_64, Linux x86_64 (native), Steam Deck (native Linux build) |
| Input | Keyboard + mouse; gamepad (Xbox/PlayStation/Steam Deck built-in controls); every action must be reachable on a controller |
| Display | 16:9 desktop (1080p/1440p/4K) and 16:10 Steam Deck (1280×800) |
| Session length | 15–30 minutes (one or two in-game days) |

**Steam Deck Verified targets.** Valve's verification covers four categories: input, display, seamlessness and system support.\[6\] To meet them:
- The default controller configuration must give access to all content.\[7\]
- On-screen glyphs must match the controller in use.\[7\]
- Text must be legible at 1280×800. Valve's Steamworks compatibility documentation sets 9 px as the absolute minimum character height at 1280×800 and recommends aiming for 12 px.
- Any text entry, such as naming the farm, must open the on-screen keyboard.\[7\]
- Default settings must give a playable frame rate.\[8\]

---

## 3. Core gameplay loops

| Loop | Duration | Player activities | Reward |
|---|---|---|---|
| **Moment-to-moment** | Seconds | Walk, use tool on tile (hoe, sow, water, scythe), interact with animal or NPC, drag items | Satisfying feedback such as soil changing, a sheaf appearing, a coin sound |
| **Daily** | ~12–15 min real time | Wake → check weather and almanac → tend animals (milk, feed, muck out) → field work → craft/process at workstations → visit village/market → sleep (autosave, processing timers tick, crops grow) | Products, coin, friendship points, finished processes |
| **Weekly** | ~7 days | Market day in the village; Sunday rest bonus (gentle buffs for attending church or resting); parish errands | Better prices, gossip and quests |
| **Seasonal** | 28 days | Season-specific tasks (spring sowing, summer hay and shearing, autumn harvest and Michaelmas, winter threshing and crafting); a fair or major feast | New recipes and seeds, structure unlocks, story chapter |
| **Yearly** | 4 seasons | Year-end review at Michaelmas "audit" (rent paid to the steward), village standing level, new chapter of the light story | New land strips, buildings, tool tier, NPC events |

**Why this works.** Stardew Valley's Community Center (6 rooms, 30 bundles) gives players direction in an otherwise open-ended game. Small rewards come from individual bundles and big unlocks from completing rooms, and the bundles guide players through every system without hand-holding.\[9\]\[10\] Our equivalent is the **Parish Guild Rolls**, explained in section 4.12.

**No stamina, so what limits the day?** Time is the only limiter. Each tool action takes a small slice of in-game time, and the player chooses what to do with daylight. That keeps the "meaningful choice per day" tension of Stardew without the energy-bar friction reviewers name as its main early-game chore.\[11\]

---

## 4. Feature requirements

Priority key: **MVP** = needed for a playable first public build; **v1** = Early Access/1.0; **Stretch** = post-launch.

### 4.1 Feature prioritization summary

| # | Feature | MVP | v1 | Stretch |
|---|---|---|---|---|
| 1 | Crop farming (till, sow, weed, harvest; 6 crops) | ✅ | 15+ crops, crop rotation/fallow | Strip fields with neighbours |
| 2 | Livestock and dairy (cows, sheep, chickens; milking, shearing) | ✅ | Pigs + pannage, oxen, geese, bees | Breeding traits |
| 3 | Gathering (wood, hazel, stone, clay, reeds, forage) | ✅ | Coppicing cycles | Mining (lead/iron as in the series) |
| 4 | Crafting chains and tech tree | 4 chains | 10+ chains | Chain automation with hired labour |
| 5 | Building structures (fence, pen, workbench, dairy) | ✅ | Barn, malthouse, granary, wattle-and-daub expansion | Timber-framed house rebuild |
| 6 | Tool tiers (3 tiers) | 2 tiers | 3 tiers + enchant-like "fittings" | Cosmetic tools |
| 7 | Calendar and festivals | 4 seasons, 2 feasts | 8+ feasts | Moveable feasts computed from Easter |
| 8 | Weather | Sun/rain/storm | Frost, drought, wet harvest | Regional microclimate |
| 9 | Crop/livestock risk + mitigation | Blight + storm | Murrain, foot rot, poor harvest year | Insurance-like "parish relief" |
| 10 | Village & NPCs | 6 NPCs, schedules | 15–20 NPCs | Aging/generations (Kynseed-like)\[12\]\[13\] |
| 11 | Relationships/friendship | Hearts, gifts | Events, courtship, marriage | Children |
| 12 | Market economy | Shop buy/sell | Market days, fairs, seasonal prices | Dynamic supply/demand |
| 13 | Story/quest framework | Prologue + 3 quests | Chapters per year, guild rolls | Optional historical arc (Dissolution) |
| 14 | Inventory | Grid, stacks, hotbar | Chests, sorting, controller quick-swap | Carts |
| 15 | Save/load | Single slot autosave | 3 slots, Steam Cloud | Cross-save |
| 16 | UI/HUD | Clock, date, hotbar, money | Almanack, map, journal | Accessibility suite |
| 17 | Audio | Placeholder SFX + 2 music loops | Seasonal tracks, ambient beds | Period instrument soundtrack |
| — | **Hunger / stamina** | ❌ **Explicitly excluded** | ❌ | ❌ |

### 4.2 Farming and crops
- **Actions:** till (spade/hoe; plough for large plots once oxen are available), broadcast-sow (grains) or dibble-sow (beans, peas), weed, water (garden only; field crops are rain-fed), reap (sickle for wheat, scythe for other grains), bind into sheaves, cart to barn, thresh, winnow.
- **Field vs garden.** Fields grow grain and pulses and rely on rain. The garden plot grows vegetables, herbs, flax/hemp and dye plants and can be watered. This mirrors the real Tudor split, where gardens grew flax or hemp as cash crops and dye plants such as madder (red), woad (blue), dyer's greenweed (green) and weld (yellow).\[14\]
- **Winter vs spring corn.** Wheat and rye are sown in autumn and harvested first; barley, oats and beans are sown in spring.\[14\]
- **Fallow and rotation (v1).** A simple three-field rotation bonus: a field left fallow or grazed gains fertility. Manure from animals adds fertility.
- **Weeding as gentle maintenance.** Weeds slowly reduce yield but never kill a crop. A quirky historical detail can appear in the almanac: thistles cut before St John's Day (24 June) were said to multiply threefold.\[14\]
- **Gleaning:** after harvest, a small free forage of grain lets the player help poor NPCs, which earns friendship.

### 4.3 Livestock and dairy
- **Animals:** cows (milk, calves, manure), oxen (draught: unlock ploughing large fields), sheep (wool, ewe's milk, lambs), pigs (pannage foraging in autumn woods, bacon/lard), chickens/geese (eggs, feathers, goose for Harvest Home), bees (skeps → honey and beeswax).
- **Care actions:** feed (hay in winter), water, milk, shear, muck out, let out to pasture, bring in. Missing care lowers mood and output. It never kills an animal outright (see 4.10).
- **Dairy season:** milk yield peaks from late spring to Michaelmas and tails off in winter. Tusser wrote that good housewives' dairies lasted "from Aprill begin, til saint Andrew be past" (30 November).\[15\]
- **Dairy targets for balancing:** according to the Mid-Tudor Manor history site, each cow was expected to produce 7 stone (98 lb) of cheese and a stone (14 lb) of butter between May and Michaelmas, and the Witheridge Historical Archive gives the same figure for the medieval period. Use roughly a 7:1 cheese-to-butter value ratio as the economic anchor for the dairy line.
- **Shearing:** after haymaking. According to the same Mid-Tudor Manor source, a good shearer could shear 7–8 sheep per hour, so shearing can be a quick, satisfying timed mini-action. Early (finer) fleeces sell higher.

### 4.4 Gathering
Wood (felling and coppiced hazel), withies (willow), reeds/rushes (thatch, rushlights, floor mats), clay, chalk/limestone (for lime), stone, wild forage (blackberries, damsons and bullaces, hazelnuts, herbs), acorns/beechmast (pig feed), feathers, eels (stretch).

### 4.5 Crafting chains and tech tree (core of the game)

**Rules**
1. Every raw resource feeds at least one chain.
2. Every chain's output unlocks a tool, structure, recipe or quest.
3. Processing takes real in-game time at stations (malting floor, churn, loom), so players plan around overnight jobs, as with Stardew's kegs and preserves jars.

**Concrete Tudor chains**

| Chain | Steps (station) | Outputs and unlocks | Historical grounding |
|---|---|---|---|
| **Bread** | Wheat sheaf → thresh (flail, barn floor) → winnow (basket) → grain → mill (village miller, fee) → flour → knead with barm (yeast from ale) → bake (bread oven) | Bread (trade good, gift, festival entry) | Threshing with flails and winnowing baskets; the series made bread and cultivated wild yeast\[4\]\[16\] |
| **Ale** | Barley → steep → malting floor (germinate) → kiln (dry) → malt → mash with water → ferment with yeast → ale | Ale (high-value staple); barm byproduct for bread | Ale = malt, water, yeast; hopped "beer" was a newer import\[17\]\[18\] |
| **Beer (v1)** | Malt + hops (hop garden) → boil wort → ferment → beer | Keeps longer (slower spoilage), sells to the inn | Hops planted in England by 1428; hops make beer bitter but help it keep\[17\]\[19\] |
| **Linen** | Flax (pulled) → ret in stream/pond → dry → break/scutch → hackle → spin on distaff → weave (loom) → linen | Linen cloth → shirts, sacks (sack = storage upgrade) | Flax pulled up, retted, beaten and spun on a distaff\[14\] |
| **Rope** | Hemp → ret → break → twist | Rope → well bucket, hay cart, bell rope quest | Hemp wound into rope or cord\[14\] |
| **Wool / cloth** | Fleece → sort/grade → card → spin → weave → full (fulling mill) → dye (woad/madder/weld) | Woollen cloth (top export good), clothing cosmetics | The series covered driving, shearing, sorting, grading, carding and spinning, weaving and fulling\[4\] |
| **Dairy** | Milk → settle/skim → churn → butter → wash, press, salt; Milk → rennet → curd → press → cheese → age | Butter, cheese (keeps), whey for pigs | The series churned, pressed and salted butter and made sheep's-milk cheese\[4\] |
| **Candles** | Sheep fat → render → tallow → dip rushes or wicks → tallow candles/rushlights; Beeswax → wax candles (church gift) | Light source (longer working evenings); church favour | The series made rushlights, dipped candles and harvested beeswax\[4\] |
| **Lime** | Chalk/limestone → kiln (calcine) → quicklime → slake → lime → lime-ash floor, limewash, mortar | Building upgrade: lime-ash floor, limewash | The series calcined and slaked lime and built a lime-ash floor\[4\] |
| **Charcoal** | Coppiced wood → stack, clamp with turf → slow burn → charcoal | Fuel for the smithy → iron tool tier | Pre-industrial fuel for metalworking |
| **Building** | Hazel → split rods → weave wattle panels; clay + dung + straw → daub → wattle-and-daub wall; reeds/straw → thatch | Pens, outbuildings, house expansion | The series built wattle-and-daub barriers\[4\] |
| **Wood** | Log → saw/rive → planks; steam-bent ash → tool handles, hoops; turned wood (pole lathe) → bowls/plates; coopered staves → barrels | Barrels (needed for ale and storage), handles for every tool | The series steam-bent wood and hired turners for bowls and plates\[4\] |
| **Preserves (v1)** | Salt (from brine) → salt meat/butter; damsons/bullaces + honey → melomel | Winter food trade goods | Episode 6 covered extracting salt from brine and a damson-and-bullace melomel\[4\] |

**Tech tree tiers (gating)**
- **Tier 0, "Cottar":** hand tools, wattle pen, garden plot, hand quern, churn.
- **Tier 1, "Husbandman":** barn + threshing floor, malting floor, loom, bread oven, rented ox team.
- **Tier 2, "Yeoman":** own oxen and plough, malthouse kiln, dairy house, hop garden, charcoal clamp, smithy access for iron tools.
- **Tier 3, "Freeholder" (v1):** timber-framed house expansion, fulling contract, bee garden, glazed window (rare purchase), extra field strips.

### 4.6 Building farm structures
Structures are placed on a grid on the farm map. Each needs materials plus an optional hired craftsman (which costs coin and time and saves the player's time).
- MVP: fence/hurdle, wattle pig sty, chicken coop, workbench, compost/dung heap, dairy shelf.
- v1: barn with threshing floor, malt house with kiln, bake oven, granary on staddle stones, beehive skeps, hop poles, sheepfold, wattle-and-daub cottage extension, thatched roof upgrade.

### 4.7 Tools and tool tiers (historically plausible, replacing copper/iron/gold)

| Tier | Name | Made from / acquired via | Effect |
|---|---|---|---|
| 1 | **Wooden** | Hand-carved: wooden spade, hazel rake, ash flail, wooden fork | Base speed, single tile |
| 2 | **Iron-shod** | Wooden tool + iron edge/shoe from village smith (needs charcoal and coin) | +1 tile area or faster action |
| 3 | **Smith-forged** | Full iron/steel head, ash handle steam-bent by player | 3-tile area (scythe sweep, hoe row) |
| Fittings (v1) | Whetstone, leather grip, tallowed joint | Crafted consumable-free upgrades | Small qualitative perks (less weeding, faster reaping) |

Draught upgrades are a parallel axis: hand dig → borrowed ox team (the series ploughed with oxen, using what was described as the country's last working ox team for harrowing) → own ox team → horse (later Tudor: by the early 16th century horses were becoming more common for wagons and ploughs).\[4\]\[14\]

### 4.8 Time and calendar
- **Day:** 6:00–24:00 in-game. A clock tick of 10 in-game minutes is roughly 7 real seconds (tunable). Sleeping at any time ends the day; staying up past 2:00 just teleports you home (no penalty except a lost morning).
- **Year:** 4 seasons × 28 days. The year starts at **Lady Day (25 March)**, the Tudor New Year, when work began in earnest after the winter lull.\[14\]

**Agricultural calendar (in-game mapping)**

| Season (in-game) | Real months | Key work | Feasts and festivals |
|---|---|---|---|
| **Spring** | Late Mar–May | Plough the fallow; sow barley, oats, beans, peas; plant garden; clean beehives; lambing, calving; dairy starts | Lady Day (New Year); Easter (moveable); May Day; Whitsun |
| **Summer** | Jun–Aug | Haymaking (scythes, about an acre per man per day); sheep washing and shearing; weeding; pull and ret flax and hemp (July); grain harvest from early August, wheat and rye first\[14\] | Midsummer/St John's Eve (24 June) with sheep-shearing feast; **Lammas (1 Aug)**: loaf-mass blessing bread from the first wheat, end of haymaking\[20\]\[21\] |
| **Autumn** | Sep–Nov | Finish harvest; peas, beans, vetches; thresh; sow winter wheat and rye; harvest honey and apples; take surplus stock to market; pigs to acorns (pannage)\[16\] | **Harvest Home** (goose feast); **Michaelmas (29 Sep)**: rents and debts due, officials appointed; Hallowtide "Seed Cake" feast (end of wheat sowing)\[22\]\[23\] |
| **Winter** | Dec–mid-Mar | Threshing and winnowing in the barn; hedging, ditching, lopping pollards (January); tool repair; crafting season\[16\]\[24\] | **Christmastide (12 days)**; Twelfth Night; **Plough Monday** (first Monday after Twelfth Day, back to work); Shrovetide (pancakes, fritters)\[22\] |

**Festival design.** Each festival is a one-day event with a mini-activity:
- Plough Monday: plough race.
- Shrovetide: pancake contest. Replace the historical "threshing the hen" blood sport with a cozy alternative.
- Sheep-shearing feast: shearing contest.
- Lammas: best-loaf judging.
- Harvest Home: feast (contribution bundle).
- Michaelmas: rent day plus fair.
- Christmastide: mummers' play and wassail.

Thomas Tusser's *Five Hundred Points of Good Husbandry* is the period source for many of these. It was first published as *A Hundreth Good Pointes* in 1557, expanded to 500 points in 1573, and went through eighteen 16th-century editions. Its "ploughman's feasting days" list Plough Monday, Shrovetide, sheep shearing, the Wake Day, Harvest Home and the Seed Cake, and Tusser frames them as "comfort with labour is fit to be had".\[22\] That is a good thematic line for the game.

### 4.9 Weather
- **States:** clear, overcast, rain (waters fields), heavy storm (can flatten ripe grain), frost (spring/autumn, damages tender garden crops), drought spell (summer, multi-day), wet harvest (late summer, raises sprouting/mould risk on uncut grain).
- **Forecast:** the almanac and NPC folk-weather lore (shepherd, priest) give a reasonably accurate next-day forecast plus a 3-day "feeling". This gives players time to act, which is central to forgiveness.
- **Visuals:** a rain particle overlay, wind sway on crops, and a seasonal palette swap via a CanvasModulate/shader per season.

### 4.10 Crop and livestock failure risk, with forgiving mitigation
Historical anchor: in J.Z. Titow's study of the Bishop of Winchester's estate records from 1209–1350, bad harvests (15%+ below average) happened about one year in eight, and good ones (15%+ above) about one in twenty. Hay failure meant fewer animals could be kept over winter. The game turns that variance into gentle drama.

| Risk | Trigger | Warning | Mitigation (player agency) | Worst case (forgiving cap) |
|---|---|---|---|---|
| Storm-flattened grain | Storm when crop is ripe | Forecast 1–2 days ahead | Reap early (lower quality); bind and stook sheaves | Lose ≤40% of affected field; straw still usable |
| Wet harvest / mould | Multi-day rain at harvest | Almanac "wet week" | Barn storage; dry sheaves on racks | Grain drops a quality tier (becomes animal feed, still sellable) |
| Frost | Early autumn/late spring | Shepherd's lore, clear-night forecast | Cover with straw; plant hardier varieties | Garden crop regrows at half speed |
| Blight/rust (grain) | Low rotation + wet season | Visible leaf spots | Rotate fields, fallow, burn stubble | Partial yield; field "rests" next season |
| Murrain (cattle illness) | Poor shelter + muddy pens | Animal mood icon, cough SFX | Clean pens, herbal drench from the wise woman, rest | Animal sick for 3–5 days (no output); recovers. **No death in default mode.** |
| Foot rot / scab (sheep) | Wet pasture | Limping animation | Trim hooves (the series shaved its sheep's hooves), tar salve, move pasture\[4\] | Reduced wool for the season |
| Poor hay year | Drought spring | Short grass visuals | Tree hay (leaf fodder, as cut in the series), buy hay at market\[4\] | Must sell or overwinter fewer animals |

**Rules**
- **Never a death spiral.** Every failure leaves a partial yield or a by-product.
- **Parish safety net.** A bad season triggers neighbours' charity events and quests. This makes failure a social and story beat rather than a punishment.
- **Optional "Hard Year" toggle (v1)** for players who want harsher risk, including livestock death.
- **Folk remedies** are flavour items, such as the series' herbal cold remedy. They work in-game as gentle buffs, and the almanac notes period beliefs without endorsing them medically.

### 4.11 Village, NPCs and relationships
- **Village layout:** church, manor/grange (steward's office), mill (water- or windmill), smithy, alehouse, green with market cross, cottages, common pasture, woods, stream.
- **NPC systems:** daily schedules by weekday and season (data-driven), rain schedules, festival schedules.
- **Friendship:** 0–10 hearts. Raised through gifts (liked/loved items tied to the NPC's trade), talking daily, completing their requests, and festival participation.
- **Heart events:** small cutscenes at 2/4/6/8 hearts reveal backstory and unlock a recipe or technique. For example, at 4 hearts the alewife teaches beer with hops.
- **Courtship and marriage (v1):** handled gently and period-appropriately (banns read in church, a wedding feast).

### 4.12 Market economy
- **Daily shops:** general chandler, smith (tools/fittings), miller (milling fee), alehouse (buys ale, sells food).
- **Market day (weekly):** stalls with better prices and rotating seasonal buyers (wool merchant in summer, cheese factor in autumn).
- **Fairs:** a Michaelmas fair and a spring fair with rare items (hop rootstock, new breeds, glass, spices).
- **Pricing model:** base price × quality × seasonal modifier × supply modifier (selling 50 cheeses in one day lowers the price for a week). Wool and cloth are the premium export line, which reflects how central wool was to the economy. *Tudor Monastery Farm*'s second episode described wool production as accounting for around half the country's wealth around 1500.\[25\]
- **Rent:** a modest quarterly payment, collected at Michaelmas and on Lady Day. It is always affordable by design. A shortfall becomes a "debt to the steward" quest, never eviction.
- **Parish Guild Rolls (bundle system):** the village guild and parish church ask for themed contributions ("Harvest Home Roll: 5 sheaves of wheat, 2 cheeses, 1 goose"). Completing a roll unlocks a structure, recipe or story chapter. The design mirrors Stardew's bundles, adapted to Tudor parish guilds, which the series showed when the team commissioned a guild.\[4\]

### 4.13 Light story and quest framework
- **Premise:** the player takes up the tenancy of a run-down holding on lands belonging to a nearby priory (a nod to the show's monastic setting), around 1530.
- **Arc (v1):** Year 1 is establishing the farm. Year 2 brings village standing and the Guild Rolls. Year 3 brings rumours of change as the monasteries' lands pass to new owners. The optional historical arc follows Henry VIII's Dissolution, which *Tudor Monastery Farm*'s final episode reflected on.\[25\] Keep it bittersweet but hopeful: the farm continues under a new landlord, and the player's standing protects the village.
- **Quest types:** fetch/deliver, craft-to-order, festival prep, relationship events, and "teach me" quests that unlock recipes.
- **Implementation:** quests are data Resources with condition and reward arrays, tracked by a QuestManager autoload. Dialogue goes through Dialogue Manager (see 7.5).

### 4.14 Inventory
- 24-slot backpack (expandable with linen sacks → leather satchel), a 10-slot hotbar, and stack size 99 (tools 1).
- Item quality: Poor / Fair / Good / Fine, which affects price and gifts.
- Chests (wooden coffer, barrel) with a quick-stack-to-nearby-chests action. This matters for controller comfort.

### 4.15 Save/load
- Autosave on sleep (end of day), as in Stardew, plus a manual save-and-quit.
- Format: versioned JSON (or Godot Resource) with a `save_version` field and migration functions.
- MVP: one slot; v1: three slots plus Steam Cloud via the Steamworks Auto-Cloud configuration.

### 4.16 UI/HUD
- HUD: clock and day, season icon, weather icon, coin purse, hotbar. **No stamina or hunger bar.**
- Menus: inventory, crafting (filterable by station, showing chain previews: "this flax makes → linen → sack"), almanac/encyclopedia, relationships, map, journal/quests, settings.
- Accessibility: text size options (at least 2 sizes), rebinding, a hold-to-toggle option, a colour-blind-safe crop-ripeness indicator, and a pause-time option for relaxed play.

### 4.17 Audio
- SFX: tool hits, animals, footsteps by surface, weather beds, church bells marking hours (a useful diegetic clock).
- Music: seasonal loops in a period-flavoured style (recorder, lute, crumhorn, hurdy-gurdy timbres). Use CC0/CC-BY music, or commission later.

---

## 5. Content outline (v1 target)

**Crops (field):** winter wheat, rye, maslin (wheat+rye mix), barley, oats, peas, beans, vetches.
**Crops (garden):** cabbage, onions, leeks, turnips, yellow carrots, parsnips, lettuce, spinach, cucumber, herbs (parsley, sage, thyme, rosemary, mint, camomile, lavender), flax, hemp, hops, dye plants (woad, madder, weld, dyer's greenweed).\[14\]
**Orchard/forage:** apples, pears, damsons, bullaces, cherries, hazelnuts, blackberries, crab apples (verjuice).
**Animals:** dairy cows, oxen, sheep (with lambs), Tamworth-style pigs (the series used Tamworths), chickens, geese, bees, a horse (late game), a farm dog (companion, no care burden), and a cat.\[4\]
**Resources:** logs, hazel rods, withies, reeds, rushes, straw, hay, clay, chalk, stone, dung, fleece, hides, tallow, beeswax, honey, salt, iron bar (purchased), charcoal.
**Craftables:** flour, bread, malt, ale, beer, butter, cheese, linen, rope, yarn, woollen cloth, dyed cloth, tallow candles, rushlights, beeswax candles, lime, wattle panels, daub, thatch bundles, planks, barrels, wooden bowls, tool handles, sacks, melomel, salted butter, preserved pork.
**Structures:** see 4.6.
**NPC archetypes (15–20):**
- **Reeve:** elected tenant who organises the field work; tutorial guide.
- **Steward/bailiff:** the priory's agent; rent and story.
- **Prior/parish priest:** feasts and church.
- **Alewife:** brewing teacher. Women brewed most ale before the Black Death and some continued into the 17th century, when guilds and male-run beer brewing displaced many.\[26\]
- **Miller:** milling fees; slightly suspected of short measure, a classic folk trope.
- **Blacksmith:** tool tiers.
- **Shepherd:** weather lore and sheep.
- **Wise woman/cunning woman:** herbal remedies.
- **Carpenter/cooper**, **thatcher**, **weaver/fuller**, **chandler**.
- **Pedlar:** fair-day rare goods.
- **Widowed dairywoman**, **swineherd boy**, **a younger son of the gentry** (romance option), **a travelling wool merchant**.

**Festivals:** Lady Day, Easter, May Day, Whitsun, Midsummer/sheep-shearing feast, Lammas, Harvest Home, Michaelmas fair, Hallowtide Seed Cake, Christmastide (12 days), Twelfth Night, Plough Monday, Shrovetide, Wake Day (parish church dedication feast; Tusser's text puts most between June and October).\[22\]

---

## 6. Art and audio direction

### 6.1 Style target
SNES-era top-down art (A Link to the Past, Secret of Mana, Earthbound): saturated but earthy palettes, 3/4 top-down perspective, 16×16 tiles, characters about 16×32 px. Mana Seed's packs explicitly emulate 16-bit SNES RPGs such as Secret of Mana, which makes them the closest stylistic anchor.\[2\]\[27\]

### 6.2 Resolution and scaling (decision)

| Setting | Value | Rationale |
|---|---|---|
| Base viewport | **320×180** | SNES-like density; integer-scales ×6 to 1920×1080 and ×8 to 2560×1440 |
| Stretch mode | `viewport` | Renders at native pixel resolution, then upscales\[28\]\[29\] |
| Stretch aspect | `expand` | On 16:10 the Deck shows 320×200 at ×4, exactly **1280×800** with no black bars; 16:9 shows 320×180 |
| Scale mode | `integer` (Godot 4.2+) | No uneven pixel sizes\[28\]\[30\] |
| Texture filter | Nearest | Crisp pixels\[31\] |
| Snap 2D transforms/vertices to pixel | On | Stops shimmer while the camera moves\[30\]\[32\] |
| UI text | Pixel font ≥ 7 px tall at base res | ×4 on Deck gives ~28 px physical, far above the 9 px Verified floor |

### 6.3 Free asset sources and licensing

| Source | Licence | Tile size | Commercial Steam use | Notes |
|---|---|---|---|---|
| **Kenney** (Tiny Town 130 assets; Roguelike/RPG pack 1,700 assets) | **CC0** | 16×16 | ✅ No attribution required\[33\] | Simple, bright, less "SNES-rich"; great for prototyping |
| **Ninja Adventure** (Pixel-Boy & AAA, itch.io) | **CC0** | 16×16 | ✅ Attribution appreciated, not required\[34\] | Includes a Godot 4 example project;\[34\] use the itch.io CC0 release, not older redistributed copies |
| **Mana Seed** (Seliel the Shaper) free packs (RPG Starter Pack, Gentle Forest) + paid farming bundle | Custom "Mana Seed User License", All Rights Reserved\[35\] | 16×16 | ✅ May be commercial\[35\]\[36\] | Paid assets: one game per purchase (free assets exempt). **No GenAI anywhere in the project, code included.** No redistribution, so keep assets out of a public repo\[35\]\[37\]\[38\] |
| **Sprout Lands** (Cup Nooble) | Free version: **non-commercial only**; Premium (≥$3.99): commercial OK\[39\] | 16×16 | ❌ free / ✅ premium | Credit Cup Nooble;\[39\] cute pastel style, less SNES |
| **LPC: Liberated Pixel Cup** (OpenGameArt) | **CC-BY-SA 3.0 / GPL 3.0** dual; some artists (Sharm, Redshrike) also offer OGA-BY/CC-BY\[40\] | **32×32**\[40\] | ⚠️ Allowed, but with share-alike obligations on modified art and full attribution\[41\] | Different tile size from the 16×16 packs, so don't mix; community debate over whether SA "infects" the game\[42\] |
| **OpenGameArt (general)** | Varies per asset | Varies | Check each asset | Keep a CREDITS file per asset |

**Licensing policy for this project**
1. Prefer CC0, then CC-BY, then custom commercial licences. Avoid CC-BY-SA/GPL art unless it's isolated and unmodified.
2. Keep `ASSET_LICENSES.md` with source URL, licence, author and date downloaded for every file.
3. If you use Mana Seed, keep the repo private (or git-ignore the assets) and don't use AI coding assistants on this project.\[37\]\[38\]
4. Never ship assets labelled "free for non-commercial use" in a paid build.

### 6.4 Keeping a consistent style across packs
- **One tile size (16×16).** Never mix 16 px and 32 px packs; downscaling LPC breaks its pixel art.
- **One master palette.** Remap all assets to a single palette (e.g., a 32–64 colour earthy SNES palette) in Aseprite with "Replace colour"/indexed mode, or use a palette-swap shader in Godot.
- **Consistent outline rule.** Pick either dark outlines or selective, coloured outlines and edit outliers.
- **Consistent light direction** (top-left) and shadow colour.
- **Use one pack as the "spine"** (Mana Seed or Ninja Adventure) and only fill gaps from others.

---

## 7. Technical design

### 7.1 Engine recommendation: Godot 4.7.x (confirmed)

**Current state (as of 20 November 2026):**
- Godot 4.7 stable shipped 18 June 2026.\[43\]
- The latest stable is 4.7.2 (18 August 2026).\[44\]
- Godot 4.8 reached beta 4 on 18 November 2026, with stable estimated for Q4 2026 but no date announced. The 4.8 .NET build requires .NET 10.\[45\]\[46\]

**Recommendation:** start on 4.7.2 and move to 4.8.x once its first patch release is out. Pre-release builds carry real risk for Deck work: a 4.8-dev6 regression broke the Steam Deck's built-in controls in Linux exports.\[47\]

**GDScript or C#?** Use **GDScript** for gameplay.
- Its syntax is Python-like and gradually typed (`var x: int`), which feels natural to a TypeScript developer.
- It needs no build step, has the best editor integration, and is what most tutorials and addons (Dialogue Manager, GodotSteam GDScript API) use.
- C# works: official docs confirm .NET projects export to Linux, Windows and macOS. However, C# Godot 4 projects still cannot export to the web, which removes the free itch.io browser demo option.\[48\]\[49\] It also adds a .NET SDK dependency that changes version between Godot releases.
- If you miss C#'s type system, use typed GDScript with "untyped declaration" warnings set to error.

### 7.2 Engine comparison

| Engine | Language | Cost/licence | 2D pixel fit | Linux/Deck | Steam integration | Learning curve for Alec | Verdict |
|---|---|---|---|---|---|---|---|
| **Godot 4.7** | GDScript / C# | Free, MIT | Excellent: TileMapLayer, terrains, integer scaling | Native Linux export | GodotSteam (mature, Steam Input support) | Low–medium | **✅ Recommended** |
| **Unity 6** | C# | Free under $200K revenue/funding; Pro $2,200/seat/yr; splash screen optional\[50\] | Very good (2D Tilemap, Pixel Perfect Camera) | Native Linux | Steamworks.NET / Facepunch | Medium (heavier editor) | Strong #2; the 2023 runtime-fee episode (cancelled Sept 2024) dented trust\[51\] |
| **GameMaker** | GML | Free non-commercial; $99.99 one-time to sell\[52\] | Excellent for 2D | Linux export | Built-in Steamworks extension | Low, but GML is a dead-end skill | Good, but proprietary and less transferable |
| **Phaser 4 + Electron** | TypeScript | Free, MIT | Good | Electron Linux build | steamworks.js / steamworks-ffi-node / Greenworks\[53\]\[54\]\[55\] | **Lowest** (your stack) | Viable (Vampire Survivors started in Phaser), but Steam SDK integration is the hard part\[56\]\[57\] |
| **Excalibur.js + Tauri** | TypeScript | Free | Good | Tauri uses WebKitGTK on Linux | Weak | Low | ❌ WebKit web views are slower than Chromium for graphics\[58\] |
| **Defold** | Lua | Free (Defold licence) | Very good | Yes | Extension available | Medium | Fine, but a smaller cozy-game community |
| **MonoGame/FNA** | C# | Free | Good, but you build everything | Yes | Steamworks.NET | High (framework, no editor) | Stardew was built on XNA/MonoGame, but too much plumbing for a hobby |
| **LÖVE** | Lua | Free (zlib) | Good | Yes | Community libs | Medium | Lightweight, but no editor/tilemap tooling |
| **Bevy** | Rust | Free | Improving | Yes | bevy_steamworks | High (Rust + ECS + immature editor) | ❌ Not for this project |
| **Pixel Game Maker MV** | Visual | Paid | Platformer/action-focused | Windows-centric | Limited | Low, but limited | ❌ Poor fit for sim systems |

**Why Godot over the TypeScript route?**
- A farming sim is heavy on tilemaps and editor work: painting maps, placing NPC paths, animation, UI layout. Godot's integrated editor saves hundreds of hours compared with hand-rolling scenes in Phaser plus Tiled.
- In JavaScript, Steam integration is the recognised gap. The Phaser team's April 2026 case study of Telazer Games' *Desktop Heroes* (Phaser + Electron, launched on Steam in October 2025) names the Steam SDK as its biggest technical hurdle: there is no official JavaScript SDK for Steam, so the team had to rely on third-party libraries.
- Steam Deck controller handling also needs extra work in Electron.
- Your web skills still transfer well: Godot's Control-node UI resembles flexbox containers, signals resemble event emitters, autoloads resemble app-level stores, and Resources resemble typed JSON models.

### 7.3 Project architecture (Godot)

```
res://
  autoload/          # singletons (like global stores)
    GameClock.gd     # time, day, season, year; emits minute/hour/day/season signals
    Calendar.gd      # feast days, market days, weather schedule
    Weather.gd       # daily roll + forecast, emits weather_changed
    Inventory.gd     # player bag, hotbar; pure data + signals
    Economy.gd       # prices, modifiers, transactions
    Relationships.gd # hearts, gift log, event flags
    QuestManager.gd  # active/completed quests, Guild Rolls
    SaveManager.gd   # serialize/deserialize all of the above, versioned
    SteamService.gd  # GodotSteam wrapper; no-ops when Steam absent
    InputGlyphs.gd   # detect last input device → swap button prompts
  data/              # data-driven content (.tres Resources)
    items/  crops/  animals/  recipes/  stations/  npcs/  festivals/  quests/
  scenes/
    world/  (Farm.tscn, Village.tscn, Woods.tscn, each with TileMapLayer stack)
    actors/ (Player.tscn, NPC.tscn, Animal.tscn)
    objects/ (CropPlot.tscn, Station.tscn, Chest.tscn)
    ui/     (HUD.tscn, InventoryUI.tscn, CraftingUI.tscn, Almanack.tscn)
  systems/
    state_machine/   # generic FSM node + states (PlayerIdle, PlayerWalk, PlayerUseTool…)
  addons/            # dialogue_manager, godotsteam, gut (tests), etc.
```

**Key patterns**
- **Data-driven content with custom Resources.** `class_name ItemData extends Resource` with `@export var id, display_name, icon, stack_size, base_price, tags`. Subclasses include `CropData` (season, days_per_stage, regrows, yield_table, weather_sensitivity), `RecipeData` (inputs: Array[ItemStack], outputs, station_id, minutes, unlock_flag) and `NPCData` (schedule, gift prefs). These are editable in the inspector, type-checked, and serialisable. Use JSON/CSV only if you want spreadsheet balancing; a small editor script can import CSV into `.tres`.
- **TileMapLayer.** The `TileMap` node was deprecated in Godot 4.3 in favour of multiple `TileMapLayer` nodes.\[59\]\[60\] Use separate layers for ground, tilled soil, crops/decor and collision overlay. Store farm-tile state (tilled, watered, crop id, growth stage) in a `Dictionary[Vector2i, TileState]` on a FarmGrid node, not in tile metadata, so it saves cleanly.
- **Time-driven simulation.** Crops and processing stations listen to `GameClock.day_passed`/`minute_passed`. Overnight processing is resolved in a single "end of day" pass (grow crops, apply weather, roll risks, finish recipes, autosave).
- **State machines** for player tool use, animals (idle/graze/sleep/sick/follow) and NPCs (schedule-following through a navigation agent and waypoint list).
- **Save system.** Each autoload implements `to_dict()`/`from_dict()`, and SaveManager writes `user://save_{slot}.json` with `save_version`. Never pickle node trees; save IDs, not object references.
- **Input.** Define actions in the Input Map bound to **"All Devices"**, not device 0. A Godot forum thread documents Deck controls breaking because an input map was bound to a specific device ID, and the Deck's built-in controller doesn't necessarily register as device 0.\[61\]

### 7.4 Steam Deck and Steam integration
- Export a **Linux x86_64** build (native). Test early with the SteamOS Devkit Client, setting full screen at 1280×800 (16:10).\[62\]
- **GodotSteam** (GDExtension or prebuilt editor) handles achievements, Steam Cloud, rich presence and Steam Input. Its Steam Input tutorial shows initialising input, enabling device callbacks and converting Steam Input actions into Godot input events, with a fallback to Godot's native input when Steam isn't running.\[63\]
- Ship a **default Steam Input configuration** (gamepad template) in Steamworks, and make sure every menu works by controller only.\[64\]
- Use dynamic glyphs that switch to controller prompts the moment a gamepad is used.\[65\]
- Use Steam's on-screen keyboard for naming the farm or character.\[8\]
- Performance target: 60 fps at 800p is easy for a 2D game. Cap at 60 and offer a 30/40 fps battery option.

### 7.5 Recommended tools and addons

| Need | Recommendation | Why |
|---|---|---|
| Pixel art editing | **Aseprite** (paid, ~$20) or **LibreSprite** (free fork) | Palette remapping, animation; Aseprite Wizard addon imports into Godot\[32\] |
| Tilemaps | Godot's built-in TileSet/TileMapLayer + terrains (autotile) | No external tool needed; Tiled only if you prefer it (via a Tiled importer addon) |
| Dialogue | **Dialogue Manager** (Nathan Hoad, MIT; v4 targets Godot 4.6+) | Stateless, text-script-like (feels like writing code), reviewers call it production-ready; good for RPG dialogue that reads game state. Dialogic 2 is still alpha and suits visual-novel staging\[66\]\[67\] |
| Steam | **GodotSteam** | Mature, documented, Steam Input support |
| Testing | **GUT** or gdUnit4 | Unit-test crafting, economy and save migration (your web-dev testing habits transfer) |
| Controller glyphs | Controller Icons addon | Automatic prompt swapping |
| Version control | **Git + GitHub/GitLab private repo with Git LFS** for `.png/.wav/.ogg` | Use the Godot `.gitignore` (`.godot/` folder excluded); commit `.tres`/`.tscn` text files; private repo to honour Mana Seed redistribution terms |
| Asset store | Godot's new **Asset Store** (introduced in 4.7, replacing the Asset Library; still in beta)\[68\] | Find addons |

---

## 8. Milestones and roadmap (solo hobbyist, ~8–10 h/week)

| Phase | Duration | Goal and exit criteria |
|---|---|---|
| **0. Learn** | 3–4 weeks | Finish the official "Your first 2D game" tutorial and one top-down RPG tutorial. Build a throwaway "walk around a tilemap and pick up items" toy. |
| **1. Core prototype** | 6–8 weeks | Player movement, 4-direction animation, GameClock, till/sow/water/harvest for 3 crops, an inventory hotbar, sleep → day passes → crops grow, JSON save. Placeholder Kenney/Ninja Adventure art. **Exit:** "Is planting and harvesting fun for 10 minutes?" |
| **2. Crafting spine** | 6–8 weeks | Data-driven RecipeData, 3 stations, 2 complete chains (bread and dairy), 1 tool tier upgrade, one animal (cow). **Exit:** a player can go from seed to bread and buy a better hoe. |
| **3. Vertical slice** | 8–10 weeks | One full season (Spring), the village with 5 NPCs on schedules, Dialogue Manager, friendship, a shop, weather (sun/rain/storm), one festival (Lady Day or May Day), first Guild Roll, final art direction locked with palette, full controller support. **Exit:** 30–45 minutes of polished play; test on a Steam Deck. |
| **4. MVP** | 4–6 months | All four seasons, 4 chains, 6 crops, 3 animals, 2 tool tiers, 2 risks with mitigation, 6 NPCs, market day, 3 save slots, settings and accessibility. **Exit:** a full in-game year without blockers; friends and family playtest. |
| **5. Early Access–ready** | 4–6 months | v1 content targets, story Year 1–2, Steam page (needs capsule art, so budget for it or use pack art within licence), GodotSteam achievements and Cloud, Deck Verified checklist pass, credits/licence screen. **Exit:** stable build, wishlist page live, demo (Linux/Windows; add a web demo only if GDScript). |

Total: roughly 18–24 months to Early Access at hobby pace. That is normal: Eric Barone (ConcernedApe) built Stardew Valley alone over about four and a half years, from 2012 to its release on 26 February 2016.

**Learning resources (web/TS → Godot)**
- The official Godot docs: "Getting Started", the "GDScript reference", "Static typing in GDScript", and "Multiple resolutions" for pixel settings.
- GDQuest (free and paid courses; strong on architecture and typed GDScript).
- HeartBeast and Brackeys' Godot tutorials (top-down action RPG fundamentals).
- The GodotSteam docs and tutorials (Steam Input, Cloud).
- Dialogue Manager's video guides.
- Mental model map: Node ≈ component; Scene ≈ reusable component tree; Signal ≈ event emitter / callback prop; Autoload ≈ global store/service; Resource ≈ typed immutable-ish data model; `await` works like in JS.

---

## 9. Risks and open questions

| Risk | Likelihood | Impact | Mitigation |
|---|---|---|---|
| **Scope creep** (the genre invites it) | High | High | Hard MVP list (section 4.1); one new system per milestone; a "parking lot" doc for ideas |
| **Asset inconsistency** across packs | High | Medium | One 16×16 spine pack, a single palette, outline rules; budget later for a commissioned key-art and character pass |
| **Licence violations** (non-commercial packs, SA/GPL, Mana Seed GenAI clause) | Medium | High (store takedown) | ASSET_LICENSES.md, CC0-first policy, no AI-assisted code if any Mana Seed asset is used |
| **IP: BBC naming/likeness** | Low if careful | High | Never use "Tudor Monastery Farm", "Tudor Farm", BBC, or presenters' names/likenesses; original characters; "inspired by Tudor farm life" |
| **Historical accuracy vs fun** | Medium | Medium | Rule: "plausible over pedantic". Compress timescales (malting takes days, not weeks), keep the Almanack honest about simplifications, and soften harsh history (blood sports, famine, religious conflict) |
| **Engine version churn** | Medium | Low | Pin to a stable minor version; upgrade only at milestone boundaries; never ship on dev/beta builds |
| **Steam Deck input quirks** | Medium | Medium | All-devices input map, Steam Input default config, test on hardware from the vertical slice onward |
| **Motivation and burnout** | High | High | Monthly playable builds, devlog, small public milestones (itch.io prototype) |

**Open questions**
1. Exact era: c.1500 (as in the series, pre-Dissolution, monastic landlord) or c.1550s (Tusser's era, post-Dissolution)? *Recommendation:* start c.1530 so the Dissolution can serve as a late-story beat.
2. Gendered roles: historically, dairy, brewing and spinning were women's work. Allow any player character to do everything, and note the history in the Almanack.
3. Is marriage in scope for v1 or stretch?
4. Generations/aging à la Kynseed (PixelCount Studios, ex-Bullfrog developers), where characters age and play passes to children: a compelling hook, but a stretch goal at most.\[69\]\[70\]
5. Commercial ambition: if Steam sale is likely, decide early on Mana Seed (paid, strict licence) versus a CC0-only art path.

---

## 10. Success metrics (hobby project)

| Category | Metric | Target |
|---|---|---|
| Learning | Comfortable building systems in typed GDScript (signals, Resources, autoloads, FSMs) | By end of Phase 2 |
| Delivery | Monthly playable build | ≥ 10 of 12 months per year |
| Fun | Playtesters voluntarily play past the first in-game week | ≥ 3 of 5 testers |
| Core loop | Testers complete at least one full crafting chain without help | ≥ 80% |
| Coziness | Testers report no "stress" moments from failure systems (post-test survey) | ≥ 4/5 average |
| Technical | 60 fps on Steam Deck at 1280×800; zero save-corruption bugs across a full year | Before EA |
| Deck | Passes self-audit against Valve's four Verified categories | Before EA |
| Compliance | 100% of shipped assets listed in ASSET_LICENSES.md with commercial-compatible licences | Before any paid release |

---

## Caveats
- Godot 4.8 was still in beta as of this writing.\[44\] Release timing and any 4.8 breaking changes (e.g., the .NET 10 requirement) are estimates, not confirmed.
- The Steam Deck Verified text-size rule (9 px absolute minimum at 1280×800, 12 px recommended) comes from Valve's Steamworks compatibility documentation, but review criteria can change. Confirm against the current page before submitting.
- Historical numbers (cheese yields, harvest frequencies, shearing rates) come from secondary educational summaries of medieval and Tudor sources. They're used here as balancing anchors, not scholarly claims, and regional practice varied widely.
- Asset licences change. Re-check each asset's page at download time and archive a copy of the licence text.

## Sources

1. [Publishing web games on Steam with Electron - Gamedev.js](https://gamedevjs.com/tutorials/publishing-web-games-on-steam-with-electron/)
2. [Free Pixel Art Tileset - Gentle Forest by Seliel the Shaper - Itch.io](https://seliel-the-shaper.itch.io/gentle-forest)
3. [Free Mana Seed RPG Starter Pack by Seliel the Shaper](https://seliel-the-shaper.itch.io/rpg-starter-pack)
4. [Tudor Monastery Farm](https://en.wikipedia.org/wiki/Tudor_Monastery_Farm)
5. [Tudor Monastery Farm](https://www.tvmaze.com/shows/19280/tudor-monastery-farm)
6. [How to Test Steam Deck Compatibility for Your Game](https://bugnet.io/blog/how-to-test-steam-deck-compatibility)
7. [Steam Deck UI checklist for game developers · Envy](https://envyui.com/blog/steam-deck-ui-checklist)
8. [Steam Deck Verified: How to Get Your Game Approved - DEV Community](https://dev.to/aplusgamesstudio/steam-deck-verified-how-to-get-your-game-approved-kf4)
9. [Stardew Valley: Encouraging Ethical Decision-making in Games](https://medium.com/@swa287/stardew-valley-encouraging-ethical-decision-making-in-games-730795b3dce8)
10. [Game Design Perspective: Stardew Valley — Pixelated Playgrounds](https://www.pixelatedplaygrounds.com/sidequests/game-design-perspective-stardew-valley)
11. [Should You Buy Stardew Valley Right Now?](https://delayedrespawnse.com/blog/should-you-buy-stardew-valley-right-now/)
12. [Checking In On Kynseed](https://articles.retroware.com/2020/10/13/checking-in-on-kynseed/)
13. [Kynseed: A game about life, farming, and adventure](https://virus.hr/en/reviews/kynseed)
14. [The farming year](https://midtudormanor.wordpress.com/the-farming-year/)
15. [The Project Gutenberg eBook of Fiue Hundred Pointes of Good Husbandrie, by Thomas Tusser..](https://www.gutenberg.org/files/51764/51764-h/51764-h.htm)
16. [Strange Horizons - The Medieval Agricultural Year By Rachel Hartman](https://strangehorizons.com/wordpress/non-fiction/articles/the-medieval-agricultural-year/)
17. [Life in Elizabethan England 75: Good English Ale](https://www.elizabethan.org/compendium/75.html)
18. [Recreating Medieval English Ales](https://www.cs.cmu.edu/~pwp/tofi/medieval_english_ale.html)
19. [Beer in England](https://en.wikipedia.org/wiki/Beer_in_England)
20. [The Norman Yoke - The Story of England](https://erenow.org/common/thestoryofengland/9.php)
21. [Lammas](https://en.wikipedia.org/wiki/Lammas)
22. [‘The Ploughman’s Feasting Days’: Festive Work Relations in Thomas Tusser](https://drtayloraucoin.com/2026/01/12/forget-not-the-feasts-that-belong-to-the-plough-festive-work-relations-in-thomas-tussers-five-hundred-points-of-good-husbandry/)
23. [Medieval Agriculture: A Study of its Practices](https://medievalhistory.top/farming-and-trade/medieval-agriculture-a-study-of-its-practices/)
24. [Five Hundred Points of Good Husbandry: Together with a Book of Huswifery](https://www.researchgate.net/publication/364773757_Five_Hundred_Points_of_Good_Husbandry_Together_with_a_Book_of_Huswifery)
25. [Tudor Monastery Farm - Apple TV](https://tv.apple.com/gb/show/tudor-monastery-farm/umc.cmc.l0wzhe4nsotjvlvo78wboqtt)
26. [Alewife (trade)](<https://en.wikipedia.org/wiki/Alewife_(trade)>)
27. [SELIEL'S WORKSHOP - Home](https://selieltheshaper.weebly.com/)
28. [Fix Blurry Pixel Art in Godot 4 - Rat Records Merchandise](https://ratrecordsnexus.com/blogs/journal/fix-blurry-pixel-art-godot-4)
29. [Using AI Pixel Art Sprites in Godot 4 (Crisp, Not Blurry)](https://spritelab.dev/guides/export-to-godot)
30. [How to Set Up Pixel-Perfect Pixel Art in Godot 4 - Godot 4 CRT, Dither & VHS Shaders](https://leckie1989.itch.io/retro-look-shader-kit-godot/devlog/1728357/how-to-set-up-pixel-perfect-pixel-art-in-godot-4)
31. [How to set up a pixel art game so it renders pixel perfect](https://www.spritecook.ai/blog/pixel-perfect-pixel-art-game-settings)
32. [godot 44 settings for pixel art](https://itch.io/blog/806788/godot-44-settings-for-pixel-art)
33. [Tiny City - GameDev News](https://gamedev.net/news/6544-tiny-city/)
34. [Ninja Adventure - Asset Pack by pixel-boy - Itch.io](https://pixel-boy.itch.io/ninja-adventure-asset-pack)
35. [The Mana Seed User License](https://selieltheshaper.weebly.com/user-license.html)
36. [Pixel Art Creature Sprites - Livestock by Seliel the Shaper](https://seliel-the-shaper.itch.io/livestock)
37. [Pixel Art Unity Package - Mana Seed Tileset Collection by Seliel the Shaper](https://seliel-the-shaper.itch.io/unity-tileset-collection)
38. [Pixel Art Character - The Mana Seed "Character Base" by Seliel the Shaper](https://seliel-the-shaper.itch.io/character-base)
39. <https://cupnooble.itch.io/sprout-lands-asset-pack>
40. [Liberated Pixel Cup (LPC) Base Assets (sprites & map tiles)](https://opengameart.org/content/liberated-pixel-cup-lpc-base-assets-sprites-map-tiles)
41. [LPC for Commercial Games](https://lpc.opengameart.org/forumtopic/lpc-for-commercial-games)
42. [Using the art for commercial project?](https://lpc.opengameart.org/forumtopic/using-the-art-for-commercial-project)
43. [Godot 4.7: Stable Release Date, HDR & Key Features](https://ziva.sh/blogs/godot-4-7)
44. [Godot Versions: Latest Stable, Release Dates and Support Status](https://godotawesome.com/godot-versions/)
45. [Godot 4.8 Beta 2 Ships: Feature-Freeze Bug-Fix Release Now Available](https://www.linuxcompatible.org/story/godot-48-beta-2-ships-featurefreeze-bugfix-release-now-available)
46. [Godot 4.8 Beta: What's New, Release Date and What Breaks](https://godotawesome.com/godot-4-8/)
47. [4.8-dev6 regression: Steam Deck built-in controls no longer work in Linux export · Issue #123704 · godotengine/godot · GitHub](https://github.com/godotengine/godot/issues/123704)
48. [C# basics — Godot Engine (stable) documentation in English](https://docs.godotengine.org/en/stable/tutorials/scripting/c_sharp/c_sharp_basics.html)
49. [Exporting for the Web — Godot Engine (latest) documentation in English](https://docs.godotengine.org/en/latest/tutorials/export/exporting_for_web.html)
50. [Unity scraps its 'Runtime Fee' following developer backlash](https://www.developer-tech.com/news/unity-scraps-runtime-fee-following-developer-backlash/)
51. [Unity Runtime Fee Cancelled: The Official Confirmation and Unity Pricing Now](https://app.cinevva.com/news/2024-09-12-unity-runtime-fee-cancelled)
52. [GameMaker Review 2026: 7.7/10, Free to Start](https://makerstack.co/reviews/gamemaker-review/)
53. [GitHub - kyeshmz/steamworks.ts: Steamworks bindings for TypeScript, Node.js and Electron · GitHub](https://github.com/kyeshmz/steamworks.ts)
54. [steamworks-ffi-node: A Steamworks SDK Library for JavaScript Game Frameworks - DEV Community](https://dev.to/arty_prof/steamworks-ffi-node-a-steamworks-sdk-library-for-javascript-game-frameworks-15h1)
55. [For those interested in HTML5 games on Steam, our HTML5 engine Construct has sup...](https://news.ycombinator.com/item?id=17081295)
56. [Desktop Heroes: Shipping an Idle RPG on Steam with Phaser and Electron](https://phaser.io/news/2026/04/desktop-heroes-phaser-electron-steam)
57. [three.js Games on Steam](https://www.summerengine.com/make-great-games/threejs-game-on-steam)
58. [🖥 Desktop](https://www.webgamedev.com/publishing/desktop)
59. [TileMap — Godot Engine (4.3) documentation in English](https://docs.godotengine.org/en/4.3/classes/class_tilemap.html)
60. [Godot 4 TileMapLayer Tutorial](https://codingquests.io/blog/godot-4-tilemaplayer-tutorial)
61. [Linux build inputs break on Steam Deck (but Windows builds work on Steam Deck) - Help - Godot Forum](https://forum.godotengine.org/t/linux-build-inputs-break-on-steam-deck-but-windows-builds-work-on-steam-deck/139250)
62. [Running Godot Games on Steam Deck](https://www.gogogodot.io/running-godot-games-on-steam-deck/)
63. [Steam Inputs - GodotSteam](https://godotsteam.com/tutorials/inputs/)
64. [Steam Deck](https://steamcommunity.com/app/1675200/discussions/0/3269060419628002259)
65. [Steam Deck Verified Review in 2026 - 9 Submission Fails That Still Sink Small-Team Builds](https://gamineai.com/blog/steam-deck-verified-review-2026-submission-fails-small-team-builds)
66. [Dialogue Manager - Godot Asset Store](https://store.godotengine.org/asset/nathanhoad/dialogue-manager/)
67. [Best Godot Dialogue Systems in 2026, Tested and Compared](https://storyflow-editor.com/blog/best-godot-dialogue-systems/)
68. [The release of Godot 4.7 has taken place](https://wnhub.io/news/engines/item-51174)
69. [Game Review: Kynseed](https://novastreamnetwork.com/games/game-review-kynseed/)
70. [Kynseed Game Guide: Complete Overview](https://kynseed.wiki/guides/game-guide/)
