# Content Pack Format Specification

> Version: v0.8 (discussion draft)
> Related docs: `01-technical-approach.md`, `../framework/01-framework-whitepaper.md` §10, `../framework/05-rules-system-framework.md`, `../framework/06-monetization-framework.md`
> Scope: the data format of content packs (campaigns / arcs / sub-games) — directory structure, file schemas, the condition DSL for edges and effects, version and entitlement declarations, validation rules. **This is the contract between content data and the framework runtime.**
> First instance: `../story/campaign01/` (*Ashenport Fragments*); authoring process in `03-content-pack-authoring-guide.md`.
> English mirror of `docs/tech/02-内容包格式规范.md` (change history omitted; §2 subsections reordered numerically). Terms follow `../GLOSSARY.md`.

---

## 1. Pack directory structure

```
<pack_id>/
├── manifest.json      # pack declaration: identity, version, dependencies, mode, entitlement gate (§2)
├── nodes.json         # story node graph: nodes + five edge types (§3, §4)
├── events.json        # L3 quest/event list: trigger, goal, settlement writes (§5)
├── encounters.json    # L4 encounter definitions (§6)
├── items.json         # item table: four identities (§7); the use block for usable items is in `04-resources-and-effects-system.md` §4
├── flags.json         # flag declarations: ledger of writers / readers (§8)
├── characters.json    # characters / companions / NPCs (optional; schema in `04-resources-and-effects-system.md` §2)
├── skills.json        # skill table (optional; same doc §3)
├── effects.json       # effects / modifiers (optional; same doc §5)
├── enemies.json       # enemy table (optional; same doc §1)
├── endings.json       # ending types (campaign packs only) (§9)
├── lore.json          # Compendium Lore entries (§10)
├── maps.json          # region maps and site maps: { "regions": [], "sites": [] } (optional; doc 16 §6)
├── tables.json        # event tables and event cards: { "tables": [], "cards": [] } (optional; doc 16 §4)
└── texts/             # externalised long text (text_ref, see §1.1; reserved for i18n — the locale is the file name)
    └── zh-CN.json
```

Rules: file names are fixed and case-sensitive; the validator warns on unknown files but doesn't reject them (forward compatibility).

### 1.1 texts/ long-text externalisation (the text_ref mechanism)

