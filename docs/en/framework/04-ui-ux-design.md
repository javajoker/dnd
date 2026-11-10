# UI/UX Design Document (framework level)

> Version: v1.1 (final; v1.1 adds the Home hotspot-illustration direction and pointers to the gesture spec)
> Related docs: `01-framework-whitepaper.md`, `02-PRD.md`; dice-presentation tiers in `09-encounter-and-dual-mode-spec.md` §6; **the full gesture vocabulary, tutorial and help-page rules are in `12-gesture-and-interaction-spec.md`**
> Scope: defines, from the framework's point of view, the duty, structure and navigation loop of every screen — **every screen is a view of the World State Board or the event stream**. No visual comps or pixel specs (those belong to the prototype stage, planned separately).
> English mirror of `docs/framework/04-UI-UX设计文档.md`. Terms follow `../GLOSSARY.md`.

---

## 1. Design principles

1. **Every screen is a view of state**: screens hold no data; they only read the World State Board and the event stream; screens appear and disappear driven by Board changes (consistent with the whitepaper §4 iron rule).
2. **Closed-loop navigation**: every screen has a clear way in (entrance) and a way out (exit); the player never gets stuck at a dead end.
3. **One main focus**: only one main content area on screen at a time; other information lives at persistent edges or in sheets.
4. **Tiered sense of ritual**: emotional peaks such as dice rolls and key story moments own the screen; routine actions are light and fast.
5. **Framework before content**: the screen structures defined here are common to every campaign, arc and sub-game pack; content only fills them and never changes the structure.

## 2. Information architecture and navigation loop

Nine kinds of screens make up the complete game loop:

```
                        ┌──────────────┐
                        │ ① Home (Camp) │
                        └──────┬───────┘
        ┌──────────┬───────────┼───────────┬──────────┐
        ▼          ▼           ▼           ▼          ▼
  ② Campaign   ⑤ Event      ⑥ Inventory  ⑦ Character  ⑧ History
     Entry        Center       Compendium                Scroll
        │
        ▼ (dual-mode campaigns branch here: Landscape Spatial / Portrait Temporal; single-mode campaigns go straight in)
   ③④ Encounter (rendered in the campaign's declared form)
        │
        ▼
   ⑨ Settlement ──→ back to ① Home / next encounter / view new ⑧ scroll entries
```

Conventions:

- **Home is the only hub**: every feature screen is entered from Home and returns to Home when done;
- **The campaign line is the main artery**: Home → Campaign Entry → Encounter → Settlement → Home; one lap = one meta loop (whitepaper §9);
- ⑧ History Scroll is the only screen that can be summoned as a sheet from almost any screen (you can always check "why did this happen").

## 3. Global elements (persistent across screens)

### 3.1 Status bar

- Position: a narrow strip at the top of each main screen;
- Content: Epic Doom Clock overview gauge, party HP overview, current campaign progress;
- Iron rule: **only "look" information, never high-frequency "tap" actions** (the top is the hardest area for the thumb to reach);
- Exception: tapping the Doom Clock → a sheet previewing approaching time-edge events.

### 3.2 Dice system

- The D20 is a global element and doesn't belong to any single screen;
- Presentation tiers: **normal checks** resolve quickly in place (≤0.5 s); **key checks** (death saves, story turning points, fate checks involved in the campaign-mode choice) get a full-screen physical presentation;
- "Which checks are key" is marked by the content pack; the framework only provides the two presentation containers.

### 3.3 Sheets and drawers

- Half-screen sheets: character cards, item details, Doom Clock preview — they don't break the current screen context;
- Bottom drawers: expanded log, dialogue options — swipe up to expand, swipe down to collapse;
- Full-screen takeover: only for key-check presentations and campaign-clear cutscenes.

## 4. Screen specifications

Each screen is described in the same format: purpose / composition / core actions / entrances / exits.

### ① Home (Camp)

- **Purpose**: the game's hub, start and end of the meta loop; shows "what the world looks like now".
- **Composition**:
  - Center: the camp / world view (changes visually with Epic progress and flags — a visualisation of the Board);
  - Highlightable slots: Campaign Entry (including "Continue" for an in-progress campaign), Event Center (badged when there are unread triggers), Inventory/Compendium, Character, History Scroll;
  - Top: the global status bar;
  - Promo slot: notices for newly released content packs (a framework-level slot; content decided by delivery).
- **Core actions**: enter each feature screen; continue the in-progress campaign.
- **Entrances**: launching the game; returning from Settlement; returning from each feature screen.
- **Exits**: to ②⑤⑥⑦⑧.
- **Presentation direction**: the visual layer can evolve into an **interactive camp scroll painting** — feature entrances carried by picture-region hotspots (Tide Tower → ②, market → ⑥, campfire → ⑦, notice board → ⑤, scrap pile → ⑧), with equivalent text entries kept at the bottom as a fallback. Hotspot rules in `12-gesture-and-interaction-spec.md` §5 (pixel specs belong to the visual-comp stage; not implemented in the prototype).

