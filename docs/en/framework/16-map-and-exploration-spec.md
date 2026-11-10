# 16 · Maps, Travel and Event Tables — Spec

> Status: **implemented** (TASKS P5.2, 2026-11-10) — code: `core/explore/` (`EventTables`, `RegionMap`, `SiteMap`), `map_flow.gd` (`MapFlow`), `shell/ui/screen_map.gd` (`ScreenMap`); demo content: campaign01 **The Fog Coast** (optional detour from the Free City Plaza hub). Not yet built: maze beats as site presets (§3.2; maze beats keep working as before) and key-tier table presentation (tables use the dice tray). Related: whitepaper §5/§7, doc 04 (screens), doc 08 (edges), doc 09 (forms), doc 11 (rules), doc 15 (party split), doc 17 (dice), tech/02 (pack format).

The tabletop loop this spec delivers: **look at the map → choose where to go and how → roll → something happens because of the roll → the world (and the map) changes.** It generalises today's exploration pieces — the hub, the room progress bar, the maze beats (`encounters.json` `maze`) and the Doom Clock — into one map system that any content pack can use.

## 1. Three scales

| Scale | What it is | Player decisions | Typical rolls |
|---|---|---|---|
| **Region map** (overworld) | Locations joined by routes — a *point-crawl* | Destination, route, travel pace, when to camp | Navigation check, random-encounter roll, weather / event table |
| **Site map** (town, dungeon, ship, ruin) | Areas or rooms joined by doors and passages | Which door, search or not, sneak or rush, rest here or move on | Search / trap / stealth checks, room-event tables |
| **Encounter** | The tactical battle (existing, doc 09) | Positioning, actions | Attacks, saves, damage |

A map is **spatial navigation on top of the story graph**, never a replacement for it: arriving at a location enters a story node (or an encounter), and the story graph stays the source of truth for narrative and branching.

## 2. Region map

### 2.1 Elements

- **Location**: `{id, name, pos, node, icon, hidden?, requires?}` — `node` is the story node entered on arrival (a hub, a scene, a site map, a battle);
- **Route**: `{from, to, legs, terrain, danger, requires?}` — `legs` = travel length in watches; `terrain` (road / wild / sea / ink-fog) picks the event table; `danger` (0–3) scales encounter chances;
- **Fog**: hidden locations and routes appear when revealed by a rumor, a map item, a flag, or by arriving next to them (`reveal` effects).

### 2.2 Travel turn (one watch per leg)

For each leg the framework runs the same **choose → roll → outcome** loop:

1. **Pace** (chosen once per journey): *Fast* (−1 watch per 2 legs, no Perception, disadvantage on navigation), *Normal*, *Careful* (+1 watch per 2 legs, advantage on spotting ambushes, can forage);
2. **Navigation check** (wilderness only): the group's navigator rolls d20 + Wits (+ proficiency in Perception/Survival-like skills declared by the rule pack) vs the route's DC; failure = **lost** (+1 watch and a roll on the *lost* table — failure is a branch, doc 08 §2);
3. **Event roll**: roll the route's **die** (d6 by default; d8/d12/d20 per table) on the terrain table (§4). Results range from nothing, to a discovery, to a hazard, to an encounter;
4. **Time**: every `watches_per_segment` watches (manifest, default 4) advance the **Doom Clock** by 1. Travel is how time pressure becomes geography.

Camping on the map = the camp sheet (short/long rest, doc 11 §7.2) — a long rest in the wild also rolls once on the route's **night table**.

### 2.3 Region-map screen (⑩, both forms)

