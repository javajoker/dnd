# Gesture and Interaction Specification

> Version: v1.2 (final; v1.2 adds dragging quickbar chips to use them)
> Related docs: `04-ui-ux-design.md` §3/§④.6, `09-encounter-and-dual-mode-spec.md`
> Scope: the mobile gesture vocabulary, per-scene gesture mapping, gesture conflict resolution, first-run tutorial and help page rules, and the direction for the Home hotspot illustration. Common to all content packs.
> English mirror of `docs/framework/12-手势与交互规范.md`. Terms follow `../GLOSSARY.md`.

---

## 1. Gesture vocabulary (recognition parameters are framework constants)

| Gesture | Recognition parameters | Semantic class | Typical use |
|---|---|---|---|
| Tap | Down-to-up <300 ms, movement <10 pt | Select / confirm | Options, buttons, target cells, target units |
| Two-finger tap | Two touches down in the same frame, held <300 ms, each moves <10 pt, distance between them changes <15 pt (distinguishes from pinch) | Quick confirm | End turn, one-tap quick roll for normal checks |
| Long-press | Held ≥400 ms, movement <10 pt | Inspect / skip | Unit and item detail cards, skip cutscenes |
| Drag | Lift after moving >10 pt | Move | Move units on the battlefield, scroll lists, drag the camera |
| Drag path | A drag that passes ≥2 semantic target points | Cast / aim | Skill casting: start = caster, path = trajectory, end = target |
| Swipe | Horizontal movement >60 pt, vertical <30 pt | Switch | The console's three tabs, the strip of past rooms |
| Pinch | Distance between two touches changes >20% | Zoom | Battlefield: follow camera ↔ overview |
| Two-finger drag | Two touches move in the same direction | Pan | Pan the zoomed battlefield |

Iron rule: **every gesture has a button alternative** — gestures are an efficiency layer, not the only channel (accessibility and newcomer protection). Every gesture command has an equivalent tappable control on screen.

## 2. Scene mapping

### 2.1 Encounter · Landscape spatial form

| Gesture | Effect |
|---|---|
| Tap | Select a unit / target cell / left-column action |
| Drag (from a unit) | Move the unit to a reachable cell (spends the move segment; shows reachable range and landing preview while dragging) |
| Drag path (unit → enemy) | Cast a targeted skill (the path previews the trajectory; release to confirm; release on empty space = cancel) |
| Two-finger tap (anywhere on the battlefield) | End turn |
| Drag (quickbar chip → target unit/cell) | Use an item / cast a skill (on that target); tapping the chip = default target (equivalent path) |
| Long-press (unit) | Info card in a half-screen sheet (HP / AC / damage dice / statuses) |
| Pinch | Zoom the tactical grid (8×5 panorama ↔ local follow) |
| Two-finger drag | Pan the camera when zoomed |

### 2.2 Encounter · Portrait temporal form

| Gesture | Effect |
|---|---|
| Tap | Options / console buttons / highlighted interactables |
| Swipe (console) | Switch the three tabs (Action / Log / Character; the dice strip is always visible) |
| Drag (own unit, vertically) | Adjust position on the vertical battlefield (advance / fall back) |
| Drag path (own → enemy, upward) | Cast a targeted skill (same command as landscape, just a vertical composition) |
| Two-finger tap (main view) | One-tap quick roll for normal checks / end turn |
| Drag (quickbar chip → target unit) | Use an item / cast a skill (on that target); tapping the chip = default target |
| Long-press | Unit info card; long-press on the dice tray = skip the presentation |
| Pinch | Battlefield overview ↔ follow camera; springs back on release |
| Swipe down (progress bar) | List of past rooms, quick rewind |

### 2.3 Outside encounters (Home / feature screens)

| Gesture | Effect |
|---|---|
| Tap | All navigation and confirmation |
| Long-press | Item / Compendium / flag details |
| Swipe | Sibling tabs such as Inventory ↔ Compendium |
| Swipe up (log strip / drawer) | Expand to half screen; swipe down to collapse |
| Tap the Doom Clock | Time-edge preview sheet |
| Tap a map pin / drag the party token along a route | Choose a destination and route (doc 16 §2.3) |
| Long-press a location, route or door | Info card (danger, known table, last visit) |
| Tap a group tab / swipe the main view (split party) | Switch focus between groups (doc 15 §4.4) |
| Drag an item onto another group's tab | Send it through a link, when allowed (doc 15 §5.2) |
| Drag (loadout library entry → party card / equipment slot / quick pouch) | Deliver a skill / gear / item there (09 §9.1 v2); tapping the entry gives it to the current character (equivalent path) |

