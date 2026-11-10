# Feature Checklist and Interaction Loops (framework feature CHECKLIST)

> Version: v1.0
> Related docs: all framework/ specs (01–12); implementations: the web interaction prototype at repo-root `prototype/` and the Godot build in `game/`
> Scope: using the prototype as the baseline, lists every framework feature for **interaction completeness and closed loops**, with the status of both implementations. Legend: ✅ done / ⚠️ partial or degraded / ❌ not implemented / ◻️ intentionally not done (reason given).
> Usage: this table is the baseline for acceptance and iteration — new features get a row, and changes update both columns.
> English mirror of `docs/framework/13-功能清单与交互闭环.md` (change history omitted). Terms follow `../GLOSSARY.md`.

---

## 1. Home (① Camp)

| Feature | Interaction | Loop | Prototype | Godot |
|---|---|---|---|---|
| Camp view | Text/visuals change with the Fading level and flags (Board visualisation) | Reached on launch; reached by returning from every feature | ✅ | ✅ |
| Five-entrance navigation | Campaign Entry (incl. "Continue") / Event Center / Inventory-Compendium / Character / History Scroll | 04 §5 two columns: every entrance has a way back to Home | ✅ | ✅ |
| Unread badge | Badge on the Event Center when there are new triggers | Event fires → badge → cleared on entry | ✅ | ✅ |
| Promo slot | Content delivery slot (framework level) | Display only, never blocks | ✅ | ✅ |
| Manual save | "Record the Codex" | Snapshot notice → stay on Home | ✅ (toast) | ✅ |
| Help entrance | Gesture guide / re-learn tutorials | Sheet → back to Home | ✅ | ✅ (guide shows the full 12 §1 table + re-learn entrance) |
| Home hotspot illustration | Interactive painting + region hotspots, text-entry fallback | 12 §5 | ◻️ (prototype: direction only) | ✅ (procedural placeholder painting, data-driven hotspot coordinates) |

## 2. Campaign Entry (②)

| Feature | Interaction | Loop | Prototype | Godot |
|---|---|---|---|---|
| Campaign book card | Title / synopsis / level / length / branch collection | Home → enter; back to Home | ✅ | ✅ |
| Mode-branch choice | Two form cards side by side; Start disabled until chosen; choice written to the Board and locked for the campaign | Choose → start → encounter | ✅ | ✅ on desktop; ❌ on device — landscape only resizes the window (code review B2) |
| Forced-mode narrative wrapper | No choice; narrative wrapper goes straight in | Same as above | ✅ | ✅ |
| Paid locked state | Visible but locked + narrative text + "Get" half-screen sheet; purchase unlocks instantly | Locked → get → unlocked → enter | ✅ (none) | ✅ |
| Sub-game book card | pack_type=subgame listed data-driven | Card → sub-game flow | ❌ (not in prototype) | ✅ |

## 3. Encounter · Portrait temporal form (④)

