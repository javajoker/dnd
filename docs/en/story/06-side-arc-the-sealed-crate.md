# Side Arc · *The Sealed Crate* (arc_salvage) · Design Notes

> Version: v1.0 (2026-11-12). Script (structure source of truth): `06-side-arc-the-sealed-crate.story.md` -> `tools/story_import.gd` -> `game/packs/arc_salvage/`.
> Related: tech/02 §2.6 (graft), tech/10, story/03 (bands), world book §4.5 / §6.

## 1. One line

The Salvage Guild pays sixty gold to fetch a sealed crate from a half-faded warehouse, unopened. Inside are the dwelling plates of families who are still alive: profit, procedure, or conscience.

## 2. How it attaches

```json
"graft": {"into": "campaign01", "node": "N1-1",
  "edge": {"type": "choice", "label": "The Guild broker has a crate that needs fetching", "to": "S-1", "requires": {"flag.done": false}}}
```

Entry: Free City Plaza (N1-1), offered until done. Return: S-7 -> N1-1. Free, no entitlement. Quest log: `events.json` `salvage_crate` (completes at S-7, +20 XP).

## 3. Node arc (11 nodes, 7 logical)

| Node | Type | Content |
|---|---|---|
| S-1 | scene | Broker Orsolya Venn's docket. Salvager's Apprentice line (`rep.salvage +1`, inspiration +1) |
| S-2 | check | Warehouse Nine: stealth or perception (medium), or the Boathook Axe. Fail -> S-2f |
| S-2f | scene | The one costed failure: `clock +1` |
| S-3 | battle | What Lives in the Margins (medium): Ink Fiend, Ink Imp x2, `hp +4`; 60 XP, 12 gold, Ink Salve |
| S-4 | scene | Kelan opens the crate: thirty current dwelling plates; the Guild lifts them so houses sell as empty. Lore `revoked_registry_plates` |
| S-5 | dialog | The choice (below) |
| S-6p | scene | Profit: `rep.salvage +1`, alignment -5, 60 gold; `bond.kelan -5`, 40 XP |
| S-6c | scene | Procedure (Scriptorium): `rep.scriptorium +1`, alignment +5; `bond.kelan +5`, `clock -1`, 40 XP |
| S-6r | scene | Conscience: `bond.kelan +15`, Mended House Plate, 40 XP |
| S-6x | scene | Failed intimidate (conscience route, no battle): `rep.salvage -1`, `bond.kelan +5`, 40 XP |
| S-7 | scene | Writes `done`, returns to N1-1 |

Each option rewards a different party: the Guild (gold), the Scriptorium (slow, clean), Kelan (the right thing at a cost).

## 4. Data added

`mended_house_plate` (trinket, `max_hp +2`, not sold; weaker than the Tide Charm); lore `revoked_registry_plates` (series Register of the Revoked). Everything else reused from the host.

## 5. Interface with the main line

Reads: `background`, `item.boathook_axe`, own `done`. Writes: `done`, `rep.salvage`, `rep.scriptorium`, `bond.kelan`, alignment, gold, XP, `doom_clock` +1 (S-2f) or -1 (S-6c). Clock budget 9 + 1 = 10. Canon: Kelan's open items are untouched (no sheet change).

## 6. Balance (measured 2026-11-12, 600 games)

| Battle | Band | Result |
|---|---|---|
| S-3 | medium 70-80 | 73.7 % (default seed), 75.0 % (seed 7) with `hp +4` already in the script |

Classes: Harbor Guard 80.3 %, Scavenger 75.2 %, Ink Adept 77.7 % (all within +-7 of default). simulate: 24 runs, node coverage 11/11. Test suite: all pass. packlint: 0 FAIL / 0 WARN; zh-CN complete.