Landscape:
```
┌────────────────────────────────────────────┬──────────────┐
│                                            │ Location card│
│   Region map (pan / pinch)                 │ Ashenport    │
│   ● known  ◌ rumored  ▲ party  ⚑ quest      │ Fog Wharf …  │
│   ───── route (danger tint)                │ Route: 2 legs│
│                                            │ Danger ●●○   │
│                                            │ Pace [F|N|C] │
│                                            │ [Travel] [Camp]
├────────────────────────────────────────────┴──────────────┤
│ d20 / d6  last roll …      Clock 4 → 5 ⚠      Log ▸        │
└───────────────────────────────────────────────────────────┘
```
Portrait:
```
┌──────────────────────────────┐
│ Clock 4 → 5 ⚠   Party ▸      │
├──────────────────────────────┤
│ Region map (vertical scroll; │
│ pinch to zoom; tap a pin)    │
│      ◌ Lighthouse            │
│      │                       │
│  ▲ Ashenport ── ● Fog Wharf  │
├──────────────────────────────┤
│ d6  last roll …              │ ← dice strip
│ Fog Wharf · 2 legs · ●●○     │ ← destination card
│ Pace: Fast | Normal | Careful│
│ [ Travel ]       [ Camp ]    │
└──────────────────────────────┘
```

- Tap a pin = select destination (route highlights); **drag the party token along a route** = choose that route (two channels, doc 12 §1);
- During travel the token moves leg by leg; each event roll shows its die in the dice strip (quick) or full screen (key tables, doc 17 §3);
- With a split party (doc 15) each group has its own token; the focused group's token is bright.

## 3. Site map

A site is a set of **areas** joined by **passages** (doors, stairs, gaps, secret doors). It is presented in the campaign's form:

| Form | Presentation |
|---|---|
| **Time (portrait)** | The existing **room sequence** (doc 04 §④.2): progress bar of rooms, door previews with type icons and danger tint, split doors for branches. Area = room. |
| **Space (landscape)** | A **top-down area map** with fog of war: areas are polygons/tiles on one canvas; the party token moves area to area; doors and features are tappable; the tactical battle opens in place when an encounter triggers. |

Landscape site map:
```
┌──────────┬───────────────────────────────────┬─────────────┐
│ Party    │  ░░░░░░  fog                      │ Area card   │
│ HP / AC  │  ┌────┐  ┌──────┐  ░░░░           │ Flooded     │
│ ▲ token  │  │ A2 ├──┤ A3 ▲ ├──🔒─ A4 ░░       │ Scriptorium │
│          │  └────┘  └──┬───┘                 │ • Search    │
│ [Camp]   │             ╎ (secret?)           │   the desk  │
│          │           ░░░░                     │ • Pull lever│
├──────────┴───────────────────────────────────┴─────────────┤
│ d20  last roll …        Clock 4 → 5 ⚠        Log ▸          │
└────────────────────────────────────────────────────────────┘
```
Portrait site map (as built): a compact area map above the room card — entered rooms filled, rooms seen through a door shown dashed with "?", the current room outlined in gold — and the room's features and doors as buttons in the thumb zone (with check tags such as "Athletics · Medium · DC 12"). It reads as a room sequence while keeping the layout of the place visible; the room progress bar of doc 04 §④.2 remains the presentation for maze beats.

### 3.1 Area

```json
{ "id": "A3", "name": "Flooded Scriptorium", "pos": [4, 2],
  "on_enter": { "table": "scriptorium_room", "once": true },
  "features": [
    { "id": "desk", "label": "Search the drowned desk", "check": { "skill": "investigation", "difficulty": "medium" },
      "success": [ { "give_item": "codex_fragment" } ], "failure": [ { "clock": 1 } ] },
    { "id": "lever", "label": "Pull the tide lever", "remote": true, "effects": [ { "write": "gate_open", "value": true } ] }
  ],
  "exits": [ { "to": "A4", "door": "locked", "key": "tide_key", "pick": { "skill": "thievery", "difficulty": "hard" } },
             { "to": "A2" } ],
  "encounter": "N2G-2b" }
```

- **Features** are the tabletop "I search the desk" moments: a check, an item use, or a free action; each writes effects;
- **Doors**: open / locked (key item or check) / stuck (Might check, noise roll on failure) / secret (revealed by a search success or a flag) / one-way;
- **Noise and wandering monsters**: failed forced doors and long rests in a site roll the site's *wandering* table;
- **Light** (optional per site): dark areas give disadvantage on searches without a light source item.

