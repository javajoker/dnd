# Technical Approach (discussion draft): the framework's technical foundation

> Version: v0.2 (discussion draft)
> Related docs: `../framework/01-framework-whitepaper.md` (v1.0 frozen), `../framework/02-PRD.md`, `../framework/05-rules-system-framework.md`, `../framework/06-monetization-framework.md`, `../framework/07-world-state-machine-spec.md`, `../framework/09-encounter-and-dual-mode-spec.md`, `../framework/11-light-rulepack-v1.md`
> Scope: the technical implementation of the game **framework** — engine choice, logic/presentation layering, World State Machine and event-stream architecture, the rule-pack mechanism, the content-pack runtime. Not the implementation of specific campaign content (content data is covered in `02-content-pack-format-spec.md` and `03-content-pack-authoring-guide.md`).
> English mirror of `docs/tech/01-技术方案讨论稿.md` (change history omitted). Terms follow `../GLOSSARY.md`.

---

## 0. Purpose

The design docs (framework/) answer "what is this game"; this doc answers "what technology builds it". The method is to derive technical constraints backwards from the design iron rules, so every architectural decision points back to a design pillar — anything that can't is over-engineering.

## 1. Design iron rules → technical constraints

| Design iron rule (source) | Technical constraint |
|---|---|
| Framework/content decoupling (whitepaper §2) | The logic layer may not import any content data; all content is loaded at runtime as data packs |
| Presentation/logic decoupling / one core, two shells (whitepaper §7.3) | The logic layer has **zero engine dependencies** (pure code, testable in a console); the engine appears only in the rendering shells |
| The event stream is the only input (whitepaper §6) | An append-only event log is the logic layer's only outward channel |
| The Board is the single source of truth (whitepaper §4.2) | A single mutable store; every write carries provenance, supporting the History Scroll's causal chain |
| Save = Board snapshot (whitepaper §4.2) | The whole Board is serialisable, versioned and migratable |
| Rule depth is an extension axis (doc 05) | Rule pack = a replaceable strategy set behind an interface; the D20 minimal core is hard-coded in the core |
| Business model is an extension axis (doc 06) | Entitlement = a global Board variable; shop / events / achievements are just different writers |
| Sustainable content delivery (whitepaper §10) | Content packs are versioned independently, loaded at runtime, backward compatible and validated automatically before going live |

## 2. Engine choice

### 2.1 Criteria (weighted for this project)

1. **Maturity of the mobile release pipeline for iOS and Android** — package size, patches, store compliance;
2. **Dynamic content-pack loading** — DLC / hot updates are the framework's lifeline (whitepaper §10); the engine must have an official or de-facto-standard resource-pack mechanism;
3. **UI-heavy, mainly 2D presentation** — the nine-screen loop, the portrait three-band breathing layout, 45° pseudo-3D; no AAA 3D needed;
4. **A separable logic layer** — core logic can be written as a pure library independent of the engine (decides test cost and whether "one core, two shells" holds);
5. **Hiring and ecosystem** — community, talent market, plugin ecosystem.

### 2.2 Candidate comparison

