# Documentation Index (English)

> The design source of truth (English only). The earlier Chinese originals are archived read-only in [`archive/zh-CN/docs/`](../../archive/zh-CN/docs/). Terms follow [`GLOSSARY.md`](GLOSSARY.md).
>
> The repo has three layers: **framework/** is the game framework that doesn't change with the story (design intent), **tech/** is the framework's technical implementation, and **story/** is the world and content that grows on top of the framework.
>
> **Layout convention**: one subdirectory per sub-game, `docs/en/subgames/<name>/`; campaign books go in `story/`. Pack data lives only in `game/packs/<pack_id>/` (no copy under `docs/`).
>
> **Interactive prototype**: [`prototype/`](../../prototype/) at the repo root (zero dependencies; open `index.html` in a browser) — a playable slice of the nine screens from doc 04.
>
> **Production build**: [`game/`](../../game/) (Godot 4.7.2 + GDScript, tech/01 §2.3). Engineering discipline is enforced by `.claude/`: skills `godot-dev` (workflow) / `godot-acceptance` (acceptance audit) + agent `godot-developer`; English versions `godot-dev-en` / `godot-acceptance-en` / `godot-developer-en`.
>
> **Latest code review**: [`tech/code-review-2026-11-10.md`](tech/code-review-2026-11-10.md) — verified status of every checklist claim.

## framework/ — the game framework (common to every content pack)

| Doc | Content |
|---|---|
| [01 Framework Whitepaper](framework/01-framework-whitepaper.md) | Five-layer funnel, World State Machine, branching directed graph, encounter state machine, two campaign forms, content packs, rule packs and the entitlement model |
| [02 PRD](framework/02-PRD.md) | Product positioning, functional requirements F1–F8, milestones M0–M4, risks |
| [03 TASKS](framework/03-TASKS.md) | Checklist from P0 framework freeze → P1 main line → P2 content pipeline → P3 operations, with verified status |
| [04 UI/UX Design](framework/04-ui-ux-design.md) | Nine screen specs, landscape five-zone / portrait three-band layouts, navigation-loop checklist |
| [05 Rules System Framework](framework/05-rules-system-framework.md) | D20 minimal core, the six rule-pack elements, Light / Standard / Deep presets |
| [06 Monetization Framework](framework/06-monetization-framework.md) | Entitlement model, per-pack strategy choice (gates in the pack, lighting by operations), four business models, monetization no-go zones |
| [07 World State Machine Spec](framework/07-world-state-machine-spec.md) | Field definitions of the six variable kinds, namespaces, save snapshots, Doom Clock behavior |
| [08 Branching Model Spec](framework/08-branching-model-spec.md) | Five edge types, three failure-path patterns, convergence strategy and branch budget |
| [09 Encounter and Dual-Mode Spec](framework/09-encounter-and-dual-mode-spec.md) | Six encounter states, mode declaration and entry branch, frozen layout metrics for both forms, dice-presentation tiers |
| [10 Items and Compendium Spec](framework/10-items-and-compendium-spec.md) | Four-identity tags, rarity and placement, Compendium series and the completion-reward whitelist |
| [11 Light Rule Pack v1](framework/11-light-rulepack-v1.md) | Numbers for the six elements: 3 attributes, DC 8/12/16, three-part action economy |
| [12 Gesture and Interaction Spec](framework/12-gesture-and-interaction-spec.md) | Gesture vocabulary and parameters, scene mapping, conflict resolution, first-run tutorial and help page, Home hotspot illustration |
| [13 Feature Checklist and Loops](framework/13-feature-checklist-and-loops.md) | Full feature CHECKLIST: interaction completeness, prototype vs Godot comparison, gap summary |
| [14 Presentation and Platform Checklist](framework/14-presentation-and-platform-checklist.md) | Productisation roadmap: P0 ritual (font / dice / hit feel), P1 atmosphere (audio / art / transitions), P2 platform, P3 operations tech |
| [15 Party Split, Perspective and Remote Play](framework/15-party-split-and-perspective-spec.md) | Groups and threads, focus switching and split view, links (remote interaction / teleport), progression per playthrough, multiplayer constraints |
| [16 Maps, Travel and Event Tables](framework/16-map-and-exploration-spec.md) | Region point-crawl, site maps in both forms, choose → roll → outcome tables, event cards |
| [17 Polyhedral Dice](framework/17-polyhedral-dice-spec.md) | d4–d100 usage and presentation tiers (strip / tray / key), fairness, event data |

## tech/ — technical implementation

| Doc | Content |
|---|---|
| [01 Technical Approach](tech/01-technical-approach.md) | Engine choice, logic/presentation layering, state machine and event-stream architecture, rule-pack host, prototype plan |
| [02 Content Pack Format Spec](tech/02-content-pack-format-spec.md) | Pack layout, manifest (mode / entitlement gate / monetization), five-edge condition DSL, table schemas, go-live validation V1–V14 |
| [03 Content Pack Authoring Guide](tech/03-content-pack-authoring-guide.md) | Campaign book → pack data transcription flow, section mapping, validator error table, review checklist |
| [04 Resources and Effects System](tech/04-resources-and-effects-system.md) | Schemas for characters / skills / items / effects, the modifier pipeline (base→add→mul→override→clamp), growth system |
| [05 Art Pipeline](tech/05-art-pipeline.md) | Asset directories, naming, resolution tiers, placeholder fallback, `art_ref` |
| [06 English Mobile Plan](tech/06-english-mobile-plan.md) | Decision record and phased plan for the English mobile release |
| [07 New-Game Kit](tech/07-new-game-kit.md) | What a new game supplies (story, art, music, theme, game manifest) and what the engine provides; the ten-step recipe |
| [08 Asset Prompt Pack](tech/08-asset-prompts.md) | Copy-ready prompts and delivery specs for generating portraits, units, icons, scenes, maps, store art, music and sound with external AI tools |
| [09 Build and Release Guide](tech/09-build-and-release-guide.md) | Exact setup and commands for Android (debug APK, release AAB) and iOS (Xcode, TestFlight): tools, templates, signing, store upload |
| [store/](store/store-listing.md) | Store listing draft, [privacy policy](store/privacy-policy.md), [billing adapter contract](store/billing-adapter.md) |
| [Code review 2026-11-10](tech/code-review-2026-11-10.md) | Review of `game/` and verification of the TASKS / 13 / 14 checklists |

## story/ — world and main-line content

| Doc | Content |
|---|---|
| [01 World: The Age of the Codex](story/01-world-age-of-the-codex.md) | The continent of Elowen, the Fading, the Unwritten and the Fatedie, factions, chapter regions |
| [02 Campaign Book: Ashenport Fragments](story/02-campaign-ashenport-fragments.md) | First main campaign: 35-node five-act structure, 16 encounters, 4 ending types |
| [03 Final Balance and Boss Design](story/03-balance-and-boss-design.md) | Difficulty targets and simulation calibration, boss behavior scripts, final enemy stats |
| [04 Side Arc: Echoes of Fog Wharf](story/04-side-arc-echoes-of-fog-wharf.md) | arc_tide, grafted onto N1-1 without touching main-line data |
| [campaign01/](story/campaign01/README.md) | *Ashenport Fragments* pack data notes and transcription decision log |

## subgames/ — one subdirectory per sub-game

> Sub-game = a content pack that reuses the encounter state machine and swaps rule parameters and presentation (whitepaper §10.2).
> Entering and leaving must pass through the Settlement screen; writing the Board is a hard requirement (doc 04 §6).
> Like any pack, a sub-game can declare its own monetization strategy (manifest `monetization`, tech/02 §2.3).

| Directory | Sub-game | Status |
|---|---|---|
| [subgames/arena](subgames/arena/01-concept.md) | Arena Gauntlet | Live (DLC demo of the full entitlement chain) |
| [subgames/riddle-maze](subgames/riddle-maze/01-concept.md) | Riddle Maze | Live (zero-combat puzzle sub-game; free) |
| subgames/haven | Haven Management (candidate) | Not started |
