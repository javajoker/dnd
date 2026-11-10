# Interactive prototype: The Age of the Codex · *Ashenport Fragments* slice

> The prototype UI text itself is Chinese (an early-stage artifact, not updated). The Chinese README is archived in `archive/zh-CN/prototype/`.
> Design docs: `../docs/en/framework/04-ui-ux-design.md` (nine screens and navigation loop), `../docs/en/framework/09-encounter-and-dual-mode-spec.md` (six states and presentation tiers), `../docs/en/framework/11-light-rulepack-v1.md` (numbers)
> Content source: `../docs/story/campaign01/` (Prologue + Act I slice; text rewritten for the prototype)

## Running it

Zero dependencies, no build. Either:

```bash
open prototype/index.html
```

```bash
cd prototype && python3 -m http.server 8642
```

then open http://localhost:8642 in a browser.

## Slice scope

Prologue "Tidewake" + Act I "The Faded Street": 10 nodes, 2 battles (including the tutorial boss), 3 faction dialogues, the shop and rest hub, two-tier dice presentation (key / normal), failure-path branching, and the Settlement and History Scroll loop.

## Rules implemented (Light rule pack v1.1)

- D20 checks (easy/medium/hard DC 8/12/16) + proficiency +2; **critical attacks: nat 20 doubles the damage dice**;
- **Advantage/disadvantage** (2d20 take high/low): the "witnessed_revocation" flag → whole-party advantage on the boss's first round; "Ink Shield" → attackers have disadvantage;
- **Saving throws**: the boss's "Ink Rain Splash" forces a Finesse save DC 11 on everyone, half damage on success (even rounds);
- **Companion rules**: Kelan / Old Fei are controllable units (each quickbar chip has 1 signature skill, 1 action per round); downed allies can be revived with "First Aid" and get up with 1 HP after battle;
- **Death saves best of three** (key check, full screen); action economy: PC 1 action + 1 per living companion + bonus + move; the enemy turn starts automatically when everyone has acted.

## Screen coverage (doc 04)

| Screen | Prototype implementation |
|---|---|
| ① Home (Camp) | World view changes with the Fading level, five entrances, promo slot, badges |
| ② Campaign Entry | Campaign card, dual-mode form cards (Start disabled until chosen), forced-mode narrative note, branch collection |
| ③ Encounter · Landscape | Five zones: top initiative bar / left action wheel / central 8×5 tactical grid / right dice tray / bottom log strip (tap to expand) |
| ④ Encounter · Portrait | Three-band breathing (explore 62/30, combat 55/37, dialogue 50/42), room progress bar (door icons + pulsing current room), four-tab console |
| ⑤ Event Center | Event cards, new-flag notices, time-edge preview (Ink-Rain Night Raid at 2 segments) |
| ⑥ Inventory / Compendium | Inventory (four identity tags) / Compendium (progress of four series and completion rewards) |
| ⑦ Character | Three attributes, proficiencies, use-limited skills, bonds, alignment axis |
| ⑧ History Scroll | Reverse-chronological event timeline, tap to expand check details, gold markers on key checks, source-node trace |
| ⑨ Settlement | Board results read out one by one (flags / reputation / clock / items), jump to new scroll entries |

> The prototype's combat ratio 55/37 predates the frozen 12/55/33 in doc 09 §5; the Godot build uses the frozen value.

## Architecture vs framework iron rules (tech/01)

- `Board`: the World State Board; every write (`writeFlag` / `tickClock` / `addRep` / `giveItem`) goes through shared primitives;
- `emit()`: an append-only event stream, the only input to the log, History Scroll and status bar;
- The six encounter states drive the portrait breathing layout (`runtime.phase` → CSS class); shells hold no logic;
- One core, two shells: `enterNode` / `doNodeCheck` / `attack` are the core; the portrait three bands and landscape five zones are the two shells — a "compare forms" debug button at the top shows the same state in both renderings; in the real game the mode is chosen and locked at the entrance (F1.4), and the Prologue is forced portrait.

## Interaction paths verified (browser walkthrough)

Mode choice disabled state → first-run gesture tutorial (skippable, shown once via localStorage) → forced-portrait notice in the Prologue → full-screen key check (long-press to skip) → failed check takes the failure path (Cordoned Alley encounter) → contextual battle tutorial → shop purchase → rest → **Loadout** (one-tap system presets "Assault / Defensive / Balanced" + per-slot tweaks; slot counts from the `loadout` config) → landscape tactical-grid boss battle (**quickbar chips**: tap = default target, drag onto an enemy = targeted cast, drag onto an ally = use item; drag = move, two-finger tap = end turn, pinch = zoom) → **Auto-play** (rolls for you, uses skills in loadout order, auto-potion below 50% HP, ≥0.8 s per action at 1×/2×, take over any time, stops when the battle ends) → death saves → retreat as "failure is a branch" → ☰ save and return Home → Settlement (growth attribute points) → History Scroll flag trace (auto-play actions marked 🤖, event source `auto`).

## Gestures (implementation side of doc 12)

Drag (move / use chip), drag path (cast), two-finger tap (end turn), long-press (details / skip), swipe (switch tab), pinch (zoom) are all implemented; **every gesture has an equivalent button path**. The help page is under "Help" on Home and tutorials can be replayed any time.

## Explicitly out of scope (prototype boundary)

- No saves/snapshots, no audio, no real physics dice (CSS presentation only); the Home hotspot painting is only a direction (see `../docs/en/framework/12-gesture-and-interaction-spec.md` §5) — the prototype uses text entrances;
- Numbers are an illustrative implementation of Light rule pack v1, not balance conclusions.
