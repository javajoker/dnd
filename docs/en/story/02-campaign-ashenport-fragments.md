# Campaign Book: *Ashenport Fragments*

> Version: v0.1 (draft)
> Related docs: `01-world-age-of-the-codex.md`, `../framework/01-framework-whitepaper.md` (branching model / campaign modes), `../framework/05-rules-system-framework.md` (Light rule pack)
> Scope: the complete content design of the first main campaign: node graph, placement of the five edge types, flags, quest/encounter lists, item placement and ending types. Numeric details are finalised together with the Light rule pack (linked to M1).
> English mirror of `docs/story/02-战役书-烬港残页.md`. Terms follow `../GLOSSARY.md`.

---

## 1. Campaign card (L1 metadata)

| Field | Value |
|---|---|
| Campaign ID | campaign01 |
| Rule pack | Light rule pack v1 (3 attributes / three difficulty tiers / three-part action economy) |
| Recommended level | 1–4 |
| Estimated length | 6–9 hours (including one side-chain replay) |
| Mode declaration | **Dual-mode (player's choice)**; exception: Act III is **forced Portrait · Temporal** (narrative reason: fragments and remembrance, see world §8); the Prologue follows the player's chosen form (choosing landscape starts in landscape from the very first scene) |
| Ending types | 4 (E1 Re-inked / E2 Free Ash / E3 A New Page / E4 The Fading Takes the Harbor) |
| Node budget | 35 nodes (Prologue 4 + Act I 8 + Act II 12 + Act III 7 + Finale 4) |

## 2. Synopsis

You wake to the sound of the tide in Ashenport with no codex page in your arms. The port city is being erased by the Fading: first a place name, then a street, then someone's daughter. The Scriptorium wants to repair the Scroll, the Uninked want to tear it up, and the Salvage Guild just wants to profit from the chaos — and all three need the Fatedie in your hand. You track the Fading to its source, enter the old quarter that has already been revoked, and finally, atop the Tide Tower, face one question: **should this book be mended, burned, or rewritten by you?**

## 3. Overall structure

```
Prologue "Tidewake" ──→ Act I "The Faded Street" ──→ Act II "Three Pens" ──→ Act III "The Revoked Quarter" ──→ Finale "The Harbor's Last Page"
 (dual-mode)             (dual-mode)                 (dual-mode)              (forced portrait)                  (dual-mode)
  tutorial, 4 nodes       investigation + 3 factions  faction side-chains      room-sequence remembrance          boss + choice + ending
```

## 4. Storyline node graph (L2)

Edge-type tags: `[C]` choice edge, `[K]` check edge (success/failure paths), `[I]` item edge, `[T]` time edge, `[R]` reputation/alignment edge

### SL-0 Prologue "Tidewake" (dual-mode, tutorial)

```
N0-1 Tidewake (cutscene)
  └─→ N0-2 The Vanished Pier Name (check tutorial: Perception · easy)
        ├─ success ─→ N0-3a You see the ink fading (gain flag: seeing_is_believing)
        └─ failure ─→ N0-3b A passer-by's terrified account (no flag, small XP compensation)
                    ↓ both paths converge
              N0-4 Three Gazes (cutscene: three stares fall on you) ──→ Act I
```

Tutorial duties: the console's three tabs and always-visible dice strip, quick dice rolls, dialogue options, viewing the log.

### SL-1 Act I "The Faded Street" (dual-mode, 8 nodes)

```
N1-1 Free City Plaza (Hub: rest / shop / rumors)
  └─→ N1-2 Investigate the faded site [K · Investigation · medium]
        ├─ success → locate N1-3 directly
        └─ failure → N1-2b Stray into the cordoned alley (small battle) → N1-3 (late: Doom Clock +1 segment)
N1-3 Witness a Revocation (cutscene: a street vanishes before your eyes; Doom Clock +1; flag: witnessed_revocation)
  ├─→ N1-4 Scriptorium contact (a grey-robed friar's probing)
  ├─→ N1-5 Uninked contact (a black-feather messenger)
  ├─→ N1-6 Salvage Guild contact (an auction-house invitation)
  └─ decline every invitation → N1-8 (no contact, reputation stays 0)
        ↓ the three contact nodes can be done in any order; each grants starting reputation
N1-7 Midnight Ink Rain (tutorial boss battle: Ink Fiend — twisted text born of the Fading)
  └─→ N1-8 Three Invitations [C]
        ├─ Scriptorium commission → Act II S chain
        ├─ Uninked commission → Act II U chain
        ├─ Salvage Guild commission → Act II G chain
        └─ "I trust no one" [R · available only when all three reputations ≤ 0] → Act II L lone-wolf shortcut
```

### SL-2 Act II "Three Pens" (dual-mode, 12 nodes)

Pick one of four chains as the main path; the other two are mentioned as "rumors" in events (recorded on the Board, can be completed on later playthroughs).

```
[Scriptorium chain]
N2S-1 Archive Trial [K · History/Perception · medium]
  ├─ success → N2S-2; failure → sentenced to copying-penance (costs 1 Doom Clock segment) → N2S-2
N2S-2 The Restoration Rite (escort battle: protect the scribe while they locally re-ink)
  └─→ N2S-3 The Price of Gold Ink [C]
        ├─ give up a piece of your own memory → Doom Clock -2, flag: blank_memory (bonus toward a personal ending)
        └─ refuse → Scriptorium reputation +1, Doom Clock -1

[Uninked chain]
N2U-1 Black Feather Gathering [K · Stealth · medium]
  ├─ success → overhear the plot; failure → exposed (battle) → win your admission by force
N2U-2 Page-Tearing Operation (battle + [C]: tear out the tax collector's page of fate?)
  ├─ tear → Uninked reputation +2, flag: page_tearer (the tax collector vanishes from everyone's memory)
  └─ spare → reputation +1, flag: showed_mercy (the tax collector gives key testimony in the Finale)
N2U-3 Ashes of Freedom (cutscene: the consequences of tearing appear, Doom Clock +1)

[Salvage Guild chain]
N2G-1 Fragment Auction [K · Persuasion · medium, or pay gold]
  └─→ N2G-2 Fog Wharf Salvage (maze-exploration encounter)
        ├─ [I · Half-Page Tide Chart] → opens a secret passage straight to the Sunken Library (extra loot + Weaver's Fragment ×1)
        └─ no item → detour route (2 extra encounters)
N2G-3 The Truth in the Ledger (cutscene: the Guild knew the Fading was coming; gain flag: insider)

[Lone-wolf shortcut] (entered via [R] or [K · hard])
N2L-1 Investigate Alone [K · Investigation · hard]
  ├─ success → straight to the truth (skips one side-chain's worth of content, Doom Clock -1, but no faction reputation)
  └─ failure → wanted by all three factions (punishment battle, then forced to pick a chain, and reputation -1)

[Convergence]
N2-C Piecing Together the Three Factions' Intel (cutscene) → unlocks Act III
  Entry condition: any chain has completed N2x-3 (or N2L-1 succeeded)
```

### SL-3 Act III "The Revoked Quarter" (forced portrait · room sequence, 7 nodes)

Narrative wrapper: the revoked old quarter survives only as fragments and can only be "replayed" one room at a time — this is the reason for the forced Portrait · Temporal form.

```
N3-1 Enter the Revoked Quarter (mode-lock cutscene) → room sequence:
R1 Faded Dwelling (pickup/check room: traces of the revoked residents' lives)
R2 Empty Classroom (dialogue room: a child who still remembers their own name [K · Soothe · medium]; failure → the child dissolves, flag: could_not_save)
R3 Ink Fiend Nest (battle room)
R4 Forking Corridor (branch door: [I · Black Feather Token] opens the left shortcut / right path is two battles)
R5 The Page Warden (boss battle: an automatic scribing golem left behind by the Scriptorium)
  └─→ N3-7 The Blank Plaza (Finale entrance; landscape unlocks from here)
```

### SL-4 Finale "The Harbor's Last Page" (dual-mode, 4 nodes)

```
N4-1 Top of the Tide Tower (final boss battle: the Inktide Avatar, incarnation of the Fading tide)
  └─→ N4-2 The Choice [C + R + I]
        ├─ Mend the Scroll → E1 (requires Inkbound alignment > midline)
        ├─ Burn the remnants → E2 (requires Blankward alignment > midline)
        ├─ Write a new page → E3 (requires [I · Weaver's Fragment ×4 complete] and any Bond ≥ 60)
        └─ no condition met / Doom Clock already full → E4 The Fading Takes the Harbor
N4-3 Ending cutscene (four types)
N4-4 Epilogue and settlement (writes Board: unlocks NG+ carry-overs)
```

## 5. Flag design (namespace campaign01.*)

| Flag | Written at | Read at |
|---|---|---|
| seeing_is_believing | N0-3a | R2 dialogue bonus, History Scroll provenance example |
| witnessed_revocation | N1-3 | Attitude changes in the three contact nodes |
| blank_memory | N2S-3 | E1 ending cutscene variation |
| page_tearer | N2U-2 | Tax collector absent in the Finale, E2 bonus |
| showed_mercy | N2U-2 | Tax collector's testimony before N4-1 (lowers boss difficulty) |
| insider | N2G-3 | Extra opening line at N3-1, Compendium entry unlock |
| could_not_save | R2 | E4 cutscene weighting, Bond events |
| fragment count (0–4) | N2G-2 secret passage + hidden spots in each chain | N4-2 E3 unlock condition |

Global variable reads/writes: Fading level (Doom Clock), reputation with four factions, Inkbound↔Blankward alignment, three Bond values (Bond placement points: see the data pack `campaign01/nodes.json` and the transcription decision log in its README).

## 6. Quest / event list (L3)

| Event | Trigger | Goal | Board writes on settlement |
|---|---|---|---|
| Strange Tales of the Pier | Automatic in Prologue | Complete the N0-2 check | XP + flag |
| The Vanishing Street | N1-2 complete | Reach N1-3 | Doom Clock +1, flag |
| Three Calling Cards | After N1-3 | Complete N1-4/5/6 | Starting reputation with three factions |
| Ink-Rain Night Raid | Doom Clock reaches 2 [T] | Win N1-7 | XP + loot |
| Archive Commission | Choose S chain [C] | Complete N2S-1~3 | Scriptorium reputation, Doom Clock -1/-2 |
| Black Feather Operation | Choose U chain [C] | Complete N2U-1~3 | Uninked reputation, flags |
| Salvage Contract | Choose G chain [C] | Complete N2G-1~3 | Salvage reputation, fragments |
| Going In Alone | Hidden choice at N1-8 [R] | N2L-1 | High-risk, high-reward settlement |
| Exploring the Revoked Quarter | N2-C | Clear R1–R5 | Compendium entries ×2, boss loot |
| The Last Page | N3-7 | Clear the Finale | Ending type + NG+ carry-over |

## 7. Encounter list (L4, 16 in total)

| Encounter | Type | Form | Difficulty |
|---|---|---|---|
| N1-2b Cordoned Alley | Battle | Follows campaign mode | Easy |
| N1-7 Midnight Ink Rain | Battle (tutorial boss) | Follows campaign mode | Easy |
| N2S-2 Restoration Rite | Escort battle | Follows campaign mode | Medium |
| N2U-1 Exposure Battle | Battle (failure path) | Follows campaign mode | Medium |
| N2U-2 Page-Tearing Operation | Battle + choice | Follows campaign mode | Medium |
| N2G-2 Fog Wharf | Maze exploration | Follows campaign mode | Medium |
| N2G-2b Sunken Library | Maze exploration (secret passage) | Follows campaign mode | Medium |
| N2G-2c Detour Route | Maze exploration (2 extra) | Follows campaign mode | Medium |
| N2L-1b Wanted Battle | Battle (punishment) | Follows campaign mode | Hard |
| R1 Faded Dwelling | Pickup/check | Forced portrait | Easy |
| R3 Ink Fiend Nest | Battle | Forced portrait | Medium |
| R4-r Corridor Right Path | Battle ×2 | Forced portrait | Medium |
| R5 The Page Warden | Boss battle | Forced portrait | Hard |
| N4-1 Top of the Tide Tower | Final boss | Follows campaign mode (landscape recommended) | Hard |
| N1-1 Plaza | Rest | Dual-mode | — |
| N3-7 Blank Plaza | Rest + cutscene | Forced portrait | — |

Mix: 8 battles / 4 maze explorations / dialogue checks scattered across nodes / 2 rests. ≤6 units on screen; every forced-portrait chapter satisfies the portrait battle constraint (04 doc §④.4). (N2G-2c and R1 were registered during the data-transcription stage; see the campaign01/README decision log.)

## 8. Item table and branch-key placement

| Item | Identity | Placement | Edge it opens |
|---|---|---|---|
| Half-Page Tide Chart | Branch key | N1-1 shop / N1-2 hidden pickup | N2G-2 secret passage [I] |
| Black Feather Token | Branch key | N2U-2 complete (given whether you tear or spare) | R4 left shortcut [I] |
| Scriptorium Signet | Branch key | N2S-3 | Persuade the guards to stand down before N4-1 [I/R] |
| Weaver's Fragment ×4 | Compendium + branch key | Secret passage ×1, R2 hidden ×1, R5 ×1, NG+ carry-over ×1 | E3 ending [I] |
| Fatedie (story item) | Core of the presentation | Starts with you in the Prologue | All key checks |
| Ink Core ×3 | Numeric (upgrade stone) | Loot from each boss | — |
| Supply Potion | Numeric (consumable) | N1-1 shop (15 gold placeholder) / brought in from Prologue ×2 | — |

## 9. Ending types

| Ending | Condition | Content | NG+ hook |
|---|---|---|---|
| E1 Re-inked | Inkbound > midline | The port city is rewritten, but those who sacrificed themselves stay blank forever | Unlocks rumor of the Holy City of Scribes |
| E2 Free Ash | Blankward > midline | Ashenport breaks free of the Weave — free, and slowly crumbling | Unlocks rumor of the Torn-Page Wastes |
| E3 A New Page (hidden) | Fragments ×4 + Bond ≥ 60 | The Unwritten becomes the new Penbearer | Unlocks the "Penbearer" starting origin |
| E4 The Fading Takes the Harbor | No condition met, or clock full | The port city is revoked; you leave carrying scraps of the codex | Carries the scraps over; NG+ begins with the "Remembrance" perspective |

E4 is a failure but not a dead end (whitepaper §5.2): finishing on E4 still records all collection and Compendium progress, and unlocks an NG+-exclusive perspective.

## 10. Branch-graph self-check (against the validation checklist)

| Check | Result | Notes |
|---|---|---|
| Every check edge has a failure path | ✅ | N0-2 / N1-2 / N2S-1 / N2U-1 / N2G-1 / N2L-1 / R2 all have failure paths |
| No unreachable nodes | ✅ | The lone-wolf shortcut has two entrances: [R] and [K · hard] |
| Flags closed-loop (every write has a read) | ✅ | See §5 table |
| Doom Clock moves both ways (accelerate/delay) | ✅ | +1: N1-3, N2U-3, N1-2 failure; -1/-2: N2S-3, N2L-1 |
| Node budget 35 | ✅ | 4+8+12+7+4 |
| Forced-portrait chapters meet the on-screen constraint | ✅ | All of Act III ≤6 units |

## 11. NG+ carry-over list (final)

**Balance principle**: carry over "narrative position and collections", never raw power (the same philosophy as the monetization no-go zones — the NG+ advantage is information and perspective, not dice).

| Category | Content | Notes |
|---|---|---|
| Common carry-over | Compendium (global.lore) / entitlements (global.entitlement.*) / cosmetics (global.cosmetic.*) / Weaver's Fragment ×1 / playthrough count | The fragment is E3's 4th one (closes the collection loop); acquired cosmetics and entitlements never downgrade |
| E1 Re-inked | flag `unlock_elysium_rumor` (rumor of the Holy City of Scribes) | Future DLC entry hook, narrative only |
| E2 Free Ash | flag `unlock_wastes_rumor` (rumor of the Torn-Page Wastes) | Same as above |
| E3 A New Page | **"Penbearer" starting origin**: different opening monologue + Fatedie presentation skin "Penbearer's Die" (cosmetic slot, pure presentation) | The hidden ending's reward is identity and presentation — no attribute points or skill power |
| E4 The Fading Takes the Harbor | **"Remembrance" perspective**: Prologue cutscene variation (faded-filter text) + one more fragment + different first NPC dialogue | The failure ending's compensation is narrative depth, consistent with "failure is a branch" |

Implementation: declared in `manifest.ngplus` (carries / per_ending unlocks); carry-over logic is data-driven.

## 12. Open items

- Per-node dialogue and text-volume budget (writing phase; external `text_ref` integration in progress);
- Boss balance is fine-tuned per version from playtesting (story/03 has the finalised baseline and the winrate tool).
