# Game Framework Whitepaper

> Version: v1.1 (frozen; v1.1 adds §10.4 dual-track iteration and §12.2 per-pack strategy choice)
> Status: **framework design frozen** (M0 exit). Further changes are reviewed against this document and recorded in version control.
> Companion specs: `07-world-state-machine-spec.md`, `08-branching-model-spec.md`, `09-encounter-and-dual-mode-spec.md`, `10-items-and-compendium-spec.md`, `11-light-rulepack-v1.md`; technical implementation in `../tech/`.
> Resolved disagreements (formerly P0.5): launch narrative positioning = *The Age of the Codex*, epic fantasy with a writing theme (finalised, `../story/01`); launch monetization strategy = decided before store submission (the framework supports all four models; doesn't block the freeze).
> Scope: this whitepaper defines only the "game framework" — the structural skeleton that can carry any storyline, campaign or sub-game. Specific worldbuilding, main story and sub-game content are out of scope and planned separately.
> English mirror of `docs/framework/01-框架白皮书.md`. Terms follow `../GLOSSARY.md`.

---

## 1. Vision and positioning

A mobile game built around the tabletop role-playing (D&D-style) experience:

- **One engine holds every story**: framework and content are fully separated; a new plot, campaign or sub-game = a new content pack, with no change to the framework itself;
- **Ship, build and iterate at the same time**: after launch we keep releasing new story branches and content packs; the framework stays backward compatible with content;
- **One phone, two ways to play**: the same encounter core powers both "Landscape · Spatial campaigns" and "Portrait · Temporal campaigns"; the campaign mode is chosen by the player on entry or mandated by the main line, with zero data difference.

## 2. Design pillars

| Pillar | Meaning | Anti-pattern (we don't do this) |
|---|---|---|
| Framework/content decoupling | Plots, levels and items are all content-pack data; the framework provides only rules and state machines | Changing the engine for a new plot |
| Failure is a branch | A failed check is not game over but a road to another story path | Failure = reload and retry |
| The State Board is the single source of truth | Every branch is driven by the World State Board; story nodes only listen to the Board | Plots hard-coding calls to each other |
| Presentation/logic decoupling | Encounter logic doesn't know about the presentation form; landscape/portrait are just two rendering and pacing wrappers | Two modes with two sets of gameplay logic |
| Sustainable content delivery | Content packs follow a unified structure and versioning convention and can ship incrementally | Shipping the whole game on every update |
| Variability built in | Rule depth and monetization model are extension axes of the framework (rule packs / entitlement model), not one-time decisions | Welding the framework to a single ruleset or business model |

## 3. Overall structure: a five-layer funnel + one engine

```
L0  Epic            ── world background, endgame threat, top-level owner of the World State Board
 └─ L1 Campaign     ── a "campaign book": a complete set of story node graphs
     └─ L2 Arc      ── one act: a directed graph of 5–15 nodes
         └─ L3 Quest/Event ── smallest story unit: trigger condition + goal + settlement
             └─ L4 Encounter ── a single session: maze exploration / battle / dialogue / rest
```

The engine that cuts across all five layers is the **World State Machine** (see §4). Every branch at every layer happens by reading and writing the World State Board.

## 4. World State Machine

### 4.1 The six kinds of Board variables

| Variable type | Example | What it drives |
|---|---|---|
| Story Flag | `saved_the_blacksmith = true` | Unlocks / closes story nodes |
| Reputation | A faction +2 | Faction shops, NPC attitudes, reputation edges |
| Doom Clock | Sacrifice ritual at 7/10 segments | Time edges, bad-ending convergence |
| Inventory | Holding "the Shattered Star Chart" | Item edges, crafting, Compendium |
| Bond | A companion's affinity at 60 | Personal quest lines, departure events |
| Alignment | Lawful ↔ Chaotic slider | Ending type |

### 4.2 Iron rule

**No system in the game changes the story directly; systems only write to the Board. Story nodes only listen to the Board.**

This one decoupling buys three things:

1. "Keep going after failure" holds structurally (a failed check just writes a different flag);
2. A save = a Board snapshot, naturally supporting cloud sync and New Game+;
3. Content packs talk to each other through the Board without needing to know the others exist.

### 4.3 Namespaces

Variables are namespaced per content pack (e.g. `campaign01.saved_the_blacksmith`) so multiple packs can coexist without polluting each other; global variables (reputation, alignment) are managed by the framework layer.

## 5. Branching model: the story directed graph

### 5.1 Nodes and edges

A story arc (L2) is a directed graph: nodes are scenes/events, edges are traversal conditions. There are five kinds of edges:

| Edge type | Meaning | Example |
|---|---|---|
| Choice edge | An explicit player choice | Save / don't save / deceive |
| Check edge | A D20 check; success and failure each take a path | Lockpicking fails → alarm → stealth battle |
| Item edge | Only appears if you hold a specific item | Have the star chart → secret-passage node appears |
| Time edge | Fires automatically when the Doom Clock reaches a segment | Ritual completes → bad-ending side path |
| Reputation/alignment edge | An invisible threshold, noticeable in hindsight | Enough reputation → option to ask a faction for help |

### 5.2 Properties of branching

- **Branching is not a tree; it is a reachability graph grown from the Board**: in the same campaign book, different playthroughs can unfold subgraphs that overlap only ~60% because of different flags;
- **Failure doesn't end things**: every check edge must have a "failure path", and the failure path must be interesting too;
- **Convergence and openness coexist**: key nodes allow multiple paths to merge (avoiding branch explosion), but each path carries different flags in, so what follows differs.

## 6. Single-encounter state machine (the L4 core)

The encounter is the unit the player actually "plays". Its logic layer is a state machine that knows nothing about presentation:

```
Enter → Explore ⇄ Discover (check / pickup / trap)
         ↓ trigger                ↓ trigger
      Combat (initiative → round loop → resolve)  Dialogue (options / checks)
         ↓                        ↓
      Settlement (XP / loot / write Board) → Rest → Exit
```

Conventions:

- All numbers, checks, AI and loot rolls happen only in the logic layer;
- The logic layer outputs only an **event stream** (e.g. "You deal 14 damage to the orc", "Check succeeded: Perception 18");
- The event stream is the rendering layer's only input, and also the only input to the log, replays and achievements.

## 7. Dual-mode presentation: Landscape · Spatial / Portrait · Temporal campaigns

### 7.1 Mode is a property of the campaign, not of how the phone is held

The presentation mode is not decided by rotating the phone; it is a **declared property of the campaign (content pack)**:

- Every campaign book declares its presentation mode: `Landscape · Spatial` / `Portrait · Temporal` / `dual-mode (player's choice)`;
- **Entering a campaign is itself a branching choice**: a dual-mode campaign offers the player a mode choice at the entrance and writes the result to the Board; a single-mode campaign is mandated by the main-line design — and the mandate is itself a narrative device (cutscene-heavy campaigns force portrait temporal flow; big battlefields force the landscape spatial board);
- The mode is locked for the duration of a campaign; no mid-way switching;
- If a campaign ships in dual mode, the other mode becomes a replay path, directly serving New Game+ and branch collection.

### 7.2 The two campaign forms

| | Landscape · Spatial campaign | Portrait · Temporal campaign |
|---|---|---|
| Gameplay metaphor | "Lay out" the battlefield: grid, positioning, line of sight | Let the story "flow past": many rooms, advancing beat by beat |
| Encounter structure | Spatial encounters: tactical grid map, free movement | Temporal encounters: room sequence, unlocked one by one |
| Layout | Spatial zoning: central main view + left/right columns + top/bottom edges | Temporal zoning: main view / console, heights "breathe" with context |
| Combat presentation | Tactical grid, positioning, projectile lines | Vertical battlefield / smart camera / feed-style battle reports |
| Dice | Dice tray on the right; key checks get a full-screen presentation | Dice tray with tiered presentation (quick roll for normal / full screen for key) |
| Information strategy | Shown side by side simultaneously | The same pixels switch purpose moment to moment |

### 7.3 The one-core-two-shells iron rule

- **Zero data difference**: the same encounter is driven by the same state machine; the two forms are just two rendering and pacing wrappers; numbers, checks and results are byte-for-byte identical;
- **No logic in the rendering layer**: no rules, numbers or checks may enter the rendering layer;
- **The event stream is the only input**: both renderers consume the same event stream, as do the log, replays, achievements and the History Scroll.

## 8. Items and collection

Items have four identities in the framework, escalating with rarity:

1. **Numeric**: affects in-encounter power (weapons, armor, consumables);
2. **Check modifier**: affects the pass rate of check edges (tools, amulets);
3. **Branch key**: opens item edges, changing the shape of the story graph (star charts, signets, tokens);
4. **Compendium / Lore**: completing a series unlocks background entries and hidden content entrances.

Collection is not a bolt-on; it is **a means of changing branch topology**, directly serving NG+ and content-pack expansion.

## 9. Meta loop

```
Play an encounter (L4)
  → settlement writes to the World State Board (flags / reputation / clock / items / bonds)
    → trigger scan: which story nodes light up / go dark (L2 / L3)
      → the campaign map updates; new entrances appear (L1)
        → the Doom Clock advances; the Epic moves toward an ending type (L0)
          → the player picks the next entrance and enters the next encounter
```

What the player feels is "I'm adventuring"; what the system sees is "every encounter is one write operation on the World State Board".

## 10. Content expansion model: ship while iterating

This is the framework's lifeline design.

### 10.1 Content is data

- A new arc, campaign or sub-game = a **content pack**: story node graph + event table + encounter definitions + item table + text resources;
- After launch the framework is **version-decoupled** from content packs: framework upgrades don't break published packs, and a new pack declares the minimum framework version it needs.

### 10.2 Sub-games

- A sub-game is a content pack that **reuses the encounter state machine and swaps rule parameters and presentation** (e.g. Arena Gauntlet, Riddle Maze, Haven Management);
- Sub-games interoperate with the main line through the Board (rewards are written to the Board, gates read the Board) but can be released and updated independently.

### 10.3 Release cadence (product-level convention)

1. Launch: framework + the first main campaign;
2. Then continuous delivery as content packs: new story branches → new campaigns → the first sub-game → more content packs;
3. Before going live, every content pack must pass: branch-graph integrity validation (no dead ends, no unreachable nodes) and a Board namespace collision check.

### 10.4 Dual-track iteration

Above the framework there are only two kinds of iteration. They are decoupled, each has its own pipeline, and each can ship independently — a content update doesn't need to touch monetization, and an operations tweak doesn't need to touch content:

| Track | Content | Pipeline | Invariants |
|---|---|---|---|
| **Content track** (ship, expand the world, build and iterate at the same time) | New branches / new campaigns / new sub-games / new rule packs / world expansion | Content-pack pipeline (§10.1–10.3) + go-live validation | Framework untouched; old saves stay valid; backward compatible |
| **Operations track** (live-ops iteration) | Choosing and adjusting monetization strategy, pricing, events and entitlement grants, cosmetic items, Home promo-slot content | Entitlement model (§12): adjust how entitlements are lit and the strategy declarations, **without touching the content graph** | Monetization no-go zones (§12.3); acquired entitlements never downgrade |

The only interface between the two tracks is **entitlement variables**: content packs declare gates ("which entitlement unlocks this" — stable); operations decide how they're lit ("how the entitlement is granted" — variable). Details in `06-monetization-framework.md`.

## 11. Rule-layer abstraction: the Rule Pack

### 11.1 Positioning

Rule depth is not a one-shot product decision but an **extension axis** of the framework. The framework only fixes a D20 minimal core; everything else is carried by "rule packs". The first main campaign launches on the Light rule pack; later packs can introduce deeper rules without touching the framework.

### 11.2 The D20 minimal core (shared by all rule packs)

1. **D20 check**: roll + modifier vs difficulty, producing success/failure branches;
2. **Event-stream output**: every rule resolution is output as events (the rendering layer, History Scroll and achievements consume only the event stream);
3. **Board reads/writes**: rule packs affect story branches only through Board variables and may never touch story nodes directly.

### 11.3 Three rule-depth presets

| Tier | Audience | Characteristics |
|---|---|---|
| Light | Launch main line, short-session players | 3 attributes, three difficulty tiers, three-part action economy |
| Standard | Core RPG players | 6 attributes, skill trees, status-effect system |
| Deep | Tabletop enthusiasts | 5e-like: full attributes, spell slots, saving throws, feats |

A campaign declares the rule pack and minimum version it needs; different campaigns on the same framework can use different tiers side by side. The six elements and details are in `05-rules-system-framework.md`.

### 11.4 Iron rules

- All rule differences are absorbed by the logic layer: **the rendering layer, the two forms and the screen loop are unaware of the rule tier**;
- Rule packs are versioned independently; an in-progress campaign in an old save can be frozen on the old version to finish;
- When carrying characters across campaigns, the attribute mapping table declared by the rule pack handles the conversion.

## 12. Monetization abstraction: the Entitlement Model

### 12.1 Positioning

The business model is a delivery strategy, not a shape of the framework. The framework provides a unified **entitlement model**: entitlements are global variables on the Board; content packs declare unlock conditions; payment is just one way of lighting an entitlement (events and achievements can too). The launch monetization strategy doesn't block the framework freeze.

### 12.2 Monetization strategies: all supported by the framework, chosen per pack

The framework supports **every monetization strategy** — the four current models are fully built in, and any future model (e.g. battle pass, free chapters + bundle discount) is supported automatically as long as it ultimately lands on "lighting an entitlement variable", with no framework change:

| Model | How the framework supports it |
|---|---|
| Premium (buy the base game) | Base entitlement bundle |
| Content-pack DLC | Campaign / arc packs declare an entitlement gate; the entrance shows a locked state |
| Subscription | A periodic set of entitlements (early unlocks, exclusive cosmetics) |
| Cosmetic / presentation items | Writes only cosmetic flags; never affects numbers or branches |

- **Strategy is a per-pack choice**: each campaign / sub-game independently declares which strategies it participates in (manifest `monetization` field), and they can be mixed (the same pack can be "DLC gate + subscription early unlock + cosmetic item slot" at once);
- **Strategy changes with versions**: adjusted version by version with operations decisions (e.g. a DLC pack moves into the subscription set, or goes free for a limited time) by changing how operations light entitlements — **no framework change, no content-graph change**;
- Legitimately acquired entitlements never downgrade: tightening a strategy affects only players who haven't unlocked yet; loosening takes effect immediately (doc 06 §3.2).

Mixable and adjustable per version, with no framework changes. Details in `06-monetization-framework.md`.

### 12.3 Iron rules

- **Payment points never hang on check results** — the fairness of the dice is not for sale;
- Paid content never breaks the branch integrity of free paths;
- Paid content packs go through exactly the same validation and screen-loop checks as free ones.

## 13. Glossary

| Term | Definition |
|---|---|
| Epic | The top narrative layer: world background and endgame threat |
| Campaign | One campaign book, a set of story node graphs |
| Arc | One act, a directed graph of 5–15 nodes |
| Encounter | A single session: maze / battle / dialogue / rest |
| World State Board | The set of six kinds of variables; the single source of truth for branching |
| Event Stream | The result sequence output by the encounter logic layer; the only input to rendering and logs |
| Content Pack | A unit of story / campaign / sub-game shipped as data |
| Doom Clock | A progress variable that drives endgame pressure |
| Campaign mode | The presentation form declared by a campaign book: Landscape · Spatial / Portrait · Temporal / dual-mode, chosen on entry or mandated |