| Dimension | Unity 6 LTS (C#) | Godot 4.x (C#/GDScript) | Unreal 5 | Cocos Creator |
|---|---|---|---|---|
| Mobile pipeline | ★★★ most mature | ★★ usable; pitfalls in store signing and compliance details | ★★ too heavy, large packages | ★★ mature in China |
| Content-pack loading | Addressables / AssetBundle, official | **PCK files are naturally DLC** — most elegant | Clumsy DLC support | Mature hot-update solutions |
| UI / 2D | UI Toolkit + uGUI, mature | Control node system, light and handy | UMG is heavy | Strong |
| Logic separation | **.NET Standard library, cleanest** | C# separable, GDScript not | Hard | Fair (TS testable) |
| Talent ecosystem | ★★★ | ★★ (growing) | ★★ | ★★ (China) |
| Risk | Licensing policy history | Few heavy mobile projects | Overkill | Weak long-term 3D |

### 2.3 Decision (made: Godot 4 + GDScript)

- **E-1 decision: Godot 4.7.2 + GDScript.** Reasons: the "PCK = DLC" model maps one-to-one to this framework's content-pack philosophy (§8); lowest package-size and licensing cost; native GDScript integration suits a small team iterating fast. A C# channel can be reviewed later if .NET libraries are needed.
- E-4 decided with it: the logic-core language follows the engine = GDScript (core implemented as pure RefCounted classes, testable headless, equivalent to iron rule 2).
- Engineering setup in place: the `game/` project skeleton, the `.claude/skills/godot-dev` and `godot-acceptance` skills, and the `godot-developer` agent.

## 3. Overall architecture: implementing one core, two shells

```
┌──────────────────────────────────────────────────────────┐
│ Rendering shells (engine layer)                           │
│  ├─ Landscape spatial renderer ├─ Portrait temporal renderer ├─ Nine-screen UI │
│  └─ Dice presentation / camera / audio                    │
│        ▲ consume only the event stream + read-only Board  │
│        │ send only player intents (Commands)              │
├────────┴─────────────────────────────────────────────────┤
│ Logic core (pure library, zero engine deps, runs in a console) │
│  ├─ WorldStateBoard   World State Board (§4)              │
│  ├─ EventStream       event-stream bus (§5)               │
│  ├─ StoryGraph        story graph runtime: trigger scanning (§7) │
│  ├─ EncounterSM       encounter state machine: six states (§6)   │
│  ├─ RulePackHost      rule-pack host: D20 minimal core + replaceable strategies │
│  ├─ EntitlementGuard  entitlement gate checks (reads entitlement variables only) │
│  └─ SaveSystem        snapshots / version migration (§9)  │
├──────────────────────────────────────────────────────────┤
│ Content layer (pure data, loaded at runtime)              │
│  content packs (campaigns / sub-games) + rule packs + entitlement declarations → format in doc 02 │
└──────────────────────────────────────────────────────────┘
```

Key constraints:

- **One-way dependencies**: content layer ← logic core ← rendering shells. Reverse references should be impossible by construction (layered assemblies / module boundaries), not by discipline.
- **The logic core runs without the engine**: all unit tests, the branch-graph validator and full-campaign simulation (bot auto-play) run in a console — directly serving the TASKS P1.2 "full internal playthrough": the 35 nodes of *Ashenport Fragments* can be run through by simulation before any prototype UI exists.
- **Renderers are unaware of the rule tier** (doc 05 §6): shells only know the event-stream format, not rule packs.

- **Enforcement**: GDScript has no assembly boundaries, so one-way dependencies are enforced by the acceptance skill's grep scans, covering `core/`, `shell/` and the app layer (`main.gd`, `subgame_runner.gd`).
- **Keep the app layer thin**: `main.gd` only wires and routes; campaign flow, sub-game flow and save timing are separate flow objects (CampaignFlow / SubgameFlow / AppServices); screenshot and demo drivers live in `tools/`, never in the production main scene.
- **No content constants in framework code**: core and shells contain no pack ids (`campaign01` …), node ids (`N1-1` …) or pack-private keys; everything pack-specific (gold key, starting gold, settlement-exempt keys, entry campaign) comes from manifests and the pack catalog.

## 4. World State Machine (WorldStateBoard)

### 4.1 Data structure

```
Board = Map<NamespacedKey, TypedValue>

NamespacedKey = "<namespace>.<name>"   e.g. campaign01.seen_fading
namespace ∈ { global, <pack_id> }       global variables under global, pack variables under the pack ID
TypedValue ∈ { Bool, Int, Float, Enum, String, List, Set }
```

The six variable kinds (flag / reputation / clock / inventory / bond / alignment) are not six structures but **six semantic tags on the same key-value space** — the tags are used for UI grouping and validator checks; storage and read/write paths are unified. Inventory is stored on the Board as `Set<item_id>`; the inventory UI is just a view of it (doc 04 §1).

### 4.2 Write API and provenance

```
board.write(key, value, provenance: { event_id, node_id, pack_id })
```

- Every write **must carry provenance** (which event in which stream wrote it). This is the data source for the History Scroll's "flag trace" (doc 04 screen ⑧); a write without provenance raises an error in Debug builds.
- A write fires a `StateChanged` notification → the story graph's **trigger scan** (§7) and UI refreshes subscribe only to this notification.

### 4.3 Snapshots and saves

- Save = full Board serialisation (JSON) + metadata (framework version, each content/rule pack version, event-stream tail sequence number);
- Version migration: snapshots carry a version number and are upgraded through a migration chain on load (working with the rule-pack "freeze in-progress campaigns on the old version" mechanism, doc 05 §7);
- Cloud sync and NG+ carry-over = transporting and trimming snapshots, no extra mechanism.

## 5. Event stream (EventStream)

### 5.1 Event structure

```
Event = {
  id,            // incrementing sequence number (unique within a save)
  session,       // encounter ID (which session produced it)
  type,          // check.result / damage.dealt / flag.written / ...
  payload,       // structured data (roll, modifier, difficulty, result …)
  source,        // producer (rule pack / encounter state machine / story graph)
}
```

### 5.2 Architectural properties

- **Append-only, immutable**: once written, events never change. Rendering, logs, the History Scroll, achievements and replays consume the same stream (whitepaper §7.3);
- **In-process pub/sub**: the logic core produces, rendering shells subscribe. High-frequency scenes like combat deliver in "beats" (all events of one action arrive in one frame so renderers can pace the presentation);
- **Determinism**: all randomness in the logic core (dice, loot rolls) uses a **seeded RNG** whose seed is saved. Event stream + seed = a fully reproducible encounter; **every new game takes a fresh seed** (system time / entropy); fixed seeds are only for tests and tools (simulation, winrate, screenshots);
- **Replay is pure presentation**: battle replay (doc 04 screen ⑧) replays the event stream to drive renderers; it never re-runs logic and can't change results.

### 5.3 Why not ECS / message-queue middleware

At single-player scale the event stream is just an ordered list plus subscriber callbacks, deliberately kept plain: it is first an **archival data structure** (the shared source of truth for the History Scroll, replays, achievements and debug logs), and only second a communication mechanism. Middleware would blur that.

## 6. Encounter state machine and the rule-pack host

### 6.1 Encounter state machine (EncounterSM)

The six states (whitepaper §6) are implemented as an explicit state machine rather than behavior trees or scattered coroutines — few states, and transitions need to be validated and visualised:

```
Enter → Explore ⇄ Discover → Combat → Settlement → Rest → Exit
                └→ Dialogue ─┘   └─→ (retreat edge) → Exit
```

- Each state's entry/exit conditions come from the pack's encounter definition (doc 02); the state machine itself holds no content;
- State changes drive the portrait "breathing" layout (doc 04 §④.1): the state machine emits `state.entered` events and shells adjust the three band heights accordingly — **logic never commands the UI; the UI only subscribes to state**.

### 6.2 Player input: Commands

Shells only send intents (`MoveCommand` / `AttackCommand` / `ChoiceCommand` / `RollCommand` …); the logic core validates and executes them and produces events. Illegal intents are rejected outright — a rendering bug can't corrupt logic state.

The source of a Command is transparent to the core: a finger tap is one source; **the auto-play agent is another** — it translates the preset strategy into isomorphic Commands (rolling dice, using skills by priority, using items by threshold), goes through exactly the same validation and event stream, tagged only with `source = auto`; agent execution is bounded by a minimum beat (default ≥0.8 s per action, 1×/2×), and the player can take over at any time (doc 09 §9.3). This lets auto-play, replay and bot simulation (§10 TP1) share one command channel.

### 6.3 Rule-pack host (RulePackHost)

The D20 minimal core is hard-coded in the core (check-formula skeleton, event-stream output, Board read/write — the three immutable items of doc 05 §2); the six elements are injected via an interface:

```
interface IRulePack {
  AttributeModel   Attributes   // attribute model (Light: 3; Deep: 5e-like)
  CheckFormula     Check        // modifier computation and difficulty calibration
  ActionEconomy    Economy      // what can be done each turn
  TurnStructure    Turn         // initiative and round loop
  GrowthCurve      Growth       // what leveling grants
  DeathRule        Death        // what happens at zero
  AttributeMapping MapTo(other) // cross-rule-pack character conversion (doc 05 §5)
}
```

- When a campaign loads, it binds to its declared rule-pack ID + minimum version (the save records the bound version; in-progress campaigns are frozen);
- The Character screen's field set is generated from the current `IRulePack.Attributes` (doc 04 screen ⑦ "dynamic presentation");
- **Effect system (EffectEngine)**: characters / skills / items / effects are all data resources; modifiers are evaluated through the fixed pipeline "base → add → mul → override → clamp", and each attachment goes into the event stream with provenance — adding a resource = adding a data row, balancing = changing data values, zero framework change. Format and stacking rules in `04-resources-and-effects-system.md`. **Not yet implemented in code** (see TASKS "Known gap").

## 7. Story directed-graph runtime (StoryGraph)

- Content packs compile the five edge types into one **condition + target + effects** structure (doc 02 §4); at runtime there are no "five edge types", only a condition evaluator — the edge type is just a semantic tag for content authors and UI;
- **Trigger scan**: after every Board write, evaluate the conditions on the out-edges of the current active node set, lighting/darkening nodes. The scan is incremental (only re-checks edges that reference changed variables); at ~35 nodes / ~200 edges the cost is negligible;
- **Time edges** are triggered by Doom Clock writes through the same scan; there is no separate timer system;
- The branch-graph validator (dead ends / unreachable / closed flag loops / node budget / namespace collisions) is an **independent command-line tool** sharing the same evaluation code as the core — so "validation passes" and "runs correctly" mean the same thing.

## 8. Content-pack runtime and loading pipeline

```
Load flow: read manifest → framework version check → namespace registration (collision check)
         → entitlement gate check (EntitlementGuard, read-only)
         → graph and table structure validation → build indexes → playable
```

- **Godot channel (chosen)**: one PCK per pack, `ProjectSettings.load_resource_pack`;
- (Unity channel, evaluated and not chosen: Addressables remote catalog, one group per pack;)
- Three-way version decoupling (framework / content pack / rule pack); packs declare `min_framework_version`, and the framework stays backward compatible (PRD F5.2);
- Format details, validation checklist and authoring process in `02-content-pack-format-spec.md` and `03-content-pack-authoring-guide.md`; first instance: `../story/campaign01/` (*Ashenport Fragments* fully data-driven).

> Implementation note: the current build loads packs from loose JSON under `res://packs/`; PCK packaging and remote delivery are not implemented yet (doc 14 #14/#16).

## 9. Saves, replay and New Game+

| Capability | Implementation |
|---|---|
| Saves | Board snapshot + event-stream tail + binding-version table (§4.3) |
| Replay | Event-stream replay (§5.2), pure presentation, not interactive |
| New Game+ | New playthrough = new snapshot + selective copy from the old snapshot per the "carry-over list" (the list is content-pack data, `manifest.ngplus`) |
| No reload on failure | Structurally there's no need for "reload and retry" — failure is already written to the Board and branches (whitepaper §5.2); save points are only exit protection |

## 10. Technical prototype plan

| Stage | Deliverable | Validates |
|---|---|---|
| TP0 Logic-core skeleton | Board + event stream + evaluators, runnable in a console | Iron rules 2/3/4 hold |
| TP1 Campaign simulation | Load `story/campaign01/` data; a bot runs through all 35 nodes and every ending | Content-pack format completeness + branch-graph validator |
| TP2 Single-encounter portrait shell | One portrait battle in the engine + three-band breathing + tiered dice presentation | One core two shells; event-stream-driven rendering |
| TP3 Dual-shell verification | The same encounter run once in each shell; event streams compared byte for byte | Zero data difference (whitepaper §7.3) |
| TP4 Loop | Home → Campaign Entry (mode branch) → Encounter → Settlement → History Scroll trace | Minimal nine-screen loop |

## 10.1 Mobile platform layer (required for store release)

| Capability | Requirement |
|---|---|
| Screen orientation | Form switching calls `DisplayServer.screen_set_orientation()` (real device rotation); resizing a desktop window is only a dev convenience. English v1 is portrait-first (`display/window/handheld/orientation = portrait`); the landscape spatial form is feature-flagged until v1.1 |
| Safe area | The three-band layout and full-screen takeovers avoid the notch / home indicator (`DisplayServer.get_display_safe_area()`) |
| Lifecycle | `NOTIFICATION_APPLICATION_PAUSED` auto-pauses and takes a fallback save, then resumes (doc 09 §7); the Android back button = ☰ menu / previous screen |
| Load on launch | On launch, read the latest snapshot → migration chain → apply → restore story-graph progress (doc 07 §4.2); "Continue" on Home must really continue |
| Package size | BGM as Ogg Vorbis; fonts loaded per language (a Latin face for en, Noto Sans SC only for zh-CN); export filters include the PNG/WAV files read via `load_from_file` |
| Export | Android (AAB) and iOS export presets committed (without signing keys); at least one real-device build per milestone |

## 11. Open decisions

| ID | Question | Status |
|---|---|---|
| ~~E-1~~ | Engine | ✅ Decided: Godot 4.7.2 + GDScript (§2.3) |
| E-2 | Authoring format: plain JSON (with schema validation) vs YAML compiled to JSON | Doesn't block (JSON first, editor later) |
| ~~E-3~~ | Event-stream persistence granularity | ✅ Decided: **full stream in the save** (snapshot `events` key; restored on launch without notifying subscribers). Events hold only msg_key/data, so the History Scroll re-renders in the current language |
| ~~E-4~~ | Logic-core language | ✅ Decided: GDScript (follows the engine) |
| ~~E-5~~ | Text resources and localization | ✅ Decided: **one bilingual build** (zh-CN + en). Core emits no player-facing prose — events carry `msg_key` + `args` and shells resolve them in the current language; UI strings live in locale tables (`texts/<locale>`); pack text keys are locale-independent (doc 02 §1.1); language is a UI preference (`ui.locale`, defaulting to the OS language). Implemented in P4 Phase 1 (`shell/ui/texts.gd`, `PackLoader._apply_locale`, packlint V15) |
