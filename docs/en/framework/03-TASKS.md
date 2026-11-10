# TASKS / CHECKLIST

> Version: v0.1
> Related docs: `01-framework-whitepaper.md`, `02-PRD.md`
> Note: this list covers design, product and content work; technical implementation tasks are in P1.5.
> Status markers: `[ ]` not started / `[~]` in progress / `[x]` done
> English mirror of `docs/framework/03-TASKS.md` (change history omitted). Terms follow `../GLOSSARY.md`.

---

## P0 Framework design freeze (M0)

### 0.1 Whitepaper review and sign-off

- [x] Review whitepaper v0.1: five-layer structure, state machine, branching model, dual mode, content-pack model
- [x] Resolve outstanding design disagreements (see 0.5)
- [x] Sign off whitepaper v1.0 and freeze it

### 0.2 World State Machine spec — final in `07-world-state-machine-spec.md`

- [x] Complete field definitions for the six variable kinds (name, range, default, readers/writers)
- [x] Namespace rules finalised (pack prefixes, ownership of global variables)
- [x] Save-snapshot rules: timing, version number, compatibility strategy
- [x] General Doom Clock behavior rules

### 0.3 Branching model spec — final in `08-branching-model-spec.md`

- [x] Full definitions and validation rules for the five edge types
- [x] "Failure is a branch" writing rules: minimum content for failure paths (patterns A/B/C)
- [x] Node convergence strategy: branch budget (per-campaign node / edge caps)
- [x] Branch-graph validation checklist (dead ends, unreachable nodes, orphan flags) — automated items in `../tech/02-content-pack-format-spec.md` §12

### 0.4 Encounter and dual-mode interaction spec — final in `09-encounter-and-dual-mode-spec.md`

- [x] Entry/exit conditions for the six encounter states
- [x] Campaign-mode declaration: how a pack declares Landscape Spatial / Portrait Temporal / dual-mode
- [x] Campaign-entry mode branch: information on the choice screen, narrative wrapping of forced modes, mode-lock rules
- [x] Landscape spatial layout: zone ratios, control duties, tactical-grid readability
- [x] Portrait temporal layout: three-band breathing rules, console tab duties, multi-room pacing
- [x] Dice-presentation tiers: which checks count as "key checks"

### 0.5 Disagreements to resolve (downgraded: no longer block the framework)

The framework has built rule depth and the business model in as extension axes (see `05-rules-system-framework.md`, `06-monetization-framework.md`), so these decisions move down to the content and operations layers:

- [x] Rule depth: the framework supports multiple coexisting rule-pack depths; the first main campaign launches on Light rules and can deepen over time (direction decided; details in `11-light-rulepack-v1.md`)
- [x] Launch narrative positioning: epic fantasy with a writing theme — *The Age of the Codex* finalised (`../story/01`)
- [x] Launch monetization strategy: free base + content-pack DLC + cosmetics (decided, doc 06 §7; subscription not enabled this phase)

### 0.6 Items and Compendium spec — final in `10-items-and-compendium-spec.md`

- [x] Tag system for the four item identities
- [x] Compendium series rules and completion reward forms

### 0.7 Screen-loop spec (`04-ui-ux-design.md`)

- [x] Review the nine screens (Home / Campaign Entry / Encounter ×2 / Event Center / Inventory-Compendium / Character / History Scroll / Settlement)
- [x] Screen-loop checklist all green: every screen has clear entrances and exits, no dead ends
- [x] Global elements: status bar, dice-presentation tiers (refined in `09-encounter-and-dual-mode-spec.md` §6), sheets and drawers

### 0.8 Rule-pack spec (`05-rules-system-framework.md`)

- [x] Review the D20 minimal core (checks, two branches, event-stream output)
- [x] Six-element field list: attribute model / check formula / action economy / round structure / growth curve / death and failure
- [x] Rule-pack versioning and save freeze/migration strategy (doc 05 §7 + `07-world-state-machine-spec.md` §4.3)
- [x] First Light rule pack details — final in `11-light-rulepack-v1.md` (together with campaign01)

