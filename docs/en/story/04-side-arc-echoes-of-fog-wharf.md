# Side Arc · *Echoes of Fog Wharf* (arc_tide) · Design Notes

> Version: v1.0 (M4 content expansion)
> Basis: tech/02 §2.6 (graft side-arc declaration block), §12 V14 (graft validation), whitepaper §10.4 (content track:
> side arcs touch only packs/ data + generic core grafting capability), doc 08 (branching model: side arcs converge back to the main line).
> Data pack: `game/packs/arc_tide/` (the authoring source is the data tables accompanying this file; same two-copy discipline as campaign01).
> English mirror of `docs/story/04-支线-雾码头的回声.md`. Terms follow `../GLOSSARY.md`.

## 1. One line

Whoever buys that Half-Page Tide Chart in the Free City Plaza will, on some foggy night, hear the salvage bell at Fog Wharf — and pull up a life the Scriptorium struck from its rolls.

## 2. How it attaches (graft — main-line data untouched)

```json
"graft": {
  "into": "campaign01",
  "node": "N1-1",
  "edge": { "type": "item", "item": "half_tide_table", "label": "Follow the Tide Chart",
    "to": "T-1", "requires": { "flag.done": false } }
```

- **Trigger**: while holding the Half-Page Tide Chart (sold in the campaign01 N1-1 shop, campaign book §8), N1-1 gains an extra item edge "Follow the Tide Chart"; without the item it stays hidden (tech/02 §4.3: no fallback means hidden);
  `requires: flag.done=false` hides the entrance once the arc is complete (edge conditions resolve into the side arc's namespace, §2.6);
  pack missing / entitlement gate not lit = nothing is injected, and the main line is byte-for-byte unchanged;
- **Convergence**: the arc's end node T-4 points back to the host node N1-1 (back to the main-line Hub; the main line can continue);
- **Entitlement**: `monetization.strategies = ["free"]`, no `entitlement.requires` declared — free with the base game.

## 3. Node arc (4 nodes, node budget 6)

| Node | Type | Content |
|---|---|---|
| T-1 | check | **Night Search at Fog Wharf**: Perception check · medium. Success → follow the bell (T-2); failure → still reach T-2, but you've woken something in the fog (`clock +1`; the "costed convergence" failure pattern B — the difference lies in the success/failure effects) |
| T-2 | battle | **Salvage Battle**: ambushed the moment you haul up the sunken chest — Ink Fiend ×1 + Ink Imp ×2 (reuses the Ink Fiend family from campaign01 enemies.json; side arcs reference the host's resource tables, tech/02 §2.6). After victory, the only out-edge → T-3 |
| T-3 | scene | **Register of the Revoked · Scrap**: on_enter settlement — Compendium entry `revoked_registry_tide` (lore effect, into global.lore) + Salvage Guild reputation +1 (rep.salvage) + XP +40 (XP flows into growth, tech/04 §8 rule 1) |
| T-4 | scene | **Convergence**: on_enter writes `arc_tide.done`; only out-edge → N1-1 (back to the main line) |

Flag ledger: `done` (writers: T-4; readers: History Scroll / reserved for future side-arc links) — it does not enter campaign01's ending conditions, so **the main line's four-ending distribution is unaffected** (the ending table reads only the host's endings; side arcs are not merged into endings, tech/02 §2.6).

## 4. Interface with the main line

- **Reads**: `item.half_tide_table` (host item; visibility condition of the graft edge);
- **Writes**: flags in the `arc_tide.*` namespace (07 §3: only this pack may write them); `global.lore` / `global.rep.salvage` /
  `global.growth.*` (global whitelist, any pack may write); `global.doom_clock` only +1 on the T-1 failure path (V5 merged-view
  clock algebraic sum = host 5 + side arc 1 = 6 ≤ 10, bounded);
- **Never writes**: any main-line flag, ending condition or node data (the graft is pure injection; the host pack is untouched).

## 5. Validation and simulation scope

- packlint: `lint_grafted` (tech/02 §12 V14) — V1–V3 graph traversal runs on the merged view (T-1~T-4 reach the host's endings via the injected edge), V4/V6–V9/V11–V13 run per this pack, and resource references (Ink Fiend family enemies, player_blank, half_tide_table) resolve in the merged view;
- Simulation: when the bot holds the Tide Chart the injected edge is visible, and after completing the arc it returns to N1-1; the ending-distribution assertion keeps the full set of four endings (the arc doesn't affect main-line endings; see `test_arc_tide` in tests/run.gd).
