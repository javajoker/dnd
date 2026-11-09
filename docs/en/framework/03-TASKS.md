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
- [x] Sub-game doc layout convention: one subdirectory per sub-game at `docs/subgames/<name>/`, updated as needed
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
- [~] Split main.gd (M2): sub-game flow → `subgame_flow.gd`, screenshot drivers → `tools/shot_driver.gd` (1861 → 1156 lines); a CampaignFlow object is left for later — many tests drive main's campaign internals directly and need changing first
- [x] Event msg_key + args (core emits no prose); the full event stream is saved (E-3 decided), so no v2→v3 migration is needed (the new key is backward compatible)
- [x] Locale tables (`Texts` + texts_zh/texts_en) + `ui.locale` setting + a language button on the help page; convention-keyed pack text overlay (tech/02 §1.1) + packlint V15 (it already caught 2 packs missing their texts file)
- [x] English-length layout → done in Phase 2

**Phase 2 · English content**

- [x] Translate all pack and UI text: `texts_en.gd` (every source key, placeholders checked key by key) + `texts/en.json` for four packs (campaign01 323 keys / arena 44 / riddle_maze 32 / arc_tide 23) + operations data `_ops/texts/en.json`; every manifest declares `locales` and V15 passes. The Riddle Maze puzzles are dice checks with flavour hints, which keep their meaning in English — no rewrite needed
- [x] Wire the readers of the 5 write-only flags (M3): `text_variants` gains an `append` mode and works on endings; placed on R2 / N3-1 / N4-1 / E1 / E2 / E4 (zh + en); V4 now FAILs when a declared node/ending reader never reads
- [x] English-length layout (moved in from Phase 1): fixed from a `--locale=en` screenshot pass — entry labels wrap, status band ellipsis + scrolling party chips, main view clipping (also fixing the old battle-card overlap), flow-wrapped quickbar, scrollable help page; flag toasts show names instead of internal keys

**Phase 3 · Mobile platform layer (portrait)**

- [ ] Orientation API, safe area, pause/resume, back button (tech/01 §10.1)
- [ ] Android / iOS export presets; Ogg audio; per-language font loading
- [ ] Real-device pass (gesture thresholds, 44 pt targets, legibility, low-end Android performance)

**Phase 4 · Store and monetization**

- [ ] Act-level entitlement gate `entitlement.campaign01_full` (tech/02 §2.2) + `entitlement.arena`
- [ ] Google Play Billing / StoreKit 2, restore purchases, refund handling
- [ ] Store assets, privacy policy, age rating, internal testing track

## Known gap

- tech/04 §5 effect-modifier runtime pipeline (base→add→mul→override→clamp + `effect.attach`/`effect.expire` events) is not implemented. No current content uses it (no pack has an effects.json); it must land before the first pack that uses modifiers ships.