### 0.9 Monetization framework spec (`06-monetization-framework.md`)

- [x] Entitlement variable rules: `global.entitlement.*` namespace, pack unlock-condition declaration (doc 06 §2.3 + `../tech/02-content-pack-format-spec.md` §2.2)
- [x] Mount points and no-go zones for the four models (not on checks, don't break branch integrity, don't sell power)
- [x] Campaign-entry locked state and Home promo-slot presentation
- [x] Handling refunds / revoked entitlements for in-progress campaigns (finish the current campaign, no new game)

**P0 exit**: all specs at v1.0, whitepaper v1.0 frozen, M0 reached (launch monetization strategy is an operations item and doesn't block). The technical prototypes (TP0–TP4, see `../tech/01-technical-approach.md` §10) and the P1.2 playtest enter their start window.

---

## P1 Worldbuilding and the first main campaign (M1, starts after M0)

### 1.1 Worldbuilding

- [x] Epic (L0) setting: world background, endgame threat, overall Doom Clock theme — see `../story/01-world-age-of-the-codex.md`
- [x] Faction list and starting reputation — see `../story/01-world-age-of-the-codex.md` §6
- [x] Compendium Lore entry framework — see `../story/01-world-age-of-the-codex.md` §9

### 1.2 First main campaign

- [x] Campaign book (L1) outline: number of arcs, node budget, number of ending types — see `../story/02-campaign-ashenport-fragments.md` §1/§3
- [x] Node graph for each arc (L2): nodes, five edge types, convergence points — see campaign book §4
- [x] Quest / event list (L3): triggers, goals, Board writes on settlement — see campaign book §6
- [x] Encounter list (L4): maze / battle / dialogue / rest mix — see campaign book §7
- [x] Item table, including placement of branch-key items — see campaign book §8
- [~] Branch-graph validation passes (dead ends / unreachable / closed flag loops) — packlint 0 FAIL on all packs, **but 5 flags (seen_fading, blank_memory, page_tearer, insider, failed_to_hold) are written and never read** (packlint V4 WARN; code review M3)
- [x] Full internal playthrough and tuning — resumes after relaunch and seeds each new game freshly (B1/B3 fixed in P4 Phase 0): full Godot playthrough (N0-1 → four endings E1–E4 + NG+); bot simulation covers 45 nodes at 100%; winrate puts all 11 battle encounters within target win-rate bands (story/03 final balance)

---

## P1.5 Technical implementation (Godot)

> Engine decision: Godot 4.7.2 + GDScript (`../tech/01-technical-approach.md` §2.3).
> Engineering discipline: `.claude/skills/godot-dev` (workflow), `godot-acceptance` (acceptance audit), `godot-developer` (dev agent) — all work under game/ goes through the skill workflow. English versions: `godot-dev-en`, `godot-acceptance-en`, `godot-developer-en`.
> The roadmap is `../tech/01-technical-approach.md` §10 TP0–TP4.

- [x] Engineering setup: game/ project skeleton (core/shell/packs/tools/tests) + headless test channel (`godot --headless --path game -s tests/run.gd`)
- [x] Engineering skills and agent: godot-dev / godot-acceptance / godot-developer in place
- [x] TP0 logic-core skeleton: Board (six variable kinds / namespace permissions / provenance / JSON snapshots) + event stream (append-only / subscribe / tail) + condition and effect evaluators (all keys of tech/02 §4.6) + seeded RNG. Rulings: lore unlocks write `global.lore`; local clock key `clock.<id>`; XP belongs to the growth system
- [x] TP1 campaign01 simulation: pack_loader / story_graph / packlint (V1–V13) / bot simulation; all four endings reachable (E3 confirmed as an NG+ hidden ending), lone wolf reachable; acceptance rulings completed the data (lone-wolf entrance edge, Bond placement, encounters registered up to 16), campaign book updated
- [x] TP2 single-encounter portrait shell: encounter core (six-state SM + Light rule pack + auto-play agent) + portrait three-band breathing / progress bar / four tabs / quickbar chips / two-tier dice presentation / auto-play pacing, event-stream-driven rendering; ruling fixed the 04/09 combat-ratio contradiction (12/55/37 → 12/55/33)
- [x] TP3 dual-shell verification: landscape five-zone shell (initiative bar / action wheel / tactical grid / dice tray / log strip) + shell router (choice defaults to time / forced narrative wrapper / per-encounter lock); **byte-for-byte identical event streams for the same encounter in both shells**; ruling: the three columns are width weights 15:60:12 normalised
- [x] TP4 screen loop: (load-on-launch added in P4 Phase 0) minimal loop of all nine screens + SaveSystem (five-part snapshot, no saving mid-encounter, ☰ returns to the pre-encounter snapshot, migration chain) + L3 event runtime (four trigger kinds and settlement writes); ruling: growth curve uses the three tiers of 11 §6
- [~] **All P1.5 technical prototypes (TP0–TP4) achieved** on desktop/headless; not yet built or run on a phone (no export presets; landscape mode only resizes a desktop window — code review B2) — the framework's minimal playable loop holds; moving on to content integration and operations
- [x] Continuous-iteration channel: the dual-track release pipeline works end to end — content track (arc_tide side arc via graft, riddle_maze sub-game, packlint V1–V14 go-live validation) and operations track (ops_config entitlements / prices / events / home_promo)

## P2 Content pipeline and sub-game template (prerequisite for M3)

- [x] Content-pack structure spec finalised — `../tech/02-content-pack-format-spec.md` (directory structure / manifest / five-edge DSL / table schemas / external `text_ref` / graft declaration)
- [x] Content-pack version declaration and compatibility rules — tech/02 §11 (three-way version decoupling) + SaveSystem migration chain
- [x] Content-pack go-live checklist — tech/02 §12 V1–V14 automated validation (packlint runs on all four packs with 0 FAIL)
- [x] Sub-game design template — tech/02 §2.5 sub-game declaration block + two instances (arena: combat / riddle_maze: pure puzzle; zero core changes asserted)
- [x] Sub-game doc layout convention: one subdirectory per sub-game at `docs/en/subgames/<name>/`, updated as needed
- [x] First sub-game concept design — Arena Gauntlet (`../subgames/arena/01-concept.md`, live); the second sub-game, Riddle Maze, is live too

---

## P3 Live operations (M4)

**Content track**:

- [ ] Content-pack release schedule (scheduling model for branches / campaigns / sub-games)
- [ ] Process for turning player feedback into new branches
- [ ] Retrospective on long-term goals driven by NG+ and collection

**Operations track**:

- [x] Launch monetization strategy decided — free base + DLC + cosmetics (06 §7)
- [~] Strategy adjustment process: operations review → entitlement delivery → effect retrospective (review and delivery chain works; the effect retrospective awaits real operations data)
- [x] Event / cosmetic item delivery pipeline — verified: ops_config event switches, cosmetic items implemented (cosmetics registry + shop purchase + completion reward), Home promo slot via home_promo
- [ ] Dual-track release calendar alignment (rules for staggering content updates and operations milestones)

## P4 English mobile release (started 2026-11-10; plan in `../tech/06-english-mobile-plan.md`)

> Decisions: all current content in English; portrait-first v1 (landscape in v1.1); free demo + one-time unlock; one bilingual build.

**Phase 0 · Fix the blockers (code review B1–B4)**

- [x] Test isolation: injectable `SaveSystem.save_dir` / `UiSettings.redirect_path`; tests use `user://test/…` only, wiped before each run; the git-SHA "core unchanged" test is replaced by a static scan of core code
- [x] Load the save on launch (B1); "Continue" really continues; a corrupt or future-version save warns and starts a new game (cold-start test added)
- [x] Fresh RNG seed per new game (B3): `Rng.new_game_seed()`; fixed seeds only for tests/screenshots (`Rng.fixed_seed_override`) and `-- --seed=N` for reproduction
- [x] Move screenshot / demo drivers out of main.gd → `tools/shot_driver.gd` (loaded dynamically only with a shot flag; shot runs also isolate saves and settings)

**Phase 1 · Decouple and localise the engine**

- [x] Remove campaign01 hard-coding from core / main (M1): the campaign is discovered from the packs folder; manifest `start` / `lock_text` / `entry`; bookkeeping keys judged by key shape; static guard test
- [x] Split main.gd (M2): campaign flow → `campaign_flow.gd`, sub-game flow → `subgame_flow.gd`, screenshot drivers → `tools/shot_driver.gd`; main.gd keeps only the app layer (service wiring, navigation, saves, store, lifecycle), 1861 → 783 lines
- [x] Event msg_key + args (core emits no prose); the full event stream is saved (E-3 decided), so no v2→v3 migration is needed (the new key is backward compatible)
- [x] Locale tables (`Texts` + texts_zh/texts_en) + `ui.locale` setting + a language button on the help page; convention-keyed pack text overlay (tech/02 §1.1) + packlint V15 (it already caught 2 packs missing their texts file)
- [x] English-length layout → done in Phase 2

**Phase 2 · English content**

- [x] Translate all pack and UI text: `texts_en.gd` (every source key, placeholders checked key by key) + `texts/en.json` for four packs (campaign01 323 keys / arena 44 / riddle_maze 32 / arc_tide 23) + operations data `_ops/texts/en.json`; every manifest declares `locales` and V15 passes. The Riddle Maze puzzles are dice checks with flavour hints, which keep their meaning in English — no rewrite needed
- [x] Wire the readers of the 5 write-only flags (M3): `text_variants` gains an `append` mode and works on endings; placed on R2 / N3-1 / N4-1 / E1 / E2 / E4 (zh + en); V4 now FAILs when a declared node/ending reader never reads
- [x] English-length layout (moved in from Phase 1): fixed from a `--locale=en` screenshot pass — entry labels wrap, status band ellipsis + scrolling party chips, main view clipping (also fixing the old battle-card overlap), flow-wrapped quickbar, scrollable help page; flag toasts show names instead of internal keys

**Phase 3 · Mobile platform layer (portrait)**

- [x] Orientation API, safe area, pause/resume, back button (tech/01 §10.1) — verified by desktop simulation and headless tests; device pass pending
- [x] Android / iOS export presets committed; audio via imported QOA (instead of Ogg, no external encoder); unused Bold font removed (−8 MB), Regular shared by both languages. The PCK is 9.5 MB, contains all 44 pack JSON files, and runs from outside the project
- [ ] Real-device pass (gesture thresholds, 44 pt targets, legibility, low-end Android performance) — needs export templates + Android SDK / full Xcode and real devices, not available on this machine

**Phase 4 · Store and monetization**

- [x] Act-level entitlement gate `entitlement.campaign01_full` (Act II to the Finale, tech/02 §2.2, checked by V9) + `entitlement.arena`; ops config `market_grants`: in the cn market the full campaign comes with the base game, in global it's the demo + unlock; after a refund the current run can finish (06 §5)
- [~] Store abstraction `shell/store` (purchase / restore / revoke) + locked-chapter screen + Restore Purchases entry — full flow tested with the mock store; **Google Play Billing / StoreKit adapters await the official plugins and store test accounts** (contract in `../store/billing-adapter.md`). A release build without an adapter has an unavailable store and never unlocks for free
- [~] Store listing copy, privacy policy and age-rating answers drafted (`../store/`); screenshots need rendering at store sizes; internal testing tracks need developer accounts

## P5 Framework expansion: a general tabletop-RPG engine (specified 2026-11-10)

Goal: turn the framework into a reusable D&D-style engine — new narrative games are made by changing story, art, music and theme data (whitepaper §14). Specs: docs 15–17, tech/07.

### 5.0 Documentation and layouts
- [x] Party split, perspective and remote play spec — `15-party-split-and-perspective-spec.md` (incl. portrait/landscape layouts, gestures, progression, multiplayer constraints)
- [x] Maps, travel and event tables spec — `16-map-and-exploration-spec.md` (region/site layouts for both forms)
- [x] Polyhedral dice spec — `17-polyhedral-dice-spec.md`
- [x] New-game kit — `../tech/07-new-game-kit.md`
- [x] Whitepaper §14, docs 04/07/09/12/13 and tech/02 updated with the new screens, keys, fields and validators
- [ ] Interactive layout prototype for the new screens (⑩ region map, ⑪ site map, split view) in `prototype/` or as a shareable page

### 5.1 Dice (smallest step, unblocks the rest)
- [x] `Dice3D` shape table: d4 / d6 / d8 / d10 / d12 (+ d100 as two d10) with per-shape face tests (`DiceShapes`; every shape settles on the given value)
- [x] DiceTray (multi-dice, ~1 s) with the On / Crits only / Off setting, and dice-strip shape glyphs in both shells
- [x] Core emits `dice` lists on check / attack / item / rest events (`table.roll` follows with 5.2)
- [x] Fixed: 3D dice meshes were wound counter-clockwise, so Godot culled the outer faces and showed the interior (hidden before by the near-black d20 body); number labels now alpha-discard

### 5.2 Maps and tables
- [x] `tables.json` loader + roller (modifiers, nested, `once`/`instead`), event cards, `table.roll` events with dice; packlint V20–V21
- [x] Region map: data, one-leg-per-press travel, pace, navigation checks, watches → Doom Clock (+ time-edge rescan), fog/reveal; ⑩ screen in both forms with tap and drag-the-token; packlint V19
- [x] Site map: areas/features/doors (stuck / locked + pick / secret + reveal), wandering table, on-enter tables, area encounters; same data in both forms (portrait compact area map + room card; landscape fogged map + side panel)
- [x] campaign01 "The Fog Coast": optional detour from the plaza hub — 5 locations (1 hidden), the Old Lighthouse site (4 rooms), 4 tables, 1 event card, a random ambush tuned into the easy band (88.5%)
- [ ] Maze beats as site presets (maze beats still run on their own runner)

### 5.3 Party split
- [x] Groups/threads/rejoin in StoryGraph (rejoin node entered once); per-character check rollers; `party_from: "group"` encounters; drift cap in node steps; packlint V16–V18
- [x] Divide-the-pack sheet (tap / drag onto a group; default split); each group uses only its own share while split
- [x] Group bar, "Meanwhile" ticker, focus switching (tap / portrait swipe), split view (portrait pane; landscape side by side); battles pause other groups
- [x] Links: remote edges (incl. messages as flag-writing remote edges) / help from afar / send item / move member between anchors (+1 Doom Clock); charges refill on a long rest
- [x] `progression` per playthrough (campaign01: split from run 1, links from run 2); demo "Split up: watch-house and archive" on the Fog Coast
- [ ] Player-chosen group assignment, companion lead (`lead: any`), timeout / recall rejoins, simultaneous battles (doc 15 §11)

### 5.4 New-game kit
- [x] Game manifest (`game/packs/_game/game.json`): default campaign, enabled packs, font, audio map — read by main / AudioManager / UITheme; `--packs-root` boots a different game
- [x] UI flavour overlay (`packs/_game/texts/<locale>.json`): 24 world-flavoured keys moved out of the framework tables, which keep neutral wording
- [x] Starter kit (`game/kit/_game` + `game/kit/starter`): packlint 0 FAIL, simulation 24/24 runs to the ending, 100% node coverage; excluded from exports
- [x] Bot simulation runs any pack and explores maps / sites / party splits (campaign01 coverage restored to 98.1% after the Fog Coast detour had dropped it to 83%)
- [x] Home-screen art and palette tokens from the manifest; win-rate tool for any pack (tech/07 §5; done in P6.1)

### 5.5 Multiplayer (later)
- [ ] Local pass-and-play seats → async online turns → real-time co-op (doc 15 §8)

## P6 World depth, balance and production assets (started 2026-11-10)

### 6.1 Framework follow-ups (from P5)
- [x] Palette tokens in the game manifest (`theme.palette`, `Palette` class) applied to the UI theme and shared sheets; optional `theme.home_art` image for the home screen
- [x] Win-rate tool for any pack (`tools/winrate.gd -- <games> <seed> <pack dir>`; act → level map from manifest `balance`); starter kit battles tuned into their bands
- [x] Party split extras: player-chosen groups (`"assign": "player"` + min/max/requires + assignment sheet), lead character (`lead: "any"` tier; Character screen "Make party lead"; condition `lead`), timeout rejoin (`timeout`) and recall link (`allow_recall`); packlint V16 checks them

### 6.2 Classes, backgrounds and items (worldview)
- [x] `classes.json`: three classes from the worldview's skill bundles — Harbor Guard / Scavenger / Ink Adept — each with attributes, Hit Die, proficiencies, basic attack, 3 class skills, starting gear
- [x] Backgrounds tied to Ashenport and its factions (Dockhand / Scriptorium Novice / Uninked Runaway / Salvager's Apprentice): proficiency, item, reputation, a written backstory
- [x] New-game screen: choose class + background (the existing hero stays as the default when none is chosen)
- [x] Conditions `hero_class` / `background`; class / background-gated options in campaign01
- [x] New items and props (consumables, gear per class, background keepsakes)

### 6.3 Companions and balance
- [x] Healing / support skills (utility `heal`), auto-play uses them
- [x] Companion second skills (Kelan: mending ink; Old Fei: brace) and per-class skills in battle
- [x] Rebalance every battle back into its band with the win-rate tool

### 6.4 Art and audio
- [x] Procedural assets: class portraits, unit art for every enemy (campaign01 + starter kit), starter-kit home illustration, new BGM (explore / map / ending), new SFX (coin, door, card, link, throw); map BGM state and SFX wired to events
- [x] Prompt pack for external AI tools (portraits, units, item icons, home art, map backgrounds, act scenes, store art, BGM, SFX) — `docs/en/tech/08-asset-prompts.md`
- [x] Map / site background images (`maps.json` `background` with a grid `frame`, doc 16 §6; packlint V19) and item icons on every item list (inventory, loadout, shop, battle quickbar; tech/05 §7.2); procedural placeholders for all of them

### 6.6 Animation and game UI
- [x] Character action animation (lunge / cast / throw / hop / brace / down / revive) and skill effects (14 kinds) — `ActionFx`, data `fx` / `attack_fx`, packlint V22, optional sprite strips (tech/05 §9)
- [x] Game UI kit for every control (palette-generated 9-slice frames, title / toast variations, optional title font and art overrides) and UI motion (button press, sheet pop-in, toast pop) — `UiKit` / `UiFx` (tech/05 §10)
- [x] Prompts for sprite strips, effect strips and a hand-drawn UI kit (tech/08 §3.4–§3.6)

### 6.5 Owner actions (outside the code)
- [ ] Generate final art and music with the prompt pack (tech/08) and replace the placeholders file by file (incl. optional animation / effect strips, UI frames and a title font)
- [ ] Store accounts, signing, devices, billing adapters (tech/06; `docs/en/store/`)
- [ ] Human playtest of the three classes and four backgrounds (feel, not just win rates); localisation review of the new English text

## Known gap

- tech/04 §5 effect-modifier runtime pipeline (base→add→mul→override→clamp + `effect.attach`/`effect.expire` events) is not implemented. No current content uses it (no pack has an effects.json); it must land before the first pack that uses modifiers ships.
