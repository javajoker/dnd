# Side Arc · *The Thirty Lamps* (arc_lamps) · Design Notes

> Version: v1.0 (2026-11-12). The second side quest made by a single run of the content pipeline with every role played by one agent (codex-producer, story writer, world designer, balancer), tech/11 §1.1.
> Script (structure source of truth): `07-side-arc-the-thirty-lamps.story.md` → `tools/story_import.gd` → `game/packs/arc_lamps/`.
> Related: tech/02 §2.6 (graft), tech/10 (script format), story/03 (balance bands), world book §4.3 / §6 / §8.1 / §9.

## 1. One line

A Scriptorium archivist wants a novice copyist fetched out of a fading reading room before the seal closes, and the copyist is busy copying thirty names that the Scriptorium has already revoked.

## 2. How it attaches

```json
"graft": {"into": "campaign01", "node": "N1-1",
  "edge": {"type": "choice", "label": "The archivist asks for a copyist", "to": "S-1",
           "requires": {"flag.done": false}}}
```

- **Entry:** the Free City Plaza hub (N1-1). It is always offered until the quest is done. The label is unique on that node (the other three grafts are Old Fei, the Guild broker and the Tide Chart).
- **Return:** S-6 goes back to N1-1. The main line, its endings and its flags are untouched.
- **Free:** `monetization.strategies = ["free"]`, no entitlement.
- **Quest log:** `events.json` `thirty_lamps` (objective, completes at S-6, settles +20 XP).

## 3. Node arc (8 nodes)

| Node | Type | Content |
|---|---|---|
| S-1 | scene | **The Archivist's Errand**: Dace of the Scriptorium asks for Pell Ambry, a novice, to be brought out of the Reading Room of the Thirty Lamps before the seal sets. The Ninth Rule says a sealed room's pages are revoked with it |
| S-2 | check | **The Sealed Annex Door**: investigation (read the seal ring) or athletics (force the hinges), both medium. Failure → S-2f |
| S-2f | scene | **The Lamp Goes Grey**: the one costed failure, `clock +1` (the seal rings across the harbour) → S-3 |
| S-3 | battle | **Ink in the Thirty Lamps** (medium): Ink Fiend, Ink Imp ×2, `enemy_mods.hp +4`; 60 XP, 12 gold, Ink Salve |
| S-4 | dialog | **Pell at the Centre Desk**: Pell is copying the thirty names by lamplight. Two choices, plus a background line for a Scriptorium Novice |
| S-5r | scene | **The Seal Closes** (Scriptorium rule): carry Pell out; the sheet greys behind you. `rep.scriptorium +1`, alignment +5 (Inkbound), gold +15, 40 XP |
| S-5w | scene | **A Copy Carried Out** (the novice's wish): Pell finishes the copy and you take it out. `rep.scriptorium -1`, `rep.salvage +1`, alignment −5 (Blankward), gold +10, item `pell_copy`, 40 XP |
| S-6 | scene | **The Thirty Lamps**: lore `revoked_registry_lamps`; writes `done` → N1-1 |

The choice at S-4 is the quest's point: the Scriptorium keeps its rule and the room stays sealed, or the novice keeps his wish and the Scriptorium loses face. The Scriptorium Novice background gets a third line that doesn't change the outcome, only the reward (inspiration +1), so the background matters without bypassing the choice.

The Salvage Guild pays for copies of fading pages. The novice route therefore reads as business in the Guild's eyes, which fits world book §6 (the Guild values recovered fragments, not principles).

## 4. Data added (world designer)

| Data | Where | Why |
|---|---|---|
| `pell_copy`, Pell's Copied Roll, `codex` only, not sold | `arc_lamps/items.json` | Host-facing marker of the wish route. It has no stat, so it doesn't outclass bought gear. The host can read `item.pell_copy` later |
| Lore `revoked_registry_lamps` (series *Register of the Revoked*) | `arc_lamps/lore.json`, written by the script's `LORE` block | Counts toward that series |
| Pell Ambry (novice) and Archivist Dace (Scriptorium) | text only, no `characters.json` entry | Both are one-scene NPCs. They have no stats, skills or battle role, so no data is needed |

Everything else is reused from the host: player_blank, Kelan, Old Fei, Ink Fiend, Ink Imp, Ink Salve.

## 5. Canon

- **Canon: no change.** The quest fills no open item on the canon sheets (world book §8.2). Kelan's open item "how she relates to the Scriptorium" is deliberately left open: this quest shows only a Scriptorium clerk's view of her, not hers.
- Pell and Dace are new NPCs, which the rules allow without a sheet.

## 6. Interface with the main line

- **Reads:** `background` (Scriptorium Novice line), its own `arc_lamps.done`.
- **Writes:** `arc_lamps.done`; global `rep.scriptorium` / `rep.salvage`, `alignment`, `lore`, `item.pell_copy`, XP, gold; `doom_clock` +1 (S-2f) only.
- **Doom Clock:** packlint V5 sums host + arc positive clock effects: 9 + 1 = 10 ≤ 10. The runtime clamps the clock to 0–10.

## 7. Balance and validation

| Battle | Band | Before | Change | After (default hero, 600 games) |
|---|---|---|---|---|
| S-3 | medium 70–80 | 73.7 % (seed 20261109), no change needed | none (`hp +4` from the recipe table, in band) | 73.7 / 75.0 % (seeds 20261109 / 7) |

- Classes (600 games): Harbor Guard 80.3 %, Scavenger 75.2 %, Ink Adept 77.7 % against the default 73.7 %. All within ±7 points, so no class needed a change. The Harbor Guard value sits just above the medium band; the band applies to the default party, so it stays.
- packlint (grafted onto campaign01): 0 FAIL / 0 WARN; zh-CN 47 keys complete.
- `simulate.gd -- 24 packs/arc_lamps`: endings E1 13 / E2 11, clock in range, quest node coverage 8/8 (100 %).
- Test suite: `== 全部通过 == RESULT: PASS 2193 / FAIL 0`; `test_arc_packs` covers arc_lamps.
