# 17 · Polyhedral Dice — Usage and Presentation Spec

> Status: **implemented** (TASKS P5.1, 2026-11-10) except tray rolls for map tables, which arrive with doc 16. Related: doc 04 §3.2 (dice system), doc 09 §6 (presentation tiers), doc 11 (rules), doc 14 #2 (3D dice), doc 16 (tables).

## 1. State (verified in code)

| Piece | Where | State |
|---|---|---|
| Shape table | `shell/ui/dice_shapes.gd` (`DiceShapes`) | d4 (read at the top vertex), d6, d8, d10 (pentagonal trapezohedron), d12 (icosahedron dual), d20; planar faces, standard numbering (opposite faces sum to N+1) — unit-tested per shape |
| 3D stage | `shell/ui/dice_3d.gd` (`Dice3D`) | `play(result)` (single d20, unchanged) and `play_set([{die, value, tens?}])` for up to 6 dice at once; the logic value is aligned to the reading position and the result face is turned to read upright; aspect-aware layout (rows of 3 in portrait); `d100_spec(r)` splits a percentile roll into a tens d10 (00–90) and a units d10 |
| Tray | `shell/ui/dice_tray.gd` (`DiceTray`) | Compact mode of the same stage (transparent, no slow motion, ~1 s), over the main view (portrait) / under the dice column (landscape); setting **Damage dice: On / Crits only / Off** in ☰ |
| Strip glyph | `shell/ui/die_glyph.gd` (`DieGlyph`) | Drawn die outline per type in both shells' dice strips; damage detail line ("Damage d8: 5+2 = 7") |
| Event data | core | `dice` on `check.roll` (all kinds), `battle.attack`, `item.use` (healing), short rest; `damage_dice` on `battle.attack` and AoE saves |

## 2. The set

| Die | Shape | Used for (this framework) |
|---|---|---|
| d4 | Tetrahedron (value read at the top vertex) | Potions (`1d4+2`), light weapons, small tables |
| d6 | Cube | One-handed weapons, default travel table, Ink Flask (`2d4` → shown as two d4) |
| d8 | Octahedron | Heavy weapons, Hit Dice (Old Fei), travel tables |
| d10 | Pentagonal trapezohedron | Hit Dice (the Unwritten), d100 tens/units |
| d12 | Dodecahedron | Big weapons, rare tables |
| d20 | Icosahedron (exists) | Checks, attacks, saves, death saves, wandering tables |
| d100 | Two d10 (tens die marked 00–90 + units die) | Rare-find and weather tables |

## 3. Where each presentation is used

Builds on the tier standard (doc 09 §6), now for every die type:

| Tier | When | Presentation |
|---|---|---|
| **Quick** | Ordinary checks, ordinary damage, routine table rolls | Dice strip: a small die glyph of the right shape + value; ≤0.5 s |
| **Tray** | Damage on a hit, healing, short-rest Hit Dice, travel event rolls, any multi-dice roll (`2d4`, `d100`) | A compact 3D tray (bottom third of the main view, ~1 s): all dice tumble together, each settles on its given face, the sum and modifier appear beside them; tap to skip |
| **Key** | Key checks (doc 09 §6), death saves, critical hits (the doubled damage dice), key table rolls (`"key": true` on a table or row) | Full-screen physical presentation (the existing d20 stage, generalised to every shape) with slow-motion settle; long-press to skip |

- **Fatigue red line** (doc 09 §6) still applies: ≤3 key presentations per encounter; tray rolls don't count but are skippable and can be turned off in settings ("Show damage dice": on / key only / off);
- **Auto-play** (doc 09 §9.3) shows tray rolls at its own pace and never adds key presentations.

## 4. Fairness rules (unchanged, extended to all dice)

- The result always comes from the logic layer (the seeded RNG, later the multiplayer authority, doc 15 §8); the 3D scene only **displays** it. For every shape the target face (or vertex, for the d4) is aligned to the reading position at the end of the throw;
- Presentation randomness (throw arc, spin) uses its own seeded RNG and never touches the game's RNG;
- Skins (cosmetics) change palettes only, never readability (contrast check on faces and numbers).

## 5. Data needed in events

So shells can render the right dice without guessing, dice-bearing events carry a **`dice`** list: `[{ "die": "d8", "value": 6 }, { "die": "d8", "value": 2 }]` plus `mod` and `total`.

| Event | Today | Add |
|---|---|---|
| `check.roll` | `rolls`, `keep`, `mode` | `dice: [{die:"d20", value}]` (two entries with advantage/disadvantage, the kept one flagged) |
| `battle.attack` | `damage_rolls`, `damage` | `dice` for the damage expression (crit doubles the entries) |
| `item.use` (heal / thrown) | `healed` | `dice` for the heal or damage expression |
| Short rest (`MSG_SHORT_REST` log) | `roll` | a proper `rest.short` event with `dice` |
| `table.roll` (doc 16) | — | `dice`, `table`, `row`, `modifiers` |

## 6. Implementation notes (for TASKS P5)

1. Generalise `Dice3D` from one icosahedron to a **shape table**: vertices, faces, face values, and the reading rule (top face, or top vertex for d4). The existing align-to-target code works per face normal and carries over;
2. Add a **DiceTray** scene that throws several `Dice3D` bodies at once on a shared table (bounded arena, 1 s cap, same skip rules);
3. The dice strip gets **shape glyphs** for the six dice (a font icon set or small SVGs) instead of the fixed "d20" label;
4. Core emits `dice` lists (§5) — presentation-only data, no rule change; old saves without `dice` fall back to today's text.

## 7. Acceptance

- Every die in §2 renders in 3D with correct face values (opposite faces summing correctly where the standard requires it) and settles on the logic's value 100% of the time (unit test per shape, like today's d20 test);
- A hit with the Boathook Axe shows a d8 in the tray; a crit shows two; healing with a potion shows a d4; a short rest shows the character's Hit Die; a d100 table shows two d10s;
- Turning "Show damage dice" off removes tray rolls but never hides key presentations.