### ② Campaign Entry

- **Purpose**: the "cover" of a campaign book and the **mode-branch choice point** (the core screen after the framework revision).
- **Composition**:
  - Campaign book card: title, Epic, synopsis, recommended level, estimated length;
  - **Mode-branch area** (dual-mode campaigns): two form cards side by side — "Landscape · Spatial campaign" (emphasising tactical grid, positioning, big battlefields) and "Portrait · Temporal campaign" (emphasising many rooms, narrative flow, one-handed pacing), each with a description of the differences and a recommendation tag; choosing is a branch and is written to the Board;
  - **Forced mode** (single-mode campaigns): no choice shown; enter directly through a narrative wrapper (e.g. "this memory can only be replayed in fragments" → forced Portrait · Temporal);
  - NG+ info: markers for modes already played, the share of this campaign's branches explored (serves collection and replay).
- **Core actions**: pick a mode (if available) → start; view branch-collection progress.
- **Entrances**: Home; quest jumps from the Event Center.
- **Exits**: into an encounter (③ or ④); back to Home.

### ③ Encounter · Landscape spatial form

- **Purpose**: lay the battlefield out — space, positioning, tactics.
- **Layout** (landscape five zones):

```
┌──────────────────────────────────────────────────┐
│ Top edge: party status bar + initiative bar (expands in combat) │
│ ┌──────────┬─────────────────────┬────────┐       │
│ │ Left col  │  Central main view   │ Right  │       │
│ │ Action    │  Tactical grid map   │ Dice   │       │
│ │ wheel     │  (shared camera for  │ tray   │       │
│ │           │  explore/combat)     │        │       │
│ └──────────┴─────────────────────┴────────┘       │
│ Bottom edge: log strip (swipe up to half screen)  │
└──────────────────────────────────────────────────┘
```

- **Core actions**: pick an action in the left column → tap a target cell in the center → confirm; roll on the right edge; check the log at the bottom.
- **Entrances**: Campaign Entry (landscape form); the next encounter within a campaign.
- **Exits**: Settlement ⑨; emergency retreat (if that edge exists) → Event Center.

### ④ Encounter · Portrait temporal form

- **Purpose**: let the story flow past — many rooms advanced beat by beat, reachable one-handed, commute-friendly.
- **Information strategy**: portrait doesn't rely on spatial zoning but on **temporal zoning** — the same pixels serve different functions at different moments; every moment is a full-screen single focus.

#### ④.1 Three-band layout and the "breathing" rule

```
┌──────────────────────┐
│ ① Status bar (8%)     │ Party portraits + HP rings + initiative order (expands in combat)
├──────────────────────┤
│                      │
│ ② Main view (55–62%)  │ Current room / encounter scene / dialogue cutscene
│                      │
├──────────────────────┤
│ ③ Console (30–37%)    │ Tabs: Action / Dice / Log / Character
└──────────────────────┘
```

The three band heights aren't fixed; they "breathe" with the encounter state machine (whitepaper §6):

| Encounter state | ① Status bar | ② Main view | ③ Console | Notes |
|---|---|---|---|---|
| Explore | 8% | 62% | 30% | Biggest view, emphasising the scene's atmosphere |
| Combat | 12% (initiative expanded) | 55% | 33% | Console expands the full action wheel |
| Dialogue | 8% | 50% | 42% | Console becomes the dialogue option list |
| Key check | 0% | ~90% | 0% | Console retracts entirely; full-screen dice presentation |
| Settlement transition | 8% | 62% | 30% | Falls back to the explore layout |

Iron rule: height changes must happen together with a state-machine state change; **no UI jitter without a story reason**.

#### ④.2 Room sequence: the skeleton of a portrait campaign

A Portrait · Temporal campaign is built from a **room sequence**; each room is an event node:

