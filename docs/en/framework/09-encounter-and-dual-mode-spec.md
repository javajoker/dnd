# Encounter and Dual-Mode Interaction Specification

> Version: v1.0 (final, corresponds to P0.4)
> Related docs: `01-framework-whitepaper.md` §6/§7, `04-ui-ux-design.md` §3/§4, `../tech/02-content-pack-format-spec.md` §2.1/§6
> Scope: entry/exit conditions of the six encounter states, the campaign-mode declaration rules, the campaign-entry mode branch rules, frozen landscape/portrait layout metrics, and the dice-presentation tier standard.
> English mirror of `docs/framework/09-遭遇与双模式交互规范.md`. Terms follow `../GLOSSARY.md`.

---

## 1. Encounter state machine: entry/exit conditions of the six states

| State | Entry condition | Exit condition | Notes |
|---|---|---|---|
| Enter | The node's encounter has loaded (battle encounters go through loadout first, see §9.1) | Opening events fully delivered → Explore | Cutscenes can be skipped; content is still written to the log |
| Explore | Default state | An interactable comes into range → Discover; hostility triggers → Combat; an NPC initiates → Dialogue | Flows both ways with Discover |
| Discover | A check / pickup / trap trigger point activates | Discovery resolved → back to Explore; trap/ambush → Combat | Checks go through the rule pack |
| Combat | Hostility triggers | One side wiped out / retreat edge / objective reached → Settlement | Initiative → round loop, defined by the rule pack |
| Dialogue | Dialogue node / NPC initiates | Options exhausted / check branch decided → Explore or Settlement | Options may carry a check badge |
| Settlement | Combat / dialogue / exploration goal complete | Board writes complete → Rest (if any) or Exit | **Writing the Board is a hard requirement** |
| Rest | The node declares a rest | Player confirms leaving → Exit | Supplies, point allocation, Character screen entrance |

Convention: state changes are emitted as `state.entered` events; rendering shells (including the portrait three-band "breathing") only subscribe and are never commanded.

## 2. Campaign-mode declaration rules

- Where: the manifest `presentation` field (format in `../tech/02-content-pack-format-spec.md` §2.1);
- `mode`: `space` / `time` / `choice`; `forced` forces per act; `recommend` is a node-level suggestion;
- **Basis for the declaration** (decision tree for content authors):
  - >8 units on screen or a big battlefield → must be `space` (portrait readability constraint, doc 04 §④.4);
  - Narrative is fragments / remembrance / a restricted perspective → should be `time` (world §8 narrative hook);
  - Either works → `choice`, handing the mode choice back to the player as a branch;
- After declaration, validator V8 re-checks unit counts in portrait encounters.

## 3. Campaign-entry mode branch rules

- Dual-mode campaigns: the entrance shows two form cards, each with a description of the difference (tactical grid / big battlefield vs many rooms / one-handed pacing) and a recommendation tag; the choice is written to `global.mode_choice.<campaign_id>` and **locked for the whole campaign**;
- Forced mode: no choice shown; enter through a narrative wrapper (e.g. "this memory can only be replayed in fragments"); the wrapper text must not sound like system-speak (no wording like "Mode locked");
- Mode cards also show: a marker for modes already played and the branch-collection percentage (NG+ replay guidance, doc 04 screen ②).

## 4. Landscape · Spatial campaign layout (frozen metrics)

| Zone | Share | Duty |
|---|---|---|
| Top edge | 8% (height) | Party status bar + initiative order bar (expanded in combat) |
| Left column | weight 15 (width) | Action wheel (main action / bonus / move / item) |
| Center | weight 60 (width) | Tactical grid map; exploration and combat share the camera |
| Right column | weight 12 (width) | Dice tray; yields to full-screen presentation for key checks |
| Bottom edge | 5% (height, expands to half screen) | Log strip; swipe up to expand |

> Note: the three column numbers are **relative width weights** (15:60:12), normalised to full width at render time (≈17.2% / 69.0% / 13.8%); the top/bottom edges are height shares.

Tactical-grid readability: cell side ≥ 8% of screen height; ≤ 12×8 cells on screen; projectile lines / threat ranges drawn as outlines rather than color fills (readable for color-blind players).

## 5. Portrait · Temporal campaign layout (frozen metrics)

- The three-band breathing layout keeps the ratio table of doc 04 §④.1 (explore 8/62/30, combat 12/55/33, dialogue 8/50/42, key checks take over the full screen), frozen here;
- Room-advance pacing: transitions ≤1 second; the progress bar sits below the status bar; future rooms show only door-icon silhouettes;
- Door-preview rules: type icon (battle / check / dialogue / pickup / branch door) + danger color scale (three tiers, matching the Light rules difficulty table); a branch door splits into left/right option cards;
- The console's four tabs (Action / Dice / Log / Character) are frozen per doc 04 §④.5; hot-zone iron rule: high-frequency actions live in the lower-half thumb arc.

## 6. Dice-presentation tier standard

| Tier | Which checks | Presentation |
|---|---|---|
| Normal | Every check not marked as key | Quick roll in place; bar animation gives the result in ≤0.5 seconds |
| Key | ① death saves; ② checks tied to the ending choice; ③ checks with `difficulty: hard` that are marked as story turning points; ④ checks the content pack explicitly marks `key: true` | Full-screen physical presentation; long-press to skip; result written to the log at the same time |

