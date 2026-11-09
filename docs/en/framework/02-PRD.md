# Product Requirements Document (PRD)

> Version: v0.1 (draft)
> Related docs: `01-framework-whitepaper.md`
> Scope: this PRD defines product and feature requirements, not the technical design; specific worldbuilding and story content are planned separately.
> English mirror of `docs/framework/02-PRD.md`. Terms follow `../GLOSSARY.md`.

---

## 1. Product overview

A mobile game offering a D&D-style tabletop experience: players adventure through a five-layer narrative structure (Epic → Campaign → Arc → Quest → Encounter); every choice and check is written to the World State Board, producing story branches that differ for every player. The same encounter core powers two campaign forms — Landscape · Spatial campaigns and Portrait · Temporal campaigns — with the mode chosen on entry or mandated by the main line.

**One-line positioning**: one phone, two perspectives, one tabletop world that keeps growing new stories.

## 2. Target users

| Segment | Traits | What we give them |
|---|---|---|
| Tabletop / D&D fans | Know D20, checks, character creation | The ritual of the rules: rolling with your own hand, failure that matters, real branches |
| Story-driven RPG players | Care about narrative and consequences | Directed-graph branches + Board-driven "choices that count" |
| Short-session mobile players | One-handed, commuting, short sessions | Portrait temporal mode + 10–20 minute encounters |
| Collectors / replayers | Chase Compendium completion and every branch | Four item identities + differences in branch topology |

## 3. Core experience goals

1. **The ritual of the roll**: the D20 is the emotional peak; key checks get a full-screen physical presentation;
2. **Choices really count**: afterwards, players can trace "it was that choice that led here";
3. **Failure is interesting too**: every failed check leads to a path with content;
4. **Each form plays to its strengths**: landscape lays out space, portrait flows through time; choosing the mode on entering a campaign is itself a branching decision;
5. **The world keeps growing**: every update has new branches to play, and old saves stay valid.

## 4. Release scope

### 4.1 v1.0 (launch): framework + first main campaign

Includes:

- World State Machine (six variable kinds) and save snapshots;
- Story directed-graph runtime (five edge types, trigger scanning);
- All encounter state-machine states (explore / discover / combat / dialogue / settlement / rest);
- Both Landscape · Spatial and Portrait · Temporal campaign forms, the campaign-entry mode branch, and the forced-mode mechanism;
- Item and Compendium system (four identities);
- Content-pack loading and version compatibility;
- Rule-pack mechanism (D20 minimal core + Light rule pack at launch, F7) and the monetization entitlement model (F8);
- The first main campaign content pack (content designed separately).

### 4.2 v1.x (continuous iteration: dual track)

**Content track** (ship, expand the world, build and iterate at the same time):

- New story-branch content packs;
- New campaign content packs;
- The first sub-game content pack (a variant mode reusing the encounter state machine).

**Operations track** (live-ops iteration):

- Per-pack choice and per-version adjustment of monetization strategy (how entitlements are lit, pricing, subscription sets);
- Events and entitlement grants (limited-time free, achievement unlocks);
- New cosmetic / presentation items.

The two tracks are decoupled and can ship independently (whitepaper §10.4).

### 4.3 Explicitly out of scope (this phase)

- Online / multiplayer co-op;
- UGC (player-created content) editor;
- Pay-for-power systems (payment-point design awaits a separate review);
- Worldbuilding and specific story content (produced with the content projects).

## 5. Functional requirements

### F1 Dual-mode presentation (campaign level)

- F1.1 A campaign book declares its presentation mode: Landscape · Spatial / Portrait · Temporal / dual-mode;
- F1.2 Dual-mode campaigns: on entering, offer the player a mode-choice branch; record the result on the Board;
- F1.3 Forced mode: the main-line design can force a campaign into one mode; the entrance shows no choice and presents the reason narratively;
- F1.4 The mode is locked for the duration of a campaign; the other mode can be a replay path;
- F1.5 Zero data difference between the two forms of the same campaign: progress, numbers and results are identical;
- F1.6 No in-game landscape/portrait rotation switching.

### F2 Encounter loop (single session)

- F2.1 Full flow through the six states: enter → explore ⇄ discover → combat / dialogue → settlement → rest → exit;
- F2.2 Turn-based combat: initiative order; three-part action economy (move / action / bonus action);
- F2.3 Check system: D20 + modifier vs difficulty, producing success/failure branches;
- F2.4 Tiered dice presentation: normal checks resolve quickly; key checks (death saves, story turning points) get full-screen presentation;
- F2.5 Settlement writes to the World State Board: XP, loot, flags, reputation, Doom Clock advance.