- **Progress bar**: a horizontal room-progress track at the top of the main view (below the status bar); past rooms are lit, the current room pulsates, future rooms show only door-icon silhouettes;
- **Door previews**: the icon combination on a door previews content and risk — type icon (battle / check / dialogue / pickup / branch door) + danger color scale (from the pack's annotations), giving the player decision information before entering;
- **Branch doors**: when two paths appear behind one door, the door splits left and right into two option cards — the portrait form of the story graph's "choice edge";
- **How it advances**: finish the current room → the progress bar moves one step → the next room unlocks; the camera "walks into" the next room with a sense of vertical depth (pushing upward, reinforcing the sense of going deeper);
- **Going back**: you may walk back to past rooms (to collect leftover pickups), but completed checks and battles don't reset.

#### ④.3 Presentation of the five room types

| Room type | Main view | Console |
|---|---|---|
| Battle room | Vertical battlefield (see ④.4) | Action tab with the action wheel |
| Check room | Scene close-up + highlighted interactables | Dice tab in front, one-tap quick roll |
| Dialogue room | Camera pushes in on the NPC | Console becomes an option list with check badges |
| Pickup room | Scene + glinting hint points | Log tab records what you got |
| Branch door | Split-door cutscene with two option cards | Not involved; choose directly in the main view |

#### ④.4 Portrait combat: a combination of three solutions

A portrait screen is too narrow for a wide battlefield; three mechanisms combine to solve it:

1. **Vertical battlefield**: battlefields are designed as long strips (corridors, boardwalks, canyons), enemies above and the party below, naturally fitting a vertical composition;
2. **Smart camera (fit first, then follow)**: while the battlefield fits, it stays centred and the camera does not move on turn changes (both sides always visible); only when pinch-zoomed so the battlefield exceeds the view does it follow the acting unit, stopping at the battlefield edges so no blank space shows past the border; battlefield content is clipped to the main view and never covers the status band or console;
3. **45° pseudo-3D**: compresses the depth direction, fitting 2–3 more usable rows than a pure top-down view while keeping units feeling three-dimensional.

Constraint: portrait campaign level design must respect an **on-screen unit cap** (≤8 suggested; exact value to be validated in prototypes); large-scale battles should be declared as Landscape · Spatial at design time — one of the bases for a pack's mode declaration.

#### ④.5 The console's four tabs

Switch with a horizontal swipe at the bottom; tab indicator dots are always visible but take no row height:

- **Action**: the current unit's action wheel (main action / bonus / move / item), filtered in real time by context; selecting highlights target cells in the main view; a second confirmation executes;
- **Dice**: a persistent D20 tray. Normal checks are a one-tap quick roll (bar animation, result in ≤0.5 s); key checks trigger a full-screen physical presentation — presentations are tiered by importance to avoid fatigue;
- **Log**: this encounter's event stream as a half-screen feed; tapping any entry can call up a camera replay of that moment (same source as the History Scroll);
- **Character**: a compact character card for the current unit (HP / skill uses / statuses / equipment slots); swipe up for the full-screen card.

#### ④.6 Gestures and hot zones

> This section is the minimal set for portrait encounters; **the full gesture vocabulary, conflict resolution and tutorial rules in `12-gesture-and-interaction-spec.md` are authoritative**.

| Gesture | Where | Effect |
|---|---|---|
| Tap | Main view | Select a unit / target cell / interactable |
| Long-press | A unit in the main view | Pop up an info card (half-screen sheet) |
| Swipe | Console | Switch the four tabs |
| Swipe up | Console Log tab | Expand the full log to half screen |
| Pinch | Main view | Overview ↔ follow camera |
| Swipe down | Progress bar | View the list of past rooms, quick rewind |

Hot-zone iron rule: the action wheel and confirm button live in the **lower-half thumb arc**, fully reachable one-handed even on large phones; the top area (status bar, progress bar) only handles low-frequency actions.

#### ④.7 Room transitions and presentation tiers

- Transitions between rooms: progress bar moves forward + camera pushes in depth, expected ≤1 s, without breaking the rhythm;
- Full-screen takeovers only for: key-check presentations, boss entrances, the story cutscene at the end of a room sequence;
- Every presentation can be skipped (long-press), and skipping loses no information — the content is written to the Log tab and the History Scroll at the same time.

- **Entrances / exits**: same as ③.

### ④.8 Landscape-only: Loadout and Settlement layouts

During a landscape campaign, Loadout and Settlement aren't squeezed into a centered portrait layout; they're rearranged for landscape space:

- **Landscape Loadout**: three columns — left "skill selection" (chip column with slot count), middle "items to carry + attribute points", right "presets and start battle" (preset cards + a large Start button in the right-thumb zone); party status bar on top;
- **Landscape Settlement**: on the left, the item-by-item Board read-out list (each entry animates in); on the right, the growth point-allocation area and exit buttons (Home / next encounter / Scroll); the victory cutscene spreads across the center, then collapses into the settlement layout;
- The portrait layout is unchanged (09 §8: consistency within a form; each form is optimal on its own rather than compromising for the other).

### ⑤ Event Center

- **Purpose**: the list of in-progress quest events (L3 instances) — "what is happening in the world right now".
- **Composition**:
  - Event card list: name, source arc, goal, time remaining (in Doom Clock segments, if any), recommended power;
  - Trigger notice area: nodes lit by new flags, "New" markers on newly unlocked branches;
  - Finished events are automatically archived into the History Scroll.
- **Core actions**: view event details; jump to the related Campaign Entry; abandon optional events (writes a flag).
- **Optional-event rule**: events triggered by `choice`/`hidden` can be abandoned (writes the `<pack>.quest_abandoned.<id>` flag and archives to the History Scroll); main-line events triggered by `auto`/`doom_clock` cannot be abandoned (time edges can't be refused — a narrative discipline).
- **Entrances**: Home (badged when updated).
- **Exits**: Home; ② Campaign Entry.

### ⑥ Inventory and Compendium

- **Purpose**: item viewing and collection progress — the display window for the four item identities.
- **Composition**:
  - Inventory page: filter by identity (numeric gear / check tools / branch keys / Compendium tokens); the item detail sheet shows stats, check modifiers and hints about branches it has opened ("This signet looks like it might be useful somewhere");
  - Compendium page: series collection progress, unlocked Lore entries, completion reward previews.
- **Core actions**: view, equip/unequip (outside campaigns), filter.
- **Entrances**: Home; "View new items" on Settlement.
- **Exits**: Home; Character screen (equipment link).

### ⑦ Character

- **Purpose**: party and character cards — an overview of numbers, statuses and bonds.
- **Composition**: switch party members horizontally; character card (attributes, skills, skill uses, equipment slots, status effects); Bond page (companion affinity and progress on their personal quest lines).
- **Core actions**: view, allocate points / equip (outside campaigns or during rest).
- **Entrances**: Home; the encounter's rest state.
- **Exits**: Home; Inventory (equipment link).

### ⑧ History Scroll

- **Purpose**: the archive of the event stream — answering the question in the player's mind, "why did it turn out like this".
- **Composition**:
  - Timeline: the whole event stream in reverse chronological order, filterable by campaign / arc;
  - Each entry expands: check details (roll + modifier = result vs difficulty), resulting flag changes;
  - **Flag trace**: any story node can show "which events lit it", forming a causal-chain view;
  - Battle replay: re-enacts the event stream of important battles (pure presentation, results can't be changed).
- **Core actions**: browse, filter, trace, replay.
- **Entrances**: Home; summoned as a sheet from any screen; "New entries" on Settlement.
- **Exits**: the source screen.

### ⑨ Settlement

- **Purpose**: the full stop of an encounter, where the meta loop's pen touches paper — "reading the Board changes aloud to the player".
- **Composition**: XP and level changes; loot (new items highlighted, can jump to Inventory); a summary of flag changes ("The blacksmith owes you a favor"); reputation and Doom Clock advance animations; previews of newly unlocked content.
- **Core actions**: continue to the next encounter / back to Home / view new scroll entries.
- **Entrances**: the end of any encounter.
- **Exits**: next encounter (③/④); ① Home; ⑧ History Scroll.

## 5. Screen-loop checklist

| Screen | Entrances (way in) | Exits (way out) | Loop |
|---|---|---|---|
| ① Home | Launch, ⑨ Settlement, returning from each feature | ②⑤⑥⑦⑧ | ✅ Hub |
| ② Campaign Entry | ①, jump from ⑤ | ③/④, ① | ✅ |
| ③ Landscape encounter | ②, previous encounter | ⑨, ⑤ (retreat) | ✅ |
| ④ Portrait encounter | ②, previous encounter | ⑨, ⑤ (retreat) | ✅ |
| ⑤ Event Center | ① | ①, ② | ✅ |
| ⑥ Inventory/Compendium | ①, ⑨ | ①, ⑦ | ✅ |
| ⑦ Character | ①, rest state | ①, ⑥ | ✅ |
| ⑧ History Scroll | ①, sheets from any screen, ⑨ | Source screen | ✅ |
| ⑨ Settlement | ③/④ | ①, ③/④, ⑧ | ✅ |

Rule: any new screen (including sub-game screens) must pass the "entrance / exit" two-column check of this table before entering the framework — part of the content-pack go-live checklist (see `03-TASKS.md` P2).

## 6. Relationship with sub-games

Sub-games reuse this framework's screens:

- A sub-game's entrance hangs in the ② Campaign Entry area (as a special campaign book card) or the Event Center;
- A sub-game's internal screens can be custom, but **entering and leaving must pass through the ⑨ Settlement screen** (writing the Board is a hard requirement);
- Sub-games add no global navigation items, so the nine-screen loop stays intact.

## 7. Visual foundations (final) and open items

**Fonts and reading hierarchy (final)**: bundled Noto Sans SC (Source Han Sans, SIL OFL 1.1), three sizes — body 16 / heading 24 / display 32 (cutscenes and key numbers); UI font sizes gradually converge onto these constants; ad-hoc custom sizes are forbidden.

> English-build note: Noto Sans SC covers Latin glyphs, but an English build should consider a dedicated Latin face (much smaller download, better typography); see the code-review report.

Open items (refined during the prototype stage):

- Transition animation duration rules for each screen (see checklist 14 #8);
- Content review rules for the promo slot.