- The tier is decided by **content-pack marking + fixed framework categories**: ① and ② are framework-constant key categories; ③ and ④ are marked by content authors;
- Red line against fatigue: ≤3 key presentations per encounter (the validator statically estimates per pack and warns);
- Natural 20 / natural 1 always add one extra tier of effects feedback regardless of tier (the extreme moments of fate, world §4.4).

## 7. Leaving and interrupting an encounter

A persistent ☰ menu inside encounters (portrait: right end of the room progress bar; landscape: right end of the top edge), with options:

| Option | Behavior |
|---|---|
| Continue | Close the menu |
| Retreat (when available) | Shown only if the content pack declares a retreat edge; follows "failure is a branch" (whitepaper §5.2) and writes the corresponding flag |
| Save and return Home | **No saving mid-encounter** (`07-world-state-machine-spec.md` §4.2): return to the snapshot taken before entering this encounter; next time the encounter starts over; show a confirmation whose text states the effect on progress |
| Gesture help | Open the gesture guide on the help page (`12-gesture-and-interaction-spec.md` §4) |

- Incoming calls / backgrounding: system interruptions auto-pause and resume on return (in-memory state kept); a killed process is handled the same as "Save and return Home" — the player loses **at most the current encounter** and never any world state already written to the Board;
- After Settlement the encounter exits normally (⑨ Settlement screen), not via ☰.

## 8. Differences between the two forms and the switching boundary (restated and refined)

- **Form is a campaign-level property**: once the player picks a form at the campaign entrance (or the pack forces one), **starting the campaign switches to that form's layout**, and it holds for the whole campaign — exploration, narrative, loadout, combat and settlement are all presented in the chosen form; act-level forced exceptions inside the campaign (e.g. SL-0/SL-3 forced portrait) are a narrative device, and when the act ends the chosen form returns;
- **Leaving the campaign restores the original screen layout** (portrait baseline): ending cleared, quitting via ☰, retreating after defeat — every path out of a campaign must restore it; outer screens (Home / feature screens) are always portrait;
- The form follows the **campaign data** (manifest `presentation`) and the implementation is data-driven — different campaigns can declare different forms and act-level exceptions; designers change the form boundary by changing content, never code;
- **On device**: switching forms = changing the device screen orientation (`DisplayServer.screen_set_orientation`), not resizing a window; English v1 is portrait-first — `choice` campaigns resolve to `time` in v1, and the landscape spatial form opens in v1.1 (tech/01 §10.1);
- No switching inside a single encounter (F1.4); the difference is one of **structure and pacing**: spatial form = a tactical-grid sandbox with free positioning; temporal form = a room-by-room sequence — the same event stream with two "bodies of play";
- Content packs declare per the §2 decision tree; portrait encounters keep ≤8 units on screen.

## 9. Loadout and the Quickbar

### 9.1 Loadout

- Battle encounters go through a **Loadout screen** before Enter: three blocks — skill selection, items to carry, unallocated attribute points; confirming enters the Enter state — the ritual moment of "preparing for battle";
- **Whether it's restricted is decided by game config** (manifest `loadout` field, `../tech/02-content-pack-format-spec.md` §2.4): whether enabled, item slot count, skill slot count, whether attribute points can be respecced; declared at campaign level, overridable per encounter; undeclared = disabled, go straight in;
- Loadout choices are written to the event stream (`loadout.confirm`), so the History Scroll can trace "what you brought to this fight".

### 9.2 Quickbar (Tray)

- Inside an encounter, available skills and items are presented as **quickbar chips** (content = current loadout selection + real-time context filtering), replacing stacks of option buttons — avoids an explosion of option combinations;
- How to use them (two channels, 12 §1 iron rule): **drag a chip onto a target unit/cell** = use on that target; **tap a chip** = use on the default target;
- Chips show remaining uses and disabled states in real time (bonus already used / uses exhausted / invalid target).

### 9.3 Presets and Auto-play

**Presets**

- Loadout configurations can be applied with one tap: **system presets** (e.g. Assault / Defensive / Balanced, shipped with the content pack) + **player-defined presets** (stored in the save);
- Entering via a preset: apply it on the Loadout screen and go straight to battle — presets exist to **reduce repetitive actions**; players can still tweak slot by slot after applying;
- A preset is only a record of slot choices and **carries no numeric bonus** (same root as the no-go zones: convenience can be given, power can't be sold).

**Auto-play**

- Auto-play can be turned on in Combat: an agent acts according to the preset strategy — **rolls check dice on your behalf**, uses skills by priority (use-limited skills first, falling back to basic attacks when exhausted), uses items by threshold (default: potion at HP <50%, configurable);
- **Time control (agent pacing)**: agent actions have a minimum beat (default ≥0.8 s per action, with 1×/2× speed); **auto-play is "a stand-in hand", not "an accelerator"** — no instant combo chains, and enemy action presentation plays as usual; the player can take over with one tap at any time, effective immediately;
- Auto-play and manual play use **exactly the same command channel and validity checks** (`../tech/01-technical-approach.md` §6.2 Command): events are tagged with source `auto` — replayable and traceable; auto-play can never get a result manual play couldn't;
- Key checks (death saves, story turning points) still get full-screen presentation; auto-play doesn't skip them; auto-play stops automatically when the encounter ends (victory / retreat).