### F3 Branching and triggers

- F3.1 All five edge types available: choice / check / item / time / reputation-alignment;
- F3.2 Failure is a branch: every check edge must have a failure path;
- F3.3 Branch-graph validation tool (content side): detects dead ends and unreachable nodes before going live;
- F3.4 Player traceability: the log can show the source event of key flags.

### F4 Items and collection

- F4.1 Four item identities: numeric / check modifier / branch key / Compendium;
- F4.2 Compendium completion rewards: unlock background entries and hidden entrances.

### F5 Content-pack mechanism

- F5.1 Content packs are released and updated independently, without a framework upgrade;
- F5.2 A content pack declares the minimum framework version it needs; the framework is backward compatible;
- F5.3 The Board is namespaced per content pack; multiple packs coexist without conflict;
- F5.4 Old saves stay valid after new packs go live, and new content can apply to old saves.

### F6 Saves

- F6.1 A save = a World State Board snapshot;
- F6.2 New Game+ supported: when restarting a campaign, players can keep part of their collection progress (exact rules set with the main-line design).

### F7 Rule-pack mechanism

- F7.1 Rule depth is a framework extension axis: the D20 minimal core is fixed; rule packs carry six elements such as the attribute model / check formula / action economy / growth curve;
- F7.2 A campaign declares the rule pack and minimum version it needs; campaigns of different rule depths can coexist;
- F7.3 The first main campaign launches on the Light rule pack; later packs can introduce deeper rules;
- F7.4 Rule packs are versioned independently; an in-progress campaign in an old save can be frozen on the old rule-pack version to finish.

### F8 Monetization capability

- F8.1 Entitlement model: entitlements are global Board variables; content packs declare unlock conditions; purchases / events / achievements can all light entitlements;
- F8.2 **Strategy chosen per pack**: the framework supports every monetization strategy (premium / content-pack DLC / subscription / cosmetic presentation, plus future models that land on the entitlement model); each campaign / sub-game independently declares the strategies it participates in, which can be mixed and adjusted per version with operations decisions, without changing the framework or content graph;
- F8.3 Monetization no-go zones: never tied to check results, never break the integrity of free branches, never sell numeric power;
- F8.4 Paid content packs go through the same validation and screen-loop checks as free ones.

## 6. Milestones (product cadence)

| Milestone | Deliverable | Exit criteria |
|---|---|---|
| M0 Framework freeze | Whitepaper finalised; all design specs reviewed | Whitepaper v1.0 signed off |
| M1 First main campaign | Worldbuilding + main campaign content design complete | Branch-graph validation passes; full internal playthrough works |
| M2 Launch | v1.0 live | Framework + first campaign running stably |
| M3 First sub-game | Sub-game rules design and content pack | Validates the "sub-games don't touch the framework" extension promise |
| M4 Live operations | Regular cadence of branch / campaign content packs | A stable content-update pipeline |

## 7. Success metrics (directional; numbers to be refined in the operations project)

- Mode-choice distribution in dual-mode campaigns, and the correlation of the chosen mode with retention (validates that "dual form" isn't a fake need);
- Encounter completion rate and encounter-length distribution (validates the 10–20 minute pacing assumption);
- NG+ start rate (validates whether branch differences are perceived);
- Return rate after content-pack updates (validates the continuous-delivery model).

## 8. Risks and open questions

| Risk / question | Description | Suggested handling |
|---|---|---|
| Branch explosion | The directed graph grows out of control; content production can't keep up | Node convergence strategy + validation tool; set budgets in main-line design |
| Readability of big portrait battles | Portrait experience degrades with 10+ units on screen | Level-design constraints (many rooms, few on screen) + smart camera |
| Cost of dual-mode development | Two renderers mean every feature's presentation is built twice | Freeze interaction specs early; M0 outputs a dual-mode component list |
| Content-pack compatibility | Old framework can't read new content / new framework breaks old content | Add version declarations and compatibility tests to the pack go-live checklist |
| Rule-depth trade-off | Resolved: the framework has a built-in rule-pack mechanism with coexisting depths (F7); the first main campaign uses the Light rules | See `05-rules-system-framework.md` |