### 3.2 Relationship to maze beats

Today's maze beats (check / loot / ambush) become **area presets**: a beat sequence is a linear site whose areas each hold one feature. Existing packs keep working unchanged; new packs use sites.

## 4. Event tables (choose → roll → outcome)

### 4.1 Format (`tables.json`)

```json
{ "id": "fogroad_travel", "die": "d8",
  "rows": [
    { "range": "1",   "label": "Ink-fog ambush",      "outcome": { "encounter": "fog_ambush" } },
    { "range": "2-3", "label": "Lost in the fog",     "outcome": { "check": { "skill": "perception", "difficulty": "medium" },
                                                                    "failure": [ { "watch": 1 } ] } },
    { "range": "4-6", "label": "Quiet road",          "outcome": {} },
    { "range": "7",   "label": "Drowned courier",     "outcome": { "event": "courier_satchel" } },
    { "range": "8",   "label": "Roll on rare finds",  "outcome": { "table": "rare_finds" } }
  ],
  "modifiers": [ { "when": { "pace": "careful" }, "add": 1 }, { "when": { "clock": { ">=": 6 } }, "add": -2 } ] }
```

- `die`: d4 / d6 / d8 / d10 / d12 / d20 / d100 (doc 17); `range` covers every face exactly once (validator);
- `outcome` may be: **effects** (the existing effect DSL), an **encounter**, a **check** with success/failure effects (failure is a branch), an **event card** (§4.2), a **node** to enter, or another **table** (nested rolls);
- `modifiers` shift the roll from state (pace, Doom Clock, reputation, items held) — the world's condition shows up in what happens on the road;
- `once` rows (`"once": true`) can be consumed (a unique find happens only once; the row then falls through to `instead`).

### 4.2 Event cards

An event card is a small choice-and-roll scene that doesn't need its own story node:

```json
{ "id": "courier_satchel", "title": "A drowned courier",
  "text_ref": "texts/en.json#event.courier_satchel",
  "options": [
    { "label": "Search the satchel",  "check": { "skill": "investigation", "difficulty": "easy" },
      "success": [ { "give_item": "half_tide_table" } ], "failure": [ { "clock": 1 } ] },
    { "label": "Say a word for the dead", "effects": [ { "inspiration": 1 } ] },
    { "label": "Leave it", "effects": [] } ] }
```

Event cards appear as a half-screen sheet over the map (both forms) with the option list in the console and the dice in the dice strip:
```
┌──────────────────────────────┐
│ (map, dimmed)                │
├──────────────────────────────┤
│ A drowned courier            │ ← event card (half-screen sheet)
│ Salt-stiff boots, a satchel… │
├──────────────────────────────┤
│ d8 → 7  "Drowned courier"    │ ← the table roll that led here
│ ○ Search the satchel  (Investigation · Easy · DC 8 · +2) │
│ ○ Say a word for the dead  (✦ Inspiration)               │
│ ○ Leave it                   │
└──────────────────────────────┘
```

## 5. Board state

| Key | Content |
|---|---|
| `<ns>.map.<map_id>.pos` | Current location (or `{group: location}` when split) |
| `<ns>.map.<map_id>.seen` | Set of revealed locations / routes |
| `<ns>.map.<map_id>.visited` | Set of visited locations |
| `<ns>.site.<site_id>.area` | Current area; `.cleared`, `.opened`, `.searched` sets |
| `<ns>.table.<table_id>.used` | Consumed `once` rows |
| `<ns>.watch` | Watches elapsed toward the next Doom Clock segment |

All bookkeeping keys, written with provenance; the History Scroll shows the rolls and outcomes as ordinary events (`map.travel`, `table.roll`, `site.enter`, `feature.use`).

## 6. Content format (tech/02 additions)