- **Motivation**: full narrative text for nodes / endings / Compendium isn't embedded in the tables; it's extracted into key-value tables under texts/. Nodes keep only the key (`text_ref`) and a summary. Multiple languages = one file per locale (`zh-CN.json`, `en.json` …); the first version has zh-CN only;
- **File format**: `texts/<locale>.json` = flat `{ "key": "full text" }` (UTF-8, `\n` for paragraphs);
- **Key rules**: `node.<node_id>.text` (node full text) / `ending.<ending_id>.text` (ending cutscene full text) / `lore.<lore_id>` (Compendium entry body);
- **Reference format**: `text_ref: "texts/<locale>.json#<key>"` — before `#` is the relative path inside texts/, after `#` is the key;
- **Resolution order (runtime)**: node display text = the matching `text_variants` variant (pure presentation substitution, §3) → full text from the texts table pointed to by `text_ref` → `summary` fallback; ending cutscene text = `text_ref` → `content` fallback; Compendium body = `text_ref` (no embedded field; a missing key means no body is shown). **A missing key always falls back silently and never rejects loading** — broken links are data defects caught by extraction-completeness assertions in the test layer;
- **Writing discipline**: texts tables only hold text, never structure; full text must not introduce flags or effects not declared in nodes/flags/encounters (semantics must match the node's effects);
- **Operations data** (`packs/_ops`, not a content pack) uses the same convention keys: `ops.<path>` (ops_config.json) and `cosmetics.<path>` (cosmetics.json), with tables in `packs/_ops/texts/<locale>.json`;
- **Convention keys (short text)**: display-text fields (`title`/`summary`/`label`/`name`/`text`/`hint`/`objective`/`content`/`role`/`source`/`lock_text`, etc.) are keyed automatically as "table.entry id.path", with no key fields added to pack JSON — e.g. `nodes.N1-1.edges.0.label`, `items.heal_potion.name`, `encounters.N2G-2.maze.beats.0.text`, `manifest.lock_text`. A target language's `texts/<locale>.json` overrides the source text by writing these keys; a missing key falls back to the source. The single source of truth for the key list is `PackLoader.text_entries()`;
- **Multiple languages (bilingual build)**: write references as locale-independent keys `text_ref: "#<key>"`; the runtime picks `texts/<locale>.json` for the current language (the old form `texts/zh-CN.json#<key>` stays valid; the path is stripped on load). Short text fields (`title` / `summary` / `label` / `name` / `hint` / `objective`) are keyed into the tables too — the data may keep source-language text as a fallback, but every shipped language must have the key;
- **Side-arc packs**: an arc pack can bring its own texts/ files, which are merged into the merged view on grafting; a key collision (same key, different text as the host or an already-injected pack) = a graft error (same rule as V14 namespace independence).

> Implementation status (P4 Phase 1): the loader overlay, `#key` references and V15 are implemented; campaign01 still uses the older `texts/zh-CN.json#…` form, which stays valid.

## 2. manifest.json

| Field | Type | Required | Description |
|---|---|---|---|
| pack_id | string | ✅ | lower snake case; also the Board namespace prefix (whitepaper §4.3) |
| name | string | ✅ | display name (e.g. "Ashenport Fragments") |
| pack_type | enum | ✅ | `campaign` / `arc` / `subgame` |
| pack_version | int | ✅ | monotonically increasing integer |
| min_framework_version | string | ✅ | minimum framework version required (PRD F5.2) |
| rule_pack | object | ✅ | `{ "id": "light", "min_version": 1 }` (doc 05 §5 campaign-level binding) |
| presentation | object | ✅ | mode declaration, see §2.1 |
| namespace | string | ✅ | must equal pack_id (redundant safety check, compared by the validator) |
| recommended_level | [int,int] | campaigns | recommended level range |
| estimated_hours | string | no | estimated length text |
| node_budget | int | campaigns | node budget; the validator checks the actual node count |
| entitlement | object | no | entitlement gate (hard gate), see §2.2; default = follows the base entitlement |
| monetization | object | no | strategy participation declaration (basis for presentation and promo slots), see §2.3; default = follows the base strategy |
| loadout | object | no | loadout configuration (doc 09 §9.1), see §2.4; default = loadout disabled |
| subgame | object | sub-games | variant declaration block, see §2.5 |
| graft | object | arc packs | graft declaration block (only `pack_type: "arc"`), see §2.6 |
| ngplus | object | no (campaigns) | NG+ carry-over block, see §2.7; default = nothing carries over (restart = completely fresh state) |
| start | object | no (campaigns) | Starting configuration, see §2.8; default = 0 gold, no starting items |
| entry | bool | no (campaigns) | Default main campaign when several campaign packs coexist; default = first by folder name |
| lock_text | string | no | Narrative locked-state text for the entry card when the entitlement isn't lit (06 §3.1); default = the framework's generic text |
| source_locale | string | no | Language of the pack's own text; default `zh-CN` |
| locales | string[] | no | Languages this pack promises (including the source); when declared, V15 checks text completeness for each |
| progression | object | no (campaigns) | Framework features unlocked per playthrough: `{ "1": {"split": false, "links": false, "lead": "player"}, … }` (doc 15 §7) — planned, P5 |
| party | object | no | Party-split settings: `{ "max_drift": 1, "link_charges": 2, "max_items": 2 }` (doc 15 §2.4/§5) — planned, P5 |
| travel | object | no | Map travel settings: `{ "watches_per_segment": 4, "default_die": "d6" }` (doc 16 §6) |

### 2.1 presentation (campaign-mode declaration, whitepaper §7.1)

```json
{
  "mode": "choice",
  "forced": { "SL-0": "time", "SL-3": "time" },
  "forced_except": { "SL-3": ["N3-7"] },
  "recommend": { "N4-1": "space" }
}
```

- `mode`: `space` (landscape spatial) / `time` (portrait temporal) / `choice` (dual-mode, the entrance shows a mode branch);
- **`choice` default**: if the player hasn't chosen, default to `time` (narrative flow first, one-hand friendly);
- `forced`: force a form per act (arc ID) — forcing is itself a narrative device; the entrance presents the reason with a narrative wrapper;
- `forced_except`: optional node-level exceptions within an act (key = arc ID, value = array of node IDs) — exempt nodes return to the `mode` resolution. Used for narrative nodes where something "unlocks from here" (e.g. campaign book Act III: landscape unlocks from N3-7 the Blank Plaza); exempt nodes still belong to the act; the graph structure is unchanged;
- `recommend`: node-level recommendation (e.g. landscape recommended for the final boss), not forced.

### 2.2 entitlement (entitlement gate, doc 06 §2)

```json
{ "requires": ["entitlement.campaign01"] }
```

- A list of global entitlement variables on the Board; all must be true to unlock; **default = follows the base entitlement** (free if the base game is premium; under a free-to-play base it depends on operations);
- While locked, the campaign entrance shows the "locked state" (doc 06 §3.1); data loads as usual but can't be entered;
- This is a **hard gate**: the pack only declares "what it needs", never "how to get it" (lighting is operations' job, doc 06 §3.2).
- **Act-level gate (optional)**: an `acts[]` entry in `nodes.json` may declare the same `entitlement: { "requires": [...] }` shape — checked before entering the act's first node; if not lit, the act entrance shows the locked state (doc 06 §3.1); an act already in progress may be finished (doc 06 §5). Used for "free demo chapters + one-time unlock" (doc 06 §7 English-market strategy).

### 2.3 monetization (strategy participation declaration)

```json
{ "strategies": ["dlc", "subscription", "cosmetic"] }
```

- Legal values: `buyout_component` (part of the premium base) / `dlc` / `subscription` / `cosmetic` / `free`;
- Meaning: which strategies this pack **participates in** — used for the entrance locked state, the Home promo slot and the subscription benefits area; the actual gate is always `entitlement.requires`;
- **Consistency check (V9 extension)**: if `strategies` contains `dlc`, `entitlement.requires` is required; if `strategies` is `["free"]`, `requires` must not be declared; a conflict rejects loading;
- Strategy adjustments (e.g. a DLC becoming included in a subscription) are done by operations changing how entitlements are lit — **this field and the gate don't change**, unless the strategy semantics themselves change (e.g. a free pack becomes DLC), in which case the pack version is bumped.

### 2.4 loadout (loadout configuration)

```json
{ "enabled": true, "item_slots": 2, "skill_slots": 2, "respec": false,
  "presets": [
    { "id": "aggressive", "name": "Assault", "skills": ["slash", "inkbolt"], "items": ["heal_potion"] }
  ] }
```

- `enabled`: whether battle encounters go through the Loadout screen before entering; `item_slots`: quick-pouch spaces (11 §8.2); `skill_slots`: the player's prepared-skill limit; `companion_skill_slots` (optional, default -1 = companions always carry all learned signature skills): companions' prepared-skill limit; `respec`: whether loadout allows resetting allocated attribute points;
- `presets` (optional): **system presets** (doc 09 §9.3), shipped with the pack; `skills`/`items` are records of slot choices; after applying one the player can still tweak each slot; **no numeric bonus** (same root as the no-go zones: convenience can be given, power can't be sold). When applying, the skill referenced by the character's `basic_attack` is always carried (tech/04 §2, doesn't take a slot); skills not learned / items not held are skipped with a notice;
- **Whether there are limits, and how many slots, is decided entirely by this config** — the framework only executes it and makes no hard-coded assumptions;
- Declared at campaign level; a single encounter in `encounters.json` can override it with a block of the same name (e.g. tighter slots for a boss);
- Loadout choices are written to the event stream (`loadout.confirm`).

### 2.5 subgame (sub-game declaration block)

```json
{
  "rules_override": { "arena_mode": true },
  "gold_reward": [15, 25, 40],
  "stat_keys": ["wins", "best"]
}
```

- `rules_override`: **object form** (key-value overrides), applied by the rule pack item by item; a string value is treated as a rule-pack ID (whole-pack replacement, backward compatible);
- Extension fields (e.g. `gold_reward` per-fight rewards, `stat_keys` record keys, `clear_as_win` — a combat-free sub-game counts reaching its ending node as 1 win, the record rule for pure-puzzle sub-games) are registered here under §11 "all new fields are optional" and consumed data-driven by the sub-game runner;
- **Reward ownership**: sub-game rewards are written to the pack's own namespace (win/record flags, `arena.xp_earned`, etc.); interoperable rewards such as items/gold go through the effect vocabulary to `global.inv` / `<ns>.gold`; XP flows into the framework-global growth keys `global.growth.*` (tech/04 §8); sub-games may never write another pack's namespace (07 §3);
- Like any content pack, a sub-game can declare its own monetization strategy (§2.3) and loadout config (§2.4).

### 2.6 graft (side-arc graft declaration block)

```json
{
  "into": "campaign01",
  "node": "N1-1",
  "edge": { "type": "item", "item": "half_tide_table", "label": "Follow the Tide Chart", "to": "T-1" }
}
```

- Meaning: an arc pack (`pack_type: "arc"`) **changes no data in the host pack**; it hooks into the main graph with one injected edge — after the host pack loads, the runtime appends `edge` to the out-edges of host node `node` (whitepaper §10.4 content track: side arcs touch only packs/ data + the generic core grafting capability);
- **Visibility**: the injected edge is evaluated like any §4 edge — an `item` edge is hidden without the item (when there's no `fallback`); pack missing / not loaded / entitlement gate not lit (§2.2) = nothing injected, and the host graph is byte-identical to the uninstalled state; uninstalling the pack = removing that arc's injected edges and nodes, restoring the host graph;
- `edge.to` points to a node in **this** pack; the arc's internal nodes may point back to host nodes (converging back to the main line, e.g. returning to `N1-1`);
- **Namespace**: flags without a prefix in the arc's node on_enter / on_complete / edge effects and event settles resolve to the **arc pack's** namespace (07 §3: in-pack flags are writable only by that pack); the injected edge's effects belong to the arc pack as well. The runtime tells sources apart with an `_ns` metadata key carried by nodes/edges (an internal key of the merged view; content authors don't write it);
- Resource reuse: arc encounters may reference the host pack's character/enemy/skill entries directly (resolved in the merged view); the arc's own entry ids must not collide with the host's (V14);
- Arc packs don't declare endings (§9 is campaigns only) — an arc's "ending" is converging back to the main line, and it doesn't affect the host's ending conditions.

### 2.7 ngplus (NG+ carry-over block, campaigns only)

```json
{
  "carries": {
    "lore": true,
    "entitlements": true,
    "cosmetics": true,
    "codex_fragment": 1,
    "playthrough": "campaign01.ngplus"
  },
  "per_ending": {
    "E1": { "flags": ["unlock_elysium_rumor"] },
    "E2": { "flags": ["unlock_wastes_rumor"] },
    "E3": { "flags": ["unlock_scribe_identity"], "dice_skin": "scribe_dice" },
    "E4": { "flags": ["ngplus_memory_view"], "codex_fragment": 1 }
  }
}
```

- Source of meaning: campaign book §11 NG+ carry-over list (balance principle: carry over "narrative position and collections", never power — same philosophy as the no-go zones); this block is the only basis for carry-over, consumed data-driven at runtime; code never hard-codes any campaign's carry-over content;
- `carries` (common carry-over; boolean keys enable with true):
  - `lore`: keep the whole `global.lore` Compendium set;
  - `entitlements`: keep all `global.entitlement.*` (system-write only, 07 §3; acquired entitlements never downgrade, whitepaper §10.4);
  - `cosmetics`: keep all `global.cosmetic.*` (07 §3 v1.2; acquired cosmetics never downgrade);
  - `codex_fragment`: how many Weaver's Fragments carry over (int);
  - `playthrough`: the full key (with namespace) of the playthrough counter; new playthrough = old value + 1 (data source for meta.ngplus/playthrough, 07 §4.1);
- `per_ending` (unlocks per ending): key = ending ID in endings.json; triggered by **the ending just reached** (the `<ns>.ending_<eid lowercase>` flag on the old Board, written by the §9 ending node's on_enter); past endings don't accumulate — skins/entitlements already granted persist via `carries`, while narrative flags apply only to the playthrough that immediately follows;
  - `flags`: flags in this pack's namespace written to the new Board (value true; prefix omitted, as in §4.6);
  - `codex_fragment`: extra fragments on top of the common count (e.g. E4 Remembrance gives one more);
  - `dice_skin`: the dice-skin ID granted; must be registered in the operations registry `_ops/cosmetics.json` (06 §7; granting writes `global.cosmetic.owned.*` with provenance granted_by=ngplus; pure presentation, never numeric);
- **Not carried over**: growth (global.growth.*) / Doom Clock / alignment / reputation / loot / the ending flags themselves (rewritten at the end of each playthrough); anything not listed in this block is reset;
- Where the presentation differences land: flags written by `per_ending.flags` are consumed by node `text_variants` (§3) for pure presentation differences such as an alternative opening monologue or a prologue filter; they never enter graph traversal or event-stream resolution.

### 2.8 start (starting configuration, campaigns only)

```json
{ "gold": 30, "items": [ { "item": "heal_potion", "n": 2 } ] }
```

- `gold`: starting gold, written to `<pack_id>.gold` (07 §2 currency clause); idempotent (an existing value isn't overwritten);
- `items`: items brought in at the start (narratively fixed, e.g. supplies carried into the Prologue); must be registered in items.json;
- The framework hard-codes no pack's economy — changing the start is a one-line data change.

## 3. nodes.json: nodes

```json
{
  "acts": [
    { "id": "SL-0", "title": "Tidewake", "mode": "forced_time", "role": "tutorial" }
  ],
  "nodes": [
    {
      "id": "N0-2",
      "act": "SL-0",
      "type": "check",
      "title": "The Vanished Pier Name",
      "summary": "Check tutorial: make out the pier name as it fades",
      "on_enter": [],
      "edges": [ "…see §4…" ]
    }
  ]
}
```

| Field | Type | Required | Description |
|---|---|---|---|
| id | string | ✅ | unique within the pack; reuses the campaign-book numbering (N0-1 / R3 / N2S-2 …) for easy cross-reference |
| act | string | ✅ | the arc (act) ID it belongs to; must exist in acts |
| type | enum | ✅ | `scene` (cutscene) / `hub` / `check` / `battle` / `dialog` / `explore` / `rest` / `branch` / `ending`; `map` (enter a region map: `"map": "<id>"`, doc 16) and `site` (enter a site map: `"site": "<id>"`); planned (P5.3): `rejoin` (party-split convergence, doc 15 §2.3) |
| title / summary | string | ✅ | display text; `summary` is also the fallback when full text is missing and the summary for lists/recaps |
| text_ref | string | no | external long-text reference (§1.1): `"texts/<locale>.json#node.<id>.text"`; resolution text_variants → text_ref → summary |
| encounter | string | conditional | the encounter ID in encounters.json (required for battle / maze / rest nodes) |
| on_enter | effect[] | no | effects resolved on entering the node (write flags, push the clock …), DSL in §4.6 |
| on_complete | effect[] | no | resolved after all edges of the node are settled, before leaving (e.g. both choice edges at N2S-3 grant the Signet) |
| text_variants | array | no | text variants (flag-driven display text substitution): `[{ "flag": "<flag_id>", "text": "…" }]` — by default (replace), the first variant whose flag holds, in declaration order, replaces the text; with `"mode": "append"`, a holding flag appends a paragraph after the text (several can stack — good for "one line of echo from an earlier choice" without copying the whole passage). `flag` without a prefix resolves to this pack's namespace. **Pure presentation**: never enters graph traversal, checks or event-stream resolution (where NG+ opening monologues / Remembrance filters land, §2.7 and campaign book §11) |
| edges | edge[] | ✅ | out-edges; may be empty for finale nodes |

Any edge type can carry a `label` (display text) and `requires` (extra gate condition, §4.6).

## 4. Edges and the condition DSL

The five design edge types (whitepaper §5.1) compile into one **condition + target + effects** structure; `type` is a semantic tag for UI presentation and validator classification; the runtime only evaluates conditions.

### 4.1 Choice edge `choice`

```json
{ "type": "choice", "label": "Give up a piece of your own memory", "to": "N2-C",
  "effects": [ { "write": "blank_memory", "value": true }, { "clock": -2 } ] }
```

### 4.2 Check edge `check`

```json
{ "type": "check", "skill": "perception", "difficulty": "easy",
  "success": "N0-3a", "failure": "N0-3b",
  "success_effects": [ { "write": "seen_fading", "value": true } ],
  "failure_effects": [ { "xp": 50 } ] }
```

- `skill`: skill name; legal values are defined by the bound rule pack (Light: the skill table derived from the three attributes);
- `difficulty`: three tiers `easy / medium / hard` (Light rules);
- `alt_pass`: an optional alternative way to pass (e.g. `{ "pay_gold": 200 }`, matching the design's "check or pay gold");
- Success and failure may point to the same node; then the difference must be in `success_effects` / `failure_effects` (e.g. N2S-1 failure costs 1 clock segment);
- **Hard validation rule**: `failure` is required — "failure is a branch" (whitepaper §5.2); the validator rejects check edges without a failure path.

### 4.3 Item edge `item`

```json
{ "type": "item", "item": "half_tide_table", "to": "N2G-2b", "fallback": "N2G-3" }
```

If the item is held the edge appears and leads to `to`; otherwise it goes to `fallback` (omit = the edge stays hidden).

### 4.4 Time edge `doom_clock`

```json
{ "type": "doom_clock", "at": 2, "to": "N1-7", "once": true }
```

Fires automatically when the Doom Clock (`global.doom_clock` or a declared local clock) reaches the segment; `once` prevents re-firing.

### 4.5 Reputation / alignment edge `reputation`

```json
{ "type": "reputation",
  "requires": { "rep.scriptorium": { "<=": 0 }, "rep.uninked": { "<=": 0 }, "rep.salvage": { "<=": 0 } },
  "to": "N2L-1" }
```

An invisible gate; the option appears only when the condition holds.

### 4.6 Common condition and effect vocabulary

Conditions (usable in `requires` and ending conditions):

| Key | Value form | Meaning |
|---|---|---|
| `flag.<id>` | bool | flag (in-pack flags omit the prefix and resolve to this pack's namespace) |
| `rep.<faction>` | `{ ">=": n }` etc. | reputation threshold |
| `clock` | `{ ">=": n }` | Epic clock segments (`global.doom_clock`) |
| `clock.<id>` | `{ ">=": n }` | local clock segments (resolves to `<ns>.clock.<id>`) |
| `item.<item_id>` | bool or `{ ">=": n }` | held / quantity held |
| `alignment` | `{ "ink_gt": 50 }` / `{ "blank_gt": 50 }` | alignment axis (Inkbound / Blankward past the midline) |
| `bond.<npc>` | `{ ">=": n }` | a specific companion's Bond |
| `bond_max` | `{ ">=": n }` | any companion's Bond (common in ending conditions) |
| `all` / `any` | array of conditions | combination |

Effects (usable in `effects` / `on_enter` / settlement):

| Key | Meaning |
|---|---|
| `write` + `value` | write a flag |
| `clock` / `clock.<id>` | Epic / local clock change (negative = delay) |
| `rep.<faction>` | reputation change |
| `alignment` | alignment slide |
| `give_item` / `remove_item` | item change |
| `xp` | experience |
| `inspiration` | Inspiration change (11 §3.2; `<ns>.inspiration` bookkeeping, clamped 0–1) |
| `gold` | gold change in this pack's namespace (`<ns>.gold` counter, 07 §2 currency clause; negative deducts, clamps at 0; same precedent as campaign01.gold / arena.gold; not in the flags.json ledger) |
| `bond.<npc>` | Bond change |
| `lore` | unlock a Compendium entry (writes to the `global.lore` set and emits a `lore.unlock` event, doc 07 §2) |

### 4.7 Planned edge types (P5)

| Edge | Spec | Summary |
|---|---|---|
| `split` | doc 15 §2.1 | Divide the party into groups, each entering its own thread; `rejoin` node; `linear_fallback` when splitting isn't unlocked |
| `remote` | doc 15 §5.1 | An action in one thread that affects another thread (`target_thread`), costing link charges |

Planned conditions (doc 15 §2.2): `in_group`, `group_size`, `thread`. Map effects (doc 16 §6, implemented): `reveal` (`"<map>.<location>"`), `watch` (watches toward the Doom Clock); nested rolls use a table row's `"outcome": {"table": …}`. Existing effect `inspiration` (doc 11 §3.2).

## 5. events.json (L3 quests/events)

```json
{
  "id": "ink_rain_raid",
  "name": "Ink-Rain Night Raid",
  "trigger": { "type": "doom_clock", "at": 2 },
  "objective": "Win N1-7 Midnight Ink Rain",
  "node": "N1-7",
  "settle": [ { "xp": 200 }, { "give_item": "ink_core" } ]
}
```

`trigger.type`: `auto` (with the node) / `choice` (a player-chosen chain) / `doom_clock` / `reputation` / `hidden` (hidden condition, e.g. the lone-wolf shortcut).

## 6. encounters.json (L4 encounters)

| Field | Type | Description |
|---|---|---|
| id | string | suggested to match the node (`N1-7`); several encounters at one node get a suffix (`R4-r`) |
| type | enum | `battle` / `escort` / `maze` / `rest` / `hybrid` (battle + choice) |
| mode | enum | `inherit` (follows campaign mode) / `forced_time` (forced portrait) |
| difficulty | enum | `easy` / `medium` / `hard` (Light rules three tiers) |
| max_units | int | on-screen unit cap; the validator forces ≤8 for `forced_time` encounters (doc 04 §④.4) |
| party | array | optional, the party instances: `[{ "id": "pc", "ref": "player_blank" }]`; `ref` points to a characters.json entry, `id` is this encounter's instance id (unit identifier in the event stream); default = the bootstrap layer doesn't auto-assemble a party |
| enemies | array | optional, enemy instances: `[{ "id": "boss", "ref": "ink_fiend" }]`; `ref` points to an enemies.json entry; the same `ref` may have several instances (distinct `id`s); a boss's area skills (with `save` declarations) are mounted on the enemies.json entry |
| pos | object | optional, initial tactical-grid placement (e.g. `{ "allies": [[2,4]], "enemies": [[3,1]] }`); **when omitted, the rendering layer places units deterministically by side + initiative order** — placement is pure presentation and doesn't enter the event stream |
| party_advantage | object | optional, an advantage-source declaration (doc 11 §3.1: sources are declared by content packs): `{ "flag": "witnessed_revocation", "rounds": 1 }` — while the flag holds, the whole party has attack advantage for `rounds` rounds |
| enemy_weaken | object | optional, a conditional enemy-weakening declaration (flag-driven modifier symmetric with party_advantage): `{ "flag": "mercy_shown", "attack_mod": -2 }` — while the flag holds, every enemy instance's attack modifier gets `attack_mod` (negative = easier); `flag` without a prefix resolves to this pack's namespace. Used for "past choices make a boss easier" (e.g. campaign book §5: showed_mercy → the tax collector's testimony at N4-1) |
| escort | object | required for `escort`: the escort target: `{ "unit": {…}, "survive_rounds": 3, "failure_effects": […] }`. `unit` is an inline friendly NPC entry (same fields as an enemies.json entry: id/name/hp/ac/attrs/attack_mod/damage), joining with `kind=escort_npc`: takes no turn, can't be commanded, HP doesn't persist across encounters. Win/lose per doc 11 §5 "objective defined by the encounter": the escort survives `survive_rounds` full rounds **or** all enemies are wiped out = win; escort HP reaches 0 = **objective failed** (`objective_failed`, a time penalty instead of a wipe) — battle ends immediately, no loot/XP, `failure_effects` (effect DSL §4.6) are written, and the node's single out-edge is still taken (failure is a branch, doc 08 §2). Enemy melee intent prefers the escort (interrupting the rite); area effects hit the whole party as usual |
| maze | object | required for `maze`: an exploration sequence: `{ "beats": […] }` (a serialised presentation of the doc 04 §④.3 room types; a full grid maze is left for later). 2–3 beats, each one of: `{ "type": "check", "skill", "difficulty", "text", "success_effects"?, "failure_effects"? }` (check room; modifier = player attribute + proficiency, doc 11 §2/§3); `{ "type": "loot", "item", "n"?, "text" }` (pickup room; `item` must be registered in items.json, V11); `{ "type": "ambush", "skill", "difficulty", "enemy"?, "text", "failure_effects"? }` (ambush check: failing applies `failure_effects`; `enemy` is a presentation-only enemy reference and must be registered, V11). Check/ambush beats may declare `"retry_on_fail": true` + `"hint": "…"` (**puzzle-room semantics**: a failed check doesn't advance the beat or apply `failure_effects`; it shows the hint and retries in place — how pure puzzle sequences "give a hint and retry, never a dead end"; default false = apply failure effects and advance). Beat effects use the effect DSL (§4.6) and are part of the V4/V5/V11/V12 validation loop; once the sequence completes, the node's out-edges are shown |
| loot | array | optional, victory loot: `[{ "item": "ink_core", "n": 1 }]`; `item` must be registered in items.json (V11) |
| xp | int | optional, victory XP (input to the doc 11 §6 growth table) |
| gold | int | optional, victory gold (doc 11 §7.3): added to `<ns>.gold` on victory and read out at settle; launch tuning `xp ÷ 5` |
| note | string | design note (pointer to boss mechanics, etc.; numbers follow the Light rule pack) |

## 7. items.json

| Field | Description |
|---|---|
| id / name | stable ASCII ID + display name (currently Chinese) |
| roles | array of the four identity tags: `stat` (numeric) / `check_mod` (check modifier) / `branch_key` (branch key) / `codex` (Compendium); multiple allowed (whitepaper §8) |
| source | where it's placed (node / shop / boss loot / NG+ carry-over) |
| unlocks | edges or endings it opens (required for branch keys; used by the validator and the item-detail hint) |

## 8. flags.json

```json
{
  "id": "seen_fading",
  "name": "Seeing Is Believing",
  "type": "bool",
  "default": false,
  "writers": ["N0-3a"],
  "readers": ["R2", "history_scroll"]
}
```

The flag ledger is the input to the **closed-loop flag check**: declared writers/readers are compared with the actual reads and writes in nodes.json — every write must have a read and every read must have a write (the tooling of campaign book §10). Global variables (`global.doom_clock`, `rep.*`, `alignment`, `bond.*`) aren't declared here; they belong to the framework layer.

> Implementation status (code review M3): packlint currently only WARNs here, and five campaign01 flags are in that state; the V4 rule above is the target.

## 9. endings.json

```json
{
  "id": "E3",
  "title": "A New Page",
  "hidden": true,
  "conditions": { "all": [ { "item.codex_fragment": { ">=": 4 } }, { "any": [ { "bond.*": { ">=": 60 } } ] } ] },
  "content": "The Unwritten becomes the new Penbearer",
  "ngplus_hook": "Unlocks the Penbearer starting origin"
}
```

Ending conditions use the §4.6 condition DSL; `default: true` marks the fallback failure-but-not-final ending (E4).

Optional field `text_variants` (same semantics as §3, including `append`): flag-driven ending text differences (e.g. campaign book §5 "blank_memory → E1 cutscene variation").

Optional field `text_ref` (§1.1): reference to the full ending cutscene text (`"texts/<locale>.json#ending.<id>.text"`); resolution text_ref → `content` fallback — `content` stays as a one-line summary / fallback, and the ending screen shows the full text (campaign book §9 cutscene + epilogue).

## 10. lore.json

Compendium entries belong to one of the four world series (`weaver_fragments` Weaver's Fragments / `revoked_registry` Register of the Revoked / `fatedie_study` Treatise on the Fatedie / `ashenport_local` Ashenport Gazetteer); each entry declares the node that unlocks it. Series completion rewards are defined at the world layer; packs only contribute entries.

Optional field `text_ref` (§1.1): reference to the entry body (`"texts/<locale>.json#lore.<id>"`); tapping an unlocked entry on the Compendium page shows the body; there's no embedded body field, so a missing key shows only the title/source.

Optional field `art_ref` (tech/05 §6): reference to the entry's illustration (`"<category dir>/<id>"`; Compendium art goes in `icons/` or `scenes/`); a pure presentation reference — a missing file falls back silently without rejecting loading.

## 11. Versioning and compatibility

- Three-way version decoupling: framework / content pack / rule pack each increment on their own; a pack declares only `min_framework_version` and `rule_pack.min_version`;
- Pack upgrades must stay backward compatible with saves in progress: deleting a node is only allowed when "no save can reach that node" (validator check);
- Schema evolution: all new fields are optional; changing a required field = a major schema version + a migrator.

## 12. Go-live validation checklist (automated; whitepaper §10.3 and campaign book §10)

| # | Check | Rule |
|---|---|---|
| V1 | No dead ends | Every non-ending node has out-edges; every path can reach some ending |
| V2 | No unreachable nodes | Full graph traversal from the prologue entrance |
| V3 | Complete failure paths | Every `check` edge has a `failure`, and the failure path has content (not a direct merge into an empty node) |
| V4 | Closed flag loops | The flags.json ledger matches the graph's reads/writes; no orphan flags (reads collected from `flag.*` conditions, encounter-level party_advantage/enemy_weaken declarations, and node/ending `text_variants`); **a declared reader that is a graph node or ending, with no read anywhere in the graph or endings = FAIL**; readers that are only UI / NG+ surfaces stay WARN for manual review |
| V5 | Bounded clocks | The algebraic sum of all `clock` effects provably converges within 0–10; an E4 fallback exists |
| V6 | Node budget | Logical nodes counted by main number (derived suffix nodes like `N1-2b` and ending nodes don't count) ≤ manifest.node_budget |
| V7 | Namespaces | In-pack references don't leave the pack prefix (globals via the whitelist); multiple packs coexist without collisions |
| V8 | Portrait constraint | `forced_time` encounters have `max_units` ≤8 |
| V9 | Entitlement and strategy declarations | Entitlements referenced by `entitlement.requires` are registered; `monetization.strategies` is consistent with `requires` (§2.3) |
| V10 | Screen loop | A new node type doesn't break the nine-screen entrance/exit check (doc 04 §5) |
| V11–V13 | Resource references / legal values / use counts | See `04-resources-and-effects-system.md` §6 |
| V14 | Graft | Arc packs: the `graft.into` target pack loads, `graft.node` exists in it, the injected edge type is legal and `to` points to a node in this pack, an `item` edge's item is registered in the merged view; namespace independence — this pack's node/event/encounter/item/lore ids don't collide with the target pack. Arc-pack lint runs graph traversal (V1–V3) and resource references (V11) on the **merged view** (host + graft injection); flags / clocks / budget / entitlements are checked per this pack |
| V16–V18 | Party split (planned, P5) | Thread integrity, group-battle unit caps, progression fallbacks (doc 15 §9) |
| V19–V21 | Maps and tables | Map connectivity, table die coverage, outcome references (doc 16 §7) |
| V15 | Text completeness | For every language in manifest `locales`: every text key (with non-empty source text) exists and is non-empty in `texts/<locale>.json`; the source language's text_ref keys must exist. To list untranslated keys: `tools/text_extract.gd` |