## 3. Gesture conflict resolution

1. **The starting point decides the meaning**: drags are routed by what's under the touch-down point — on a unit = move/path, on empty space = camera/scroll, on a list = scroll;
2. **Move vs path**: dragging from your own unit, ending on an enemy unit = cast, ending on an empty cell = move; preview and confirm on release, never take effect instantly;
3. **Two-finger tap vs pinch**: distinguished by distance change and duration — distance change <15 pt and duration <300 ms is a two-finger tap, otherwise go to zoom recognition; a two-finger tap doesn't block single-finger taps (if the two fingers land >1 frame apart it isn't treated as two-finger); **no thumb double-tap** (blocks the view, easily confused with fast repeated selection taps, high mis-touch rate on mobile);
4. **Zoom wins over rotation**: no rotation gesture (consistent with "mode is not a screen orientation");
5. A gesture interrupted mid-way (incoming call / backgrounding) is treated as releasing on empty space = cancel; no half-formed commands;
6. **Chip drag vs scrolling the bar**: drag starting on a chip = use-drag; drag starting on empty space in the bar = horizontal scroll; a chip dragged across the main view shows a path preview; releasing on empty space = cancel.

## 4. First-run tutorial and help page

Three layers, all **skippable, re-learnable, and skipping loses no information**:

| Layer | Trigger | Content | Form |
|---|---|---|---|
| Launch cards | First launch (once) | 3 pages of core gestures: tap = select, long-press = details, swipe = switch | Full-screen cards, swipe right to turn pages, "Skip" always visible |
| Contextual tutorials | First time in a given context (once per kind) | First check = two-finger tap quick roll; first battle = drag to move + path to cast + two-finger tap to end turn; first time zoom is available = pinch | Translucent overlay + highlighted target area, non-modal, tap anywhere to continue |
| Help page | Always available, entered on demand | Gesture guide (all tables in §1–§2 of this spec), entrance to re-learn contextual tutorials | Entered from the "Help" entry on Home |

- Trigger records are written to the save (`global.tutorial.<id>`), so they don't repeat on restart;
- Tutorial text is content-pack data (the narrative wrapper can change with the campaign); the structure is fixed by the framework.

## 5. Home hotspot illustration

The visual layer of ① Home is **an interactive camp scroll painting** (Ashenport by night); feature entrances are carried by hotspot regions of the picture rather than a list of buttons:

| Picture region | Entrance |
|---|---|
| Tide Tower (faint glow in the distance) | ② Campaign entry |
| Market stalls | ⑥ Inventory / Compendium |
| Campfire and companions | ⑦ Character |
| Notice board | ⑤ Event center |
| Pile of scraps / private codex | ⑧ History Scroll |

Rules: hotspots hint with a gentle breathing glow (≤3 s cycle, no flashing); hotspots with unread state get a badge; the painting changes visually with Epic progress and flags (a visualisation of the Board, 04 §4 ①); **a text entry bar is kept at the bottom as the accessibility and recognisability fallback** — the hotspot painting is the skin and the text entries are the skeleton, functionally equivalent; **the fallback bar is collapsed by default** (the home screen belongs to the illustration) and is always reachable three ways: a **small grip** at the bottom (a short gold line with a chevron; visually small, touch area ≥ 120×28 pt), **swipe up anywhere on the home screen** to open it and **swipe down** to close it (vertical travel ≥ 48 pt, mainly vertical; a swipe that ends on a hotspot does not count as a tap), and the hotspots themselves. The player's last choice is persisted (a UI preference, not world state — not written to the Board, stored in local settings).

**Implementation status**: implemented in the Godot build (game/). The first-phase painting is a procedural placeholder (layered color blocks + silhouettes, ink / gold-ink palette); when the art is replaced, the hotspot coordinate table and logic stay unchanged (coordinates and entrance mapping are data).

## 6. Hot-zone iron rules (kept and frozen)

- High-frequency actions (action wheel, confirm button, dice tray) live in the **lower-half thumb arc**;
- The top area (status bar, progress bar) only carries low-frequency and "look" information;
- Minimum touch target 44×44 pt; for gestures that don't need precise placement, snap to the nearest target (≤12 pt).