| Feature | Interaction | Loop | Prototype | Godot |
|---|---|---|---|---|
| Three-band breathing | Explore 8/62/30, combat 12/55/33, dialogue 8/50/42, key check full screen; heights change only with state changes | Driven by state changes | ✅ | ✅ |
| Room progress bar | Past lit / current pulsing / future silhouettes; swipe down to review past rooms | Advance → review (completed rooms don't reset) | ✅ (no review) | ✅ (swipe-down/tap review, read-only) |
| Console dice strip + three tabs | Always-visible dice strip; Action / Log / Character, swipe to switch | Tab cycle | ✅ | ✅ (swipe + tap, two channels) |
| Quickbar chips | Skills / items / companions / first aid; tap = default target, drag onto target = targeted use | Use → uses/disabled state refresh | ✅ | ✅ (tap + drag to target; release on empty space cancels) |
| Vertical battlefield | Enemies above, party below; unit cards show HP/AC | Combat presentation | ✅ | ✅ |
| Room types | Battle / check / dialogue / pickup / branch door presented differently | 04 §④.3 | ✅ | ✅ |
| Loadout (pre-battle) | Per character: party cards → character sheet (four gear slots + prepared skills) + quick pouch + three-tab library; drag-and-drop / tap; last loadout pre-filled; one-tap presets; slot counts from config | Node → loadout → battle | ✅ (old three-block version) | ✅ |
| Equipment | Weapon / Armor / Shield / Trinket slots, persisted on the Board; swap weapons in battle (object interaction, once per turn) | Loadout / battle pack group | ✅ (none) | ✅ |
| Quick pouch and pack | Pouch = bonus action, pack = action; items shared by the party; drag thrown items onto enemies | Battle quickbar "Pack" group | ✅ (none) | ✅ |

## 4. Encounter · Landscape spatial form (③)

| Feature | Interaction | Loop | Prototype | Godot |
|---|---|---|---|---|
| Five-zone layout | Top initiative / left wheel / center tactical grid / right dice tray / bottom log strip (tap to expand to half screen) | 09 §4 frozen metrics | ✅ | ✅ |
| Tactical grid | Unit placement, readable cell size | Presentation | ✅ | ✅ |
| Drag to move | Drag a unit to a reachable cell (spends the move segment) | Move → write | ✅ | ✅ |
| Drag path to cast | Path preview from own unit to enemy, then cast | Cast → event | ✅ | ✅ |
| Pinch zoom | Overview ↔ follow camera | Pure presentation | ✅ | ✅ (clamped 0.7–1.6) |
| Dual-shell consistency | Same encounter, byte-identical event streams in both shells | tech/01 §10 TP3 | ✅ (form-compare debug button) | ✅ (shell_diff hard check) |

## 5. Gesture system (doc 12 vocabulary)

| Gesture | Use | Prototype | Godot |
|---|---|---|---|
| Tap | Select / confirm | ✅ | ✅ |
| Long-press | Detail card / skip presentation | ✅ | ✅ |
| Drag | Move unit / scroll | ✅ | ✅ |
| Drag path | Cast / aim | ✅ | ✅ |
| Two-finger tap | End turn / quick roll | ✅ | ✅ |
| Swipe | Switch tab / review rooms | ✅ | ✅ |
| Pinch | Battlefield zoom | ✅ | ✅ |

Note: the Godot gesture layer implements all of 12 §1's recognition parameters (gesture_recognizer.gd / gesture_layer.gd shared by both shells; GestureCommands guarantees gestures and buttons produce isomorphic Commands); every gesture keeps an equivalent button path (12 §1 iron rule).

## 6. Dice and checks

| Feature | Interaction | Prototype | Godot |
|---|---|---|---|
| Normal quick roll | Resolves in the tray in place, ≤0.5 s | ✅ | ✅ |
| Key-check full-screen presentation | Death saves / story turning points; skippable without losing information | ✅ (long-press to skip) | ✅ (long-press ≥400 ms to skip, 04 §④.7 mis-touch protection) |
| Natural 20 / 1 bump | Critical success/failure text + effects marker | ✅ | ✅ |
| Check details viewable | d20 + modifier vs DC itemised | ✅ | ✅ (dice tray / Scroll) |
| Advantage / disadvantage | 2d20 take high/low; sources declared by packs | ✅ | ✅ |

## 7. Combat (Light rule pack v1.1)

| Feature | Notes | Prototype | Godot |
|---|---|---|---|
| Action economy | PC 1 action + 1 action per living companion + bonus + move; turn passes automatically when all actions are spent | ✅ | ✅ |
| Companion system | Controllable chips, downed, first aid (d20 + Wits vs 8), stand up at 1 HP after battle | ✅ | ✅ |
| Death saves best of three | Key check, full screen | ✅ | ✅ |
| Saving throws (AoE) | save = {attr, dc, half}, boss area skills | ✅ | ✅ |
| Critical hits | nat 20 doubles damage dice | ✅ | ✅ |
| Auto-play | Rolls for you / strategy chain / 1×–2× pacing / take over any time / auto-stop at end / events tagged `auto` | ✅ | ✅ |
| Retreat | Failure is a branch (no loot or XP; companions dragged out) | ✅ | ✅ |
| Escort battle | Keep an NPC alive for N rounds; failure costs time | ✅ (none) | ✅ |
| Maze exploration sequence | Check / pickup / ambush beats, idempotent progress | ✅ (none) | ✅ |
| Battle + choice hybrid | Post-battle choice written to the Board | ✅ (none) | ✅ |
| HP persists across encounters | Written at settlement, next encounter starts from it, rest restores full | ✅ (none) | ✅ |
| Short / long rest | Short rest spends Hit Dice to heal; long rest restores all (Doom Clock +1 in the wild, free at the inn); "Make Camp" on settle + camp on post-battle story nodes | ✅ (none) | ✅ |
| Battle gold | Encounter `gold` field, paid on victory, read out at settle; spend it on camp Supplies | ✅ (none) | ✅ |

## 8. Encounter boundaries (09 §7)

| Feature | Notes | Prototype | Godot |
|---|---|---|---|
| ☰ pause menu | Continue / save and return Home / gesture help | ✅ | ✅ |
| Save and return Home | Confirmation, encounter restart stated, written Board state unaffected | ✅ | ✅ (restores the in-memory snapshot) |
| Interruptions (09 §7) | Calls / backgrounding auto-pause and resume | — | ❌ no app-pause handling (code review B2) |
| Form locked within an encounter | No landscape/portrait switch after entering | ✅ | ✅ (shell router lock) |
| Act-level forced form | SL-0/SL-3 forced portrait + narrative wrapper, switch back at N3-7 | ✅ | ✅ |

## 9. Growth and Settlement (⑨)

| Feature | Notes | Prototype | Godot |
|---|---|---|---|
| Item-by-item read-out | XP / loot / flags / reputation / clock animated one by one | ✅ | ✅ |
| Growth point allocation | Attribute points at settlement / loadout, capped at +3 | ✅ | ✅ (global.growth) |
| Jump to new scroll entries | Settlement → History Scroll | ✅ | ✅ |
| Save snapshots | Settlement complete / Home idle / manual; migration chain | ❌ (not in prototype) | ✅ loaded on launch + migration chain; "Continue" really continues (P4 Phase 0) |
| New Game+ | Ending → NG+: fragment carry-over / Compendium and entitlements kept / playthrough count | ❌ | ✅ |
| Ending types | E1–E4 triggered by conditions + ending screen | ❌ (outside the slice) | ✅ |

## 10. Feature screens (⑤⑥⑦⑧)

| Feature | Notes | Prototype | Godot |
|---|---|---|---|
| Event Center ⑤ | Event cards / new-flag area / time-edge preview / abandon (writes a flag) | ✅ (no abandon) | ✅ (optional events can be abandoned, flag written + quest.abandon archived) |
| Inventory-Compendium ⑥ | Four identity tags, progress of the four Compendium series and completion rewards | ✅ | ✅ (filter / details / series progress / completion preview) |
| Character ⑦ | Attributes / proficiencies / skills / bonds / alignment axis / growth area | ✅ | ✅ |
| History Scroll ⑧ | Event stream newest first, expandable details, flag trace, gold markers for key moments | ✅ | ✅ |
| Battle replay ⑧ | Re-enacts the event stream of important battles (pure presentation, unchangeable) | ❌ | ✅ (minimal: beat-log replay, read-only) |

## 11. Monetization and operations (06)

| Feature | Notes | Prototype | Godot |
|---|---|---|---|
| Entitlement runtime | Three lighting paths — purchase / event / achievement — with provenance | ❌ | ✅ |
| Locked state | Visible but locked, narrative, unlocks on purchase | ❌ | ✅ |
| Refunds | Finish the current run, no new run | ❌ | ✅ |
| Zero-change strategy switch | Pack fingerprints identical across a limited-time-free switch | ❌ | ✅ (asserted) |
| Home promo slot / subscription area | 06 §6 mount points | ⚠️ (placeholder text) | ⚠️ (placeholder text) |

## 12. Toolchain and audit (engineering side)

| Feature | Status |
|---|---|
| packlint V1–V14 | ✅ 0 FAIL on all four packs |
| Bot simulation (all endings / coverage) | ✅ 45/45 nodes, 100% |
| shell_diff dual-shell comparison | ✅ byte-identical |
| Headless tests | ✅ 1583 PASS / 0 FAIL; test data isolated under user://test/ (P4 Phase 0) |
| Release audit | ✅ first round closed (fail → fix → re-review pass) |

---

## Gap summary

| # | Gap | Level | Resolution |
|---|---|---|---|
| 1 | Gesture layer (drag / path / two-finger tap / pinch / swipe / long-press details) | High | ✅ Implemented (12 §1 parameters + §3 conflict resolution, shared by both shells) |
| 2 | Three-layer tutorial (launch cards / contextual tutorials / help re-learn) | High | ✅ Implemented (12 §4, trigger records in global.tutorial.*) |
| 3 | Progress-bar room review | Medium | ✅ Implemented (swipe down / tap, read-only) |
| 4 | Skipping presentations unified to long-press (mis-touch protection, 04 §④.7) | Low | ✅ Implemented (long-press ≥400 ms) |
| 5 | Event Center "abandon event (writes a flag)" | Medium | ✅ Implemented (optional events, quest.abandon + flag) |
| 6 | Full Inventory-Compendium (four series progress / completion rewards) | Medium | ✅ Implemented (filter / details / series progress / completion preview) |
| 7 | Battle replay (⑧ event-stream re-enactment) | Medium | ✅ Minimal version (beat-log replay, pure presentation, read-only) |
| 8 | Home hotspot illustration | — | ✅ Implemented in Godot (12 §5: procedural placeholder painting + data-driven hotspot coordinates) |
| 9 | Real promo-slot delivery / subscription benefits area | — | Operations content, delivered with M4 |