- `maps.json`: region maps `{id, name, background?, locations[], routes[], start}` and sites `{id, name, background?, form_hint?, areas[], start, wandering_table?}`;
- **`background`** (implemented, P6.4): `{ "art_ref": "scenes/<id>", "frame": [x0, y0, x1, y1], "tier"?: 1080 }` — an illustration laid under the map. `frame` is the **grid rectangle the image covers**, so the image is drawn with the same transform as the locations / areas and its landmarks sit under them; author the image at the frame's aspect ratio (Fog Coast `[0,0,8,6]` → 1080×810). `frame` defaults to the bounding box of all points plus one grid unit. With a background, routes get a dark under-stroke and site area boxes turn semi-transparent; without the file the procedural plain map is drawn (silent fallback). File: `game/assets/art/scenes/scene_<id>_<tier>.png`;
- `tables.json`: `{ "tables": [ … §4.1 … ], "cards": [ … §4.2 … ] }` — event tables and event cards live together (cards are not L3 quests, so they stay out of `events.json`);
- New node type `map` (enters a region map) and `site` (enters a site map); new effects `reveal`, `watch`, `table`;
- Manifest `travel`: `{ "watches_per_segment": 4, "default_die": "d6" }`.

## 7. Validation (packlint)

- **V19 map connectivity**: every location reachable from `start` (allowing reveals); every route endpoint exists; no orphan site areas; `background.art_ref` is `scenes/<id>` and `frame` is `[x0, y0, x1, y1]` with x1>x0, y1>y0 (FAIL); a point outside the frame or a missing image file is a WARN;
- **V20 table coverage**: ranges cover each face of the die exactly once; nested tables exist; no cycles without a `once` exit;
- **V21 outcome references**: encounters / events / nodes / items referenced by tables, features and doors are registered;
- Existing V8 (unit caps per form) applies to encounters triggered from maps.

## 8. Interaction rules

- Two channels everywhere (doc 12 §1): tap a pin / door / feature or drag the token onto it;
- Long-press a location, route or door = info card (danger, known table, last visit);
- Every roll is visible: the die type, the modifiers and the table row it hit are shown in the log ("d8: 2 +1 (careful) = 3 → Lost in the fog");
- Map screens keep the hot-zone rule (doc 12 §6): confirm buttons in the lower thumb arc; the map itself is a free pan/zoom surface.

## 8.1 As built (notes for authors)

- **Travel is one leg per press** ("Travel" / "Continue the journey"): each leg adds a watch, rolls navigation on wild/fog terrain (careful = advantage, fast = disadvantage; failure = the leg is lost) and rolls the route's table (`route.table`, else `map.tables[terrain]`); 4 watches advance the Doom Clock and re-check time edges;
- An encounter or event card interrupts the journey; the journey is kept on the Board and continues on the next press. A battle from a map returns to the map whatever the result (HP persists, minimum 1);
- Arriving next to a location reveals it unless it is `secret`; `hidden` routes are only revealed through `reveal` effects;
- Locations need a `node` (story node entered on arrival; give it an edge back to the map node) or a `site`; tapping "Enter: <here>" with no destination re-enters the current location;
- Sites: features are one-shot by default (`"once": false` to allow repeats); a `stuck` door's failed force rolls the site's `wandering_table`; a `locked` door opens with its `key` item or a `pick` check; `secret` doors appear after a feature with `reveal_exit` succeeds; `"to": "@map"` leaves the site;
- Map nodes count their locations' nodes as reachable for packlint V1/V2.

## 9. Acceptance (summary)

- A pack can declare a region map with ≥5 locations, ≥2 hidden, and travel between them with pace choice, navigation checks, table rolls and Doom Clock cost;
- A site map plays as a room sequence in portrait and as a fogged area map in landscape from the **same data**;
- Tables with d6/d8/d12/d20/d100 resolve correctly, apply modifiers, consume `once` rows, and show the right die (doc 17);
- Event cards resolve choices and checks with failure branches; everything is traceable in the History Scroll.
